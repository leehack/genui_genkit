import 'dart:async';

import 'package:genui/genui.dart';

/// Request sent from a GenUI session to a Genkit-backed backend.
final class GenUiTurnRequest {
  const GenUiTurnRequest({
    required this.message,
    this.history = const [],
    this.systemPrompt,
    this.catalogId,
    this.metadata = const {},
  });

  /// The current user/UI message.
  final ChatMessage message;

  /// Prior conversation messages known by the adapter.
  final List<ChatMessage> history;

  /// Optional system prompt assembled from the GenUI catalog.
  final String? systemPrompt;

  /// Catalog identifier expected by the renderer.
  final String? catalogId;

  /// App-specific request metadata.
  final Map<String, Object?> metadata;
}

/// Serializes a [GenUiTurnRequest] for remote Genkit flows.
Map<String, Object?> genUiTurnRequestToJson(GenUiTurnRequest request) {
  return {
    'message': request.message.toJson(),
    'history': request.history.map((message) => message.toJson()).toList(),
    if (request.systemPrompt != null) 'systemPrompt': request.systemPrompt,
    if (request.catalogId != null) 'catalogId': request.catalogId,
    'metadata': request.metadata,
  };
}

/// Deserializes the JSON format produced by [genUiTurnRequestToJson].
GenUiTurnRequest genUiTurnRequestFromJson(Map<String, Object?> json) {
  final historyJson = json['history'] as List<Object?>? ?? const [];
  return GenUiTurnRequest(
    message: ChatMessage.fromJson(_jsonMap(json['message'], 'message')),
    history: [
      for (final item in historyJson)
        ChatMessage.fromJson(_jsonMap(item, 'history')),
    ],
    systemPrompt: json['systemPrompt'] as String?,
    catalogId: json['catalogId'] as String?,
    metadata: json['metadata'] == null
        ? const {}
        : _jsonMap(json['metadata'], 'metadata'),
  );
}

Map<String, Object?> _jsonMap(Object? value, String fieldName) {
  if (value is! Map) {
    throw FormatException('Expected "$fieldName" to be a JSON object.');
  }
  return Map<String, Object?>.from(value);
}

/// Events emitted by a backend during one GenUI turn.
sealed class GenUiBackendEvent {
  const GenUiBackendEvent();
}

/// A raw text chunk from the model/backend.
///
/// Chunks may include normal assistant prose and/or fenced A2UI JSON blocks.
final class GenUiTextChunk extends GenUiBackendEvent {
  const GenUiTextChunk(this.text);

  final String text;
}

/// Signals a successfully completed backend turn.
final class GenUiTurnDone extends GenUiBackendEvent {
  const GenUiTurnDone({this.metadata = const {}});

  final Map<String, Object?> metadata;
}

/// Signals an error reported by the backend.
final class GenUiBackendError extends GenUiBackendEvent {
  const GenUiBackendError(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
}

/// Backend contract used by [GenkitGenUiSession].
abstract interface class GenUiBackend {
  Stream<GenUiBackendEvent> send(GenUiTurnRequest request);

  FutureOr<void> cancelActiveTurn();

  FutureOr<void> dispose();
}

/// Function that converts a turn request into a raw text stream.
typedef GenkitTextGenerator =
    FutureOr<Stream<String>> Function(GenUiTurnRequest request);

/// Minimal local backend adapter for Genkit-style streaming APIs.
///
/// The generator is intentionally generic so apps can wrap `Genkit.generateStream`
/// from any provider, including `genkit_llamadart`, without forcing this package
/// to depend on a concrete model plugin.
final class LocalGenkitBackend implements GenUiBackend {
  LocalGenkitBackend({required GenkitTextGenerator generate})
    : _generate = generate;

  final GenkitTextGenerator _generate;
  var _disposed = false;

  @override
  Stream<GenUiBackendEvent> send(GenUiTurnRequest request) async* {
    if (_disposed) {
      yield const GenUiBackendError('LocalGenkitBackend has been disposed.');
      return;
    }

    try {
      final stream = await _generate(request);
      await for (final chunk in stream) {
        if (chunk.isNotEmpty) {
          yield GenUiTextChunk(chunk);
        }
      }
      yield const GenUiTurnDone();
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
    _disposed = true;
  }

  @override
  FutureOr<void> cancelActiveTurn() {}
}
