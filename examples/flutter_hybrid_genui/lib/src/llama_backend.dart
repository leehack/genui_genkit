import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:genui_genkit/genui_genkit.dart';
import 'package:genui_genkit_llamadart/genui_genkit_llamadart.dart';
import 'package:llamadart/llamadart.dart' as llama;

import 'model_config.dart';
import 'runtime/app_runtime.dart';

final class LlamaLocalGenkitBackend implements GenUiBackend {
  LlamaLocalGenkitBackend(this.config, {required this.modelStatus})
    : _backend = LlamaDartGenUiBackend(
        LlamaDartGenUiConfig(
          modelSource: config.modelSource,
          mmprojSource: config.mmprojSource,
          modelName: config.modelName,
          cacheDirectory: config.cacheDirectory,
          cachePolicy: config.cachePolicy,
          modelSha256: config.modelSha256,
          mmprojSha256: config.mmprojSha256,
          bearerToken: config.bearerToken,
          contextSize: config.contextSize,
          temperature: config.temperature,
          maxTokens: config.maxTokens,
          enableThinking: config.enableThinking,
        ),
      ) {
    _downloadSubscription = _backend.snapshots.listen((snapshot) {
      modelStatus.value = ModelRuntimeStatus.fromDownload(
        config: config,
        snapshot: snapshot,
        assetLabel: 'Model',
      );
    });
  }

  final ModelConfig config;
  final ValueNotifier<ModelRuntimeStatus> modelStatus;
  final LlamaDartGenUiBackend _backend;

  StreamSubscription<llama.ModelDownloadTaskSnapshot>? _downloadSubscription;

  Future<void> prepare() async {
    await _backend.prepare();
  }

  @override
  Stream<GenUiBackendEvent> send(GenUiTurnRequest request) async* {
    try {
      await _backend.prepare();
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

    yield* _backend.send(request);
  }

  @override
  Future<void> cancelActiveTurn() async {
    await _backend.cancelActiveTurn();
  }

  @override
  Future<void> dispose() async {
    await _downloadSubscription?.cancel();
    await _backend.dispose();
  }
}
