import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:genkit/genkit.dart' as genkit;
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:genui_genkit/genui_genkit.dart';

import 'model_config.dart';
import 'runtime/app_runtime.dart';

final class LlamaLocalGenkitBackend implements GenUiBackend {
  LlamaLocalGenkitBackend(this.configListenable, {required this.modelStatus}) {
    modelStatus.value = ModelRuntimeStatus.idle(configListenable.value);
    configListenable.addListener(_handleConfigChanged);
  }

  final ValueListenable<ModelConfig> configListenable;
  final ValueNotifier<ModelRuntimeStatus> modelStatus;

  GenkitBackend<LlamaDartGenerationConfig>? _backend;
  ModelConfig? _activeConfig;
  Future<GenkitBackend<LlamaDartGenerationConfig>>? _initialization;
  LlamaModelPreparationTask? _preparationTask;
  StreamSubscription<LlamaModelPreparationSnapshot>? _preparationSubscription;
  var _disposed = false;

  Future<void> prepare({String? warmUpSystemPrompt}) async {
    await _ensureBackend(warmUpSystemPrompt: warmUpSystemPrompt);
  }

  @override
  Stream<GenUiBackendEvent> send(GenUiTurnRequest request) async* {
    late final GenkitBackend<LlamaDartGenerationConfig> backend;
    try {
      backend = await _ensureBackend();
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
    _preparationTask?.cancel();
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

  Future<GenkitBackend<LlamaDartGenerationConfig>> _ensureBackend({
    String? warmUpSystemPrompt,
  }) async {
    if (_disposed) {
      throw StateError('LlamaLocalGenkitBackend has been disposed.');
    }

    final config = configListenable.value;
    final activeBackend = _backend;
    if (activeBackend != null && identical(config, _activeConfig)) {
      return activeBackend;
    }
    final activeInitialization = _initialization;
    if (activeInitialization != null && identical(config, _activeConfig)) {
      return activeInitialization;
    }

    await _disposeBackend();
    _activeConfig = config;
    final initialization = _initializeBackend(
      config,
      warmUpSystemPrompt: warmUpSystemPrompt,
    );
    _initialization = initialization;
    try {
      return await initialization;
    } finally {
      if (identical(_initialization, initialization)) {
        _initialization = null;
      }
    }
  }

  Future<GenkitBackend<LlamaDartGenerationConfig>> _initializeBackend(
    ModelConfig config, {
    String? warmUpSystemPrompt,
  }) async {
    final task = llamaDart.prepareModelTask(
      name: config.modelName,
      source: config.modelSource,
      modelParams: config.inferenceOptions.toModelParams(),
      mmprojSource: config.mmprojSource,
      options: config.loadOptionsFor(
        config.modelSource,
        sha256: config.modelSha256,
      ),
      mmprojOptions: config.mmprojSource == null
          ? ModelLoadOptions.defaults
          : config.loadOptionsFor(
              config.mmprojSource!,
              sha256: config.mmprojSha256,
            ),
      supportsEmbeddings: false,
    );
    _preparationTask = task;
    _preparationSubscription = task.snapshots.listen((snapshot) {
      if (!identical(_preparationTask, task)) return;
      modelStatus.value = ModelRuntimeStatus.fromPreparation(
        config: config,
        snapshot: snapshot,
        assetLabel: switch (snapshot.sourceRole) {
          LlamaModelPreparationSourceRole.mmproj => 'Projector',
          _ => 'Model',
        },
      );
    });

    final prepared = await task.result;
    genkit.Genkit? ai;
    GenkitBackend<LlamaDartGenerationConfig>? backend;
    try {
      if (!identical(_preparationTask, task) || _disposed) {
        await prepared.dispose();
        throw StateError('Local model preparation was superseded.');
      }

      ai = prepared.createGenkit();
      await prepared.warmUp<Object?>(
        ai,
        systemPrompt: warmUpSystemPrompt,
        prompt: warmUpSystemPrompt == null || warmUpSystemPrompt.trim().isEmpty
            ? 'Reply with one token: ready'
            : 'Warm up the GenUI instruction prefix. Reply with one token: ready',
        config: LlamaDartGenerationConfig(
          temperature: 0,
          maxTokens: 1,
          enableThinking: config.enableThinking,
        ),
      );
      backend = GenkitBackend<LlamaDartGenerationConfig>(
        ai: ai,
        model: prepared.modelRef,
        config: LlamaDartGenerationConfig(
          temperature: config.temperature,
          maxTokens: config.maxTokens,
          enableThinking: config.enableThinking,
        ),
        onDispose: () async {
          await prepared.dispose();
          await ai!.shutdown();
        },
      );
      if (!identical(_preparationTask, task) || _disposed) {
        await backend.dispose();
        throw StateError('Local model preparation was superseded.');
      }

      _backend = backend;
      modelStatus.value = ModelRuntimeStatus.ready(
        config: config,
        resolvedModelPath: prepared.modelEntry.filePath,
      );
      return backend;
    } catch (_) {
      if (!identical(_backend, backend)) {
        await backend?.dispose();
      }
      if (backend == null) {
        await prepared.dispose();
        await ai?.shutdown();
      }
      rethrow;
    }
  }

  Future<void> _disposeBackend() async {
    final backend = _backend;
    final task = _preparationTask;
    _backend = null;
    _activeConfig = null;
    _initialization = null;
    _preparationTask = null;
    task?.cancel();
    await _preparationSubscription?.cancel();
    _preparationSubscription = null;
    await task?.dispose();
    await backend?.dispose();
  }
}
