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

  final CustomOptions? config;
  final GenkitConfigBuilder<CustomOptions>? configBuilder;
  final List<genkit.Tool<Object?, Object?>>? tools;
  final List<String>? toolNames;
  final String? toolChoice;
  final bool? returnToolRequests;
  final int? maxTurns;
  final SchemanticType<Object?>? outputSchema;
  final String? outputFormat;
  final bool? outputConstrained;
  final String? outputInstructions;
  final bool? outputNoInstructions;
  final String? outputContentType;
  final Map<String, dynamic>? Function(GenUiTurnRequest request)?
  contextBuilder;
  final List<genkit.GenerateMiddlewareRef<CustomOptions>>? use;
  final List<genkit.InterruptResponse>? interruptRespond;
  final List<genkit.ToolRequestPart>? interruptRestart;
}

typedef GenkitChunkMapper =
    String? Function(genkit.GenerateResponseChunk<Object?> chunk);

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

  final genkit.Genkit ai;
  final genkit.ModelRef<CustomOptions> model;
  final GenkitGenerateOptions<CustomOptions> options;
  final GenkitMessageMapper messageMapper;
  final GenkitChunkMapper chunkMapper;
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

genkit.Role genkitRoleFor(ChatMessageRole role) {
  return switch (role) {
    ChatMessageRole.system => genkit.Role.system,
    ChatMessageRole.user => genkit.Role.user,
    ChatMessageRole.model => genkit.Role.model,
  };
}

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
