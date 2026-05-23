import 'dart:async';

import 'package:genkit/genkit.dart' as genkit;
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:genui_genkit/genui_genkit.dart';
import 'package:llamadart/llamadart.dart' as llama;

/// Configuration for the optional llamadart-backed GenUI backend.
final class LlamaDartGenUiConfig {
  const LlamaDartGenUiConfig({
    required this.modelSource,
    this.mmprojSource,
    this.modelName = 'local-genui',
    this.cacheDirectory,
    this.cachePolicy = llama.ModelCachePolicy.preferCached,
    this.modelSha256,
    this.mmprojSha256,
    this.bearerToken,
    this.contextSize = 8192,
    this.temperature = 0.2,
    this.maxTokens = 2048,
    this.enableThinking = false,
  });

  final llama.ModelSource modelSource;
  final llama.ModelSource? mmprojSource;
  final String modelName;
  final String? cacheDirectory;
  final llama.ModelCachePolicy cachePolicy;
  final String? modelSha256;
  final String? mmprojSha256;
  final String? bearerToken;
  final int contextSize;
  final double temperature;
  final int maxTokens;
  final bool enableThinking;

  llama.ModelLoadOptions loadOptionsFor(
    llama.ModelSource source, {
    String? sha256,
  }) {
    return llama.ModelLoadOptions(
      cachePolicy: source.isLocal
          ? llama.ModelCachePolicy.preferCached
          : cachePolicy,
      sha256: sha256,
      bearerToken: source.isLocal ? null : bearerToken,
    );
  }
}

/// GenUI backend that runs Genkit against an on-device llamadart model.
///
/// The backend resolves [LlamaDartGenUiConfig.modelSource] through llamadart's
/// download/cache manager, registers the resolved file with `genkit_llamadart`,
/// and delegates generation to `GenkitBackend`.
final class LlamaDartGenUiBackend implements GenUiBackend {
  LlamaDartGenUiBackend(
    this.config, {
    llama.ModelDownloadManager? downloadManager,
  }) : _downloadController = llama.ModelDownloadController(
         manager:
             downloadManager ??
             llama.DefaultModelDownloadManager(
               defaultCacheDirectory: config.cacheDirectory,
             ),
       );

  final LlamaDartGenUiConfig config;
  final llama.ModelDownloadController _downloadController;

  LlamaDartPlugin? _plugin;
  genkit.Genkit? _ai;
  GenkitBackend<LlamaDartGenerationConfig>? _backend;
  Future<void>? _initialization;
  var _disposed = false;

  Stream<llama.ModelDownloadTaskSnapshot> get snapshots =>
      _downloadController.snapshots;

  Future<void> prepare() async {
    if (_disposed) {
      throw StateError('LlamaDartGenUiBackend has been disposed.');
    }
    await _ensureInitialized();
  }

  @override
  Stream<GenUiBackendEvent> send(GenUiTurnRequest request) async* {
    if (_disposed) {
      yield const GenUiBackendError('LlamaDartGenUiBackend has been disposed.');
      return;
    }

    try {
      await _ensureInitialized();
    } catch (error, stackTrace) {
      yield GenUiBackendError(
        error.toString(),
        cause: error,
        stackTrace: stackTrace,
      );
      return;
    }

    yield* _backend!.send(request);
  }

  @override
  Future<void> cancelActiveTurn() async {
    await _backend?.cancelActiveTurn();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _backend?.dispose();
    await _downloadController.dispose();
    await _plugin?.dispose();
    await _ai?.shutdown();
    _backend = null;
    _plugin = null;
    _ai = null;
    _initialization = null;
  }

  Future<void> _ensureInitialized() async {
    if (_backend != null) return;
    final activeInitialization = _initialization;
    if (activeInitialization != null) {
      await activeInitialization;
      return;
    }

    final initialization = _initialize();
    _initialization = initialization;
    try {
      await initialization;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    final modelEntry = await _downloadController.start(
      config.modelSource,
      options: config.loadOptionsFor(
        config.modelSource,
        sha256: config.modelSha256,
      ),
    );

    String? mmprojPath;
    final mmprojSource = config.mmprojSource;
    if (mmprojSource != null) {
      final mmprojEntry = await _downloadController.start(
        mmprojSource,
        options: config.loadOptionsFor(
          mmprojSource,
          sha256: config.mmprojSha256,
        ),
      );
      mmprojPath = mmprojEntry.filePath;
    }

    final plugin = llamaDart(
      models: [
        LlamaModelDefinition(
          name: config.modelName,
          modelPath: modelEntry.filePath,
          mmprojPath: mmprojPath,
          modelParams: llama.ModelParams(contextSize: config.contextSize),
        ),
      ],
    );
    final ai = genkit.Genkit(plugins: [plugin]);
    _plugin = plugin;
    _ai = ai;
    _backend = GenkitBackend<LlamaDartGenerationConfig>(
      ai: ai,
      model: llamaDart.model(config.modelName),
      config: LlamaDartGenerationConfig(
        temperature: config.temperature,
        maxTokens: config.maxTokens,
        enableThinking: config.enableThinking,
      ),
    );
  }
}
