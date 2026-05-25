import 'dart:async';
import 'dart:convert';

import 'package:genkit/genkit.dart' as genkit;
import 'package:genui/genui.dart';
import 'package:schemantic/schemantic.dart';

import 'backend.dart';

/// Converts a GenUI chat message into a Genkit message.
typedef GenkitMessageMapper = genkit.Message Function(ChatMessage message);

/// Returns provider-specific Genkit generation options for a turn.
typedef GenkitConfigBuilder<CustomOptions> =
    CustomOptions? Function(GenUiTurnRequest request);

/// Optional Genkit generate settings forwarded by [GenkitBackend].
final class GenkitGenerateOptions<CustomOptions> {
  /// Creates generation options forwarded to `Genkit.generateStream`.
  const GenkitGenerateOptions({
    this.config,
    this.configBuilder,
    this.tools,
    this.toolNames,
    this.toolChoice,
    this.returnToolRequests,
    this.maxTurns,
    this.outputSchema,
    this.outputFormat,
    this.outputConstrained,
    this.outputInstructions,
    this.outputNoInstructions,
    this.outputContentType,
    this.contextBuilder,
    this.use,
    this.interruptRespond,
    this.interruptRestart,
  });

  /// Static provider-specific options used for every request.
  final CustomOptions? config;

  /// Dynamic provider-specific options built from each GenUI turn.
  final GenkitConfigBuilder<CustomOptions>? configBuilder;

  /// Tool definitions made available to the Genkit model.
  final List<genkit.Tool<Object?, Object?>>? tools;

  /// Names of registered Genkit tools made available to the model.
  final List<String>? toolNames;

  /// Provider-specific tool choice policy.
  final String? toolChoice;

  /// Whether tool requests should be returned instead of automatically handled.
  final bool? returnToolRequests;

  /// Maximum number of tool-calling turns Genkit may run for one request.
  final int? maxTurns;

  /// Optional schema for structured model output.
  final SchemanticType<Object?>? outputSchema;

  /// Optional structured output format name.
  final String? outputFormat;

  /// Whether Genkit should constrain model output to [outputSchema].
  final bool? outputConstrained;

  /// Additional instructions Genkit should include for structured output.
  final String? outputInstructions;

  /// Whether Genkit should skip default structured-output instructions.
  final bool? outputNoInstructions;

  /// Expected content type for structured output.
  final String? outputContentType;

  /// Builds Genkit context from a GenUI turn.
  ///
  /// If omitted, non-empty [GenUiTurnRequest.metadata] is forwarded as context.
  final Map<String, dynamic>? Function(GenUiTurnRequest request)?
  contextBuilder;

  /// Genkit generation middleware refs to apply to the request.
  final List<genkit.GenerateMiddlewareRef<CustomOptions>>? use;

  /// Interrupt responses to resume a pending tool interaction.
  final List<genkit.InterruptResponse>? interruptRespond;

  /// Tool request parts to restart an interrupted generation.
  final List<genkit.ToolRequestPart>? interruptRestart;
}

/// Converts a Genkit stream chunk into text for the GenUI session.
typedef GenkitChunkMapper =
    String? Function(genkit.GenerateResponseChunk<Object?> chunk);

/// Converts the final Genkit response into turn-completion metadata.
typedef GenkitResultMetadataMapper =
    Map<String, Object?> Function(
      genkit.GenerateResponseHelper<Object?> response,
    );

/// Backend adapter for any Genkit model.
///
/// The host app owns provider setup: register Gemini, OpenAI, llamadart, or any
/// other Genkit plugin on [ai], then pass the selected [model] here. This class
/// only translates GenUI turn requests into Genkit messages and streams model
/// text chunks back into [GenkitGenUiSession].
final class GenkitBackend<CustomOptions> implements GenUiBackend {
  /// Creates a backend for the selected Genkit [model].
  ///
  /// Provider setup stays outside this package: register plugins on [ai], then
  /// pass the selected model reference and optional generation settings here.
  GenkitBackend({
    required this.ai,
    required this.model,
    CustomOptions? config,
    GenkitConfigBuilder<CustomOptions>? configBuilder,
    GenkitGenerateOptions<CustomOptions>? options,
    this.messageMapper = defaultGenkitMessageMapper,
    GenkitChunkMapper? chunkMapper,
    GenkitResultMetadataMapper? resultMetadataMapper,
    FutureOr<void> Function()? onDispose,
  }) : options =
           options ??
           GenkitGenerateOptions<CustomOptions>(
             config: config,
             configBuilder: configBuilder,
           ),
       chunkMapper = chunkMapper ?? ((chunk) => chunk.text),
       resultMetadataMapper =
           resultMetadataMapper ?? defaultGenkitResultMetadataMapper,
       _onDispose = onDispose;

  /// Genkit runtime configured by the host app.
  final genkit.Genkit ai;

  /// Genkit model reference selected by the host app.
  final genkit.ModelRef<CustomOptions> model;

  /// Generation options forwarded to Genkit for each turn.
  final GenkitGenerateOptions<CustomOptions> options;

  /// Converts GenUI chat messages into Genkit messages.
  final GenkitMessageMapper messageMapper;

  /// Converts Genkit stream chunks into text chunks.
  final GenkitChunkMapper chunkMapper;

  /// Converts the final Genkit response into completion metadata.
  final GenkitResultMetadataMapper resultMetadataMapper;
  final FutureOr<void> Function()? _onDispose;

  var _disposed = false;

  @override
  Stream<GenUiBackendEvent> send(GenUiTurnRequest request) async* {
    if (_disposed) {
      yield const GenUiBackendError('GenkitBackend has been disposed.');
      return;
    }

    final messages = genkitMessagesForRequest(request, messageMapper);

    try {
      final stream = ai.generateStream<CustomOptions, Object?>(
        model: model,
        messages: messages,
        config: options.configBuilder?.call(request) ?? options.config,
        tools: options.tools,
        toolNames: options.toolNames,
        toolChoice: options.toolChoice,
        returnToolRequests: options.returnToolRequests,
        maxTurns: options.maxTurns,
        outputSchema: options.outputSchema,
        outputFormat: options.outputFormat,
        outputConstrained: options.outputConstrained,
        outputInstructions: options.outputInstructions,
        outputNoInstructions: options.outputNoInstructions,
        outputContentType: options.outputContentType,
        context:
            options.contextBuilder?.call(request) ??
            (request.metadata.isEmpty
                ? null
                : Map<String, dynamic>.from(request.metadata)),
        use: options.use,
        interruptRespond: options.interruptRespond,
        interruptRestart: options.interruptRestart,
      );

      var emittedText = false;
      await for (final chunk in stream) {
        final text = chunkMapper(chunk);
        if (text != null && text.isNotEmpty) {
          emittedText = true;
          yield GenUiTextChunk(text);
        }
      }
      final result = await stream.onResult;
      if (!emittedText) {
        final finalText = result.text;
        if (finalText.isNotEmpty) {
          yield GenUiTextChunk(finalText);
        }
      }
      yield GenUiTurnDone(metadata: resultMetadataMapper(result));
    } catch (error, stackTrace) {
      yield GenUiBackendError(
        error.toString(),
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _onDispose?.call();
  }

  @override
  FutureOr<void> cancelActiveTurn() {}
}

/// Builds the Genkit message list for one GenUI request.
List<genkit.Message> genkitMessagesForRequest(
  GenUiTurnRequest request, [
  GenkitMessageMapper messageMapper = defaultGenkitMessageMapper,
]) {
  return [
    if (request.systemPrompt != null && request.systemPrompt!.isNotEmpty)
      genkit.Message(
        role: genkit.Role.system,
        content: [genkit.TextPart(text: request.systemPrompt!)],
      ),
    for (final previous in request.history)
      if (defaultGenkitMessageText(previous).trim().isNotEmpty)
        messageMapper(previous),
    messageMapper(request.message),
  ];
}

/// Default plain-text mapping for GenUI chat turns.
///
/// UI interactions are preserved as textual context so any Genkit provider can
/// respond to ChoicePicker or other component submit events without depending
/// on Flutter widget details.
genkit.Message defaultGenkitMessageMapper(ChatMessage message) {
  return genkit.Message(
    role: genkitRoleFor(message.role),
    content: [genkit.TextPart(text: defaultGenkitMessageText(message))],
  );
}

/// Converts a GenUI chat role into the corresponding Genkit role.
genkit.Role genkitRoleFor(ChatMessageRole role) {
  return switch (role) {
    ChatMessageRole.system => genkit.Role.system,
    ChatMessageRole.user => genkit.Role.user,
    ChatMessageRole.model => genkit.Role.model,
  };
}

/// Converts a GenUI chat message into the default plain-text Genkit prompt.
String defaultGenkitMessageText(ChatMessage message) {
  final fragments = <String>[];
  final text = message.text.trim();
  if (text.isNotEmpty) {
    fragments.add(text);
  }

  final interactions = message.parts.uiInteractionParts
      .map((part) => part.interaction)
      .toList(growable: false);
  if (interactions.isNotEmpty) {
    fragments.add(
      'User interacted with generated UI: ${jsonEncode(interactions)}',
    );
  }

  if (fragments.isNotEmpty) {
    return fragments.join('\n\n');
  }

  return jsonEncode(message.toJson());
}

/// Extracts standard completion metadata from a Genkit response.
Map<String, Object?> defaultGenkitResultMetadataMapper(
  genkit.GenerateResponseHelper<Object?> response,
) {
  return {
    'finishReason': response.modelResponse.finishReason.value,
    if (response.modelResponse.finishMessage != null)
      'finishMessage': response.modelResponse.finishMessage,
    if (response.modelResponse.usage != null)
      'usage': response.modelResponse.usage!.toJson(),
  };
}
