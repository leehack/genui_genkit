import 'dart:async';

import 'package:genkit/client.dart' as genkit_client;
import 'package:http/http.dart' as http;

import 'backend.dart';

/// Calls a remote Genkit flow that streams GenUI/A2UI text chunks.
///
/// This backend targets flows served by `genkit_shelf` or another compatible
/// Genkit flow server. The remote flow input is a serialized [GenUiTurnRequest],
/// the stream chunks are plain text, and the final flow result is exposed as
/// [GenUiTurnDone.metadata].
final class RemoteGenkitFlowBackend implements GenUiBackend {
  RemoteGenkitFlowBackend({
    required Uri flowUrl,
    Map<String, String> headers = const {},
    http.Client? client,
  }) : _remoteAction = genkit_client
           .defineRemoteAction<
             Map<String, Object?>,
             Map<String, Object?>,
             String,
             void
           >(
             url: flowUrl.toString(),
             defaultHeaders: headers,
             httpClient: client,
             fromResponse: _metadataFromJson,
             fromStreamChunk: (jsonData) => jsonData as String? ?? '',
           );

  final genkit_client.RemoteAction<
    Map<String, Object?>,
    Map<String, Object?>,
    String,
    void
  >
  _remoteAction;

  StreamSubscription<String>? _activeSubscription;
  var _disposed = false;

  @override
  Stream<GenUiBackendEvent> send(GenUiTurnRequest request) {
    if (_disposed) {
      return Stream.value(
        const GenUiBackendError('RemoteGenkitFlowBackend has been disposed.'),
      );
    }

    late StreamController<GenUiBackendEvent> controller;
    var cancelled = false;
    var reportedError = false;

    Future<void> start() async {
      StreamSubscription<String>? subscription;
      try {
        final actionStream = _remoteAction.stream(
          input: genUiTurnRequestToJson(request),
        );
        subscription = actionStream.listen(
          (text) {
            if (text.isNotEmpty && !controller.isClosed) {
              controller.add(GenUiTextChunk(text));
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            reportedError = true;
            if (!controller.isClosed) {
              controller.add(
                GenUiBackendError(
                  error.toString(),
                  cause: error,
                  stackTrace: stackTrace,
                ),
              );
            }
          },
          cancelOnError: false,
        );
        _activeSubscription = subscription;

        await subscription.asFuture<void>();
        if (!cancelled && !controller.isClosed) {
          controller.add(GenUiTurnDone(metadata: await actionStream.onResult));
        }
      } catch (error, stackTrace) {
        if (!cancelled && !reportedError && !controller.isClosed) {
          controller.add(
            GenUiBackendError(
              error.toString(),
              cause: error,
              stackTrace: stackTrace,
            ),
          );
        }
      } finally {
        if (identical(_activeSubscription, subscription)) {
          _activeSubscription = null;
        }
        if (!controller.isClosed) {
          await controller.close();
        }
      }
    }

    controller = StreamController<GenUiBackendEvent>(
      onListen: () => unawaited(start()),
      onCancel: () async {
        cancelled = true;
        await _activeSubscription?.cancel();
        _activeSubscription = null;
      },
    );
    return controller.stream;
  }

  @override
  Future<void> cancelActiveTurn() async {
    await _activeSubscription?.cancel();
    _activeSubscription = null;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await cancelActiveTurn();
    _remoteAction.dispose();
  }
}

Map<String, Object?> _metadataFromJson(dynamic jsonData) {
  if (jsonData == null) return const {};
  if (jsonData is Map<Object?, Object?>) {
    return jsonData.cast<String, Object?>();
  }
  return {'result': jsonData};
}
