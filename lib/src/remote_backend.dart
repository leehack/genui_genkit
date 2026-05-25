import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'backend.dart';

/// Calls a remote GenUI backend over HTTP and consumes Server-Sent Events.
///
/// The backend sends one POST per turn. The server is expected to return SSE
/// events named `chunk`, `done`, and `error`. If [client] is omitted, this
/// class creates and owns a short-lived HTTP client per turn, which allows
/// [cancelActiveTurn] to abort the active request. If [client] is supplied, the
/// caller owns its lifecycle and cancellation cannot forcibly close it.
final class RemoteGenUiBackend implements GenUiBackend {
  /// Creates a backend for a custom HTTP/SSE endpoint.
  RemoteGenUiBackend({
    required Uri endpoint,
    http.Client? client,
    Map<String, String> headers = const {},
  }) : _endpoint = endpoint,
       _client = client,
       _headers = headers;

  final Uri _endpoint;
  final http.Client? _client;
  final Map<String, String> _headers;
  http.Client? _activeOwnedClient;
  var _disposed = false;

  @override
  Stream<GenUiBackendEvent> send(GenUiTurnRequest request) async* {
    if (_disposed) {
      yield const GenUiBackendError('RemoteGenUiBackend has been disposed.');
      return;
    }

    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    if (ownsClient) {
      _activeOwnedClient = client;
    }
    try {
      final httpRequest = http.Request('POST', _endpoint)
        ..headers.addAll({
          'accept': 'text/event-stream',
          'content-type': 'application/json',
          ..._headers,
        })
        ..body = jsonEncode(genUiTurnRequestToJson(request));
      final response = await client.send(httpRequest);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        yield GenUiBackendError(
          'Remote GenUI backend returned HTTP ${response.statusCode}.',
        );
        return;
      }

      await for (final event in _sseEvents(response.stream)) {
        switch (event.name) {
          case 'chunk':
            final data = _decodeEventObject(event);
            final text = data['text'] as String? ?? '';
            if (text.isNotEmpty) yield GenUiTextChunk(text);
          case 'error':
            final data = _decodeEventObject(event);
            yield GenUiBackendError(data['message'] as String? ?? event.data);
          case 'done':
            final data = event.data.trim().isEmpty
                ? const <String, Object?>{}
                : _decodeEventObject(event);
            yield GenUiTurnDone(metadata: data);
          default:
            break;
        }
      }
    } catch (error, stackTrace) {
      if (!_disposed) {
        yield GenUiBackendError(
          error.toString(),
          cause: error,
          stackTrace: stackTrace,
        );
      }
    } finally {
      if (ownsClient) {
        client.close();
      }
      if (identical(_activeOwnedClient, client)) {
        _activeOwnedClient = null;
      }
    }
  }

  @override
  FutureOr<void> cancelActiveTurn() {
    _activeOwnedClient?.close();
    _activeOwnedClient = null;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _activeOwnedClient?.close();
    _activeOwnedClient = null;
  }
}

Map<String, Object?> _decodeEventObject(_SseEvent event) {
  final decoded = jsonDecode(event.data);
  if (decoded is! Map<Object?, Object?>) {
    throw FormatException(
      'Expected "${event.name}" SSE data to be a JSON object.',
    );
  }
  return decoded.cast<String, Object?>();
}

Stream<_SseEvent> _sseEvents(Stream<List<int>> bytes) async* {
  var name = 'message';
  final data = StringBuffer();

  await for (final line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty) {
        yield _SseEvent(name: name, data: data.toString().trimRight());
      }
      name = 'message';
      data.clear();
      continue;
    }
    if (line.startsWith('event:')) {
      name = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      data.writeln(line.substring(5).trimLeft());
    }
  }

  if (data.isNotEmpty) {
    yield _SseEvent(name: name, data: data.toString().trimRight());
  }
}

final class _SseEvent {
  const _SseEvent({required this.name, required this.data});

  final String name;
  final String data;
}
