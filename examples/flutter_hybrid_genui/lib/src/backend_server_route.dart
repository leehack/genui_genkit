import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:genui_genkit/genui_genkit.dart';

import 'model_config.dart';

/// Remote Genkit-flow route whose endpoint can be edited at runtime.
final class BackendServerGenkitBackend implements GenUiBackend {
  BackendServerGenkitBackend(this.config);

  final ValueListenable<BackendServerConfig> config;

  RemoteGenkitFlowBackend? _backend;
  BackendServerConfig? _activeConfig;
  var _disposed = false;

  @override
  Stream<GenUiBackendEvent> send(GenUiTurnRequest request) async* {
    if (_disposed) {
      yield const GenUiBackendError(
        'BackendServerGenkitBackend has been disposed.',
      );
      return;
    }

    final backend = await _ensureBackend(config.value);
    yield* backend.send(request);
  }

  @override
  FutureOr<void> cancelActiveTurn() {
    return _backend?.cancelActiveTurn();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _backend?.dispose();
    _backend = null;
  }

  Future<RemoteGenkitFlowBackend> _ensureBackend(
    BackendServerConfig currentConfig,
  ) async {
    final existing = _backend;
    final activeConfig = _activeConfig;
    if (existing != null &&
        activeConfig != null &&
        currentConfig.sameRuntimeConfig(activeConfig)) {
      return existing;
    }

    await existing?.dispose();
    _activeConfig = currentConfig;
    return _backend = RemoteGenkitFlowBackend(flowUrl: currentConfig.endpoint);
  }
}
