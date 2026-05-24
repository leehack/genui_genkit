import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:genui_genkit/genui_genkit.dart';
import 'package:genui_genkit_llamadart/genui_genkit_llamadart.dart';
import 'package:llamadart/llamadart.dart' as llama;

import 'model_config.dart';
import 'runtime/app_runtime.dart';

final class LlamaLocalGenkitBackend implements GenUiBackend {
  LlamaLocalGenkitBackend(this.configListenable, {required this.modelStatus}) {
    modelStatus.value = ModelRuntimeStatus.idle(configListenable.value);
    configListenable.addListener(_handleConfigChanged);
  }

  final ValueListenable<ModelConfig> configListenable;
  final ValueNotifier<ModelRuntimeStatus> modelStatus;

  LlamaDartGenUiBackend? _backend;
  ModelConfig? _activeConfig;
  LlamaDartGenUiBackend? _preparedBackend;
  StreamSubscription<llama.ModelDownloadTaskSnapshot>? _downloadSubscription;
  var _disposed = false;

  Future<void> prepare({String? warmUpSystemPrompt}) async {
    final backend = await _ensureBackend();
    await _prepareBackend(backend, warmUpSystemPrompt: warmUpSystemPrompt);
  }

  @override
  Stream<GenUiBackendEvent> send(GenUiTurnRequest request) async* {
    late final LlamaDartGenUiBackend backend;
    try {
      backend = await _ensureBackend();
      await _prepareBackend(backend);
    } catch (error, stackTrace) {
      modelStatus.value = modelStatus.value.copyWith(
        phase: ModelRuntimePhase.failed,
        errorMessage: error.toString(),
      );
      yield GenUiBackendError(
        error.toString(),
        cause: error,
        stackTrace: stackTrace,
      );
      return;
    }

    yield* backend.send(request);
  }

  @override
  Future<void> cancelActiveTurn() async {
    await _backend?.cancelActiveTurn();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    configListenable.removeListener(_handleConfigChanged);
    await _disposeBackend();
  }

  void _handleConfigChanged() {
    unawaited(_resetForConfig(configListenable.value));
  }

  Future<void> _resetForConfig(ModelConfig config) async {
    await cancelActiveTurn();
    await _disposeBackend();
    if (!_disposed) {
      modelStatus.value = ModelRuntimeStatus.idle(config);
    }
  }

  Future<LlamaDartGenUiBackend> _ensureBackend() async {
    if (_disposed) {
      throw StateError('LlamaLocalGenkitBackend has been disposed.');
    }

    final config = configListenable.value;
    final activeBackend = _backend;
    if (activeBackend != null && identical(config, _activeConfig)) {
      return activeBackend;
    }

    await _disposeBackend();
    final backend = _createBackend(config);
    _backend = backend;
    _activeConfig = config;
    _downloadSubscription = backend.snapshots.listen((snapshot) {
      if (!identical(_backend, backend)) return;
      final status = ModelRuntimeStatus.fromDownload(
        config: config,
        snapshot: snapshot,
        assetLabel: 'Model',
      );
      if (snapshot.stage == llama.ModelDownloadTaskStage.ready &&
          !identical(_preparedBackend, backend)) {
        modelStatus.value = ModelRuntimeStatus.loading(
          config: config,
          resolvedModelPath: snapshot.entry?.filePath,
        );
        return;
      }
      modelStatus.value = status;
    });
    return backend;
  }

  Future<void> _prepareBackend(
    LlamaDartGenUiBackend backend, {
    String? warmUpSystemPrompt,
  }) async {
    if (identical(_preparedBackend, backend)) return;

    final config = _activeConfig ?? configListenable.value;
    final currentStatus = modelStatus.value;
    modelStatus.value = ModelRuntimeStatus.loading(
      config: config,
      assetLabel: currentStatus.assetLabel,
      resolvedModelPath: currentStatus.resolvedModelPath,
    );

    await backend.prepare(warmUpSystemPrompt: warmUpSystemPrompt);
    if (!identical(_backend, backend) || _disposed) return;

    _preparedBackend = backend;
    modelStatus.value = ModelRuntimeStatus.ready(
      config: config,
      resolvedModelPath: modelStatus.value.resolvedModelPath,
    );
  }

  LlamaDartGenUiBackend _createBackend(ModelConfig config) {
    return LlamaDartGenUiBackend(
      LlamaDartGenUiConfig(
        modelSource: config.modelSource,
        mmprojSource: config.mmprojSource,
        modelName: config.modelName,
        cacheDirectory: config.cacheDirectory,
        cachePolicy: config.cachePolicy,
        modelSha256: config.modelSha256,
        mmprojSha256: config.mmprojSha256,
        bearerToken: config.bearerToken,
        inferenceOptions: config.inferenceOptions,
        temperature: config.temperature,
        maxTokens: config.maxTokens,
        enableThinking: config.enableThinking,
      ),
    );
  }

  Future<void> _disposeBackend() async {
    final backend = _backend;
    _backend = null;
    _activeConfig = null;
    _preparedBackend = null;
    await _downloadSubscription?.cancel();
    _downloadSubscription = null;
    await backend?.dispose();
  }
}
