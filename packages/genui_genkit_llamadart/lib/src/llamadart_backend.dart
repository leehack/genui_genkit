import 'dart:async';

import 'package:genkit/genkit.dart' as genkit;
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:genui_genkit/genui_genkit.dart';
import 'package:llamadart/llamadart.dart' as llama;

/// Load-time inference controls passed to llamadart.
///
/// These values are fixed once the model/context is loaded. Keep generation
/// controls such as temperature and max tokens on [LlamaDartGenUiConfig].
final class LlamaDartInferenceOptions {
  const LlamaDartInferenceOptions({
    this.contextSize = 4096,
    this.gpuLayers = llama.ModelParams.maxGpuLayers,
    this.preferredBackend = llama.GpuBackend.auto,
    this.splitMode = llama.ModelSplitMode.layer,
    this.mainGpu = 0,
    this.numberOfThreads = 0,
    this.numberOfThreadsBatch = 0,
    this.batchSize = 0,
    this.microBatchSize = 0,
    this.maxParallelSequences = 1,
    this.useMmap = true,
    this.useMlock = false,
    this.flashAttention = llama.FlashAttention.auto,
    this.cacheTypeK = llama.KvCacheType.f16,
    this.cacheTypeV = llama.KvCacheType.f16,
  });

  /// Smaller profile useful for plain chat benchmarks and very compact prompts.
  ///
  /// GenUI catalog/schema prompts need more room, so this is not the default.
  static const mobileCompact = LlamaDartInferenceOptions(
    contextSize: 2048,
    batchSize: 512,
    microBatchSize: 128,
  );

  /// Default local GenUI profile for mobile-class devices.
  ///
  /// The context leaves room for the compact A2UI catalog/schema prompt plus
  /// response budget while keeping the measured mobile batch settings.
  static const mobileGenUi = LlamaDartInferenceOptions(
    batchSize: 512,
    microBatchSize: 256,
  );

  /// Backwards-compatible alias for the default mobile GenUI profile.
  static const mobileBalanced = mobileGenUi;

  final int contextSize;
  final int gpuLayers;
  final llama.GpuBackend preferredBackend;
  final llama.ModelSplitMode splitMode;
  final int mainGpu;
  final int numberOfThreads;
  final int numberOfThreadsBatch;
  final int batchSize;
  final int microBatchSize;
  final int maxParallelSequences;
  final bool useMmap;
  final bool useMlock;
  final llama.FlashAttention flashAttention;
  final llama.KvCacheType cacheTypeK;
  final llama.KvCacheType cacheTypeV;

  LlamaDartInferenceOptions copyWith({
    int? contextSize,
    int? gpuLayers,
    llama.GpuBackend? preferredBackend,
    llama.ModelSplitMode? splitMode,
    int? mainGpu,
    int? numberOfThreads,
    int? numberOfThreadsBatch,
    int? batchSize,
    int? microBatchSize,
    int? maxParallelSequences,
    bool? useMmap,
    bool? useMlock,
    llama.FlashAttention? flashAttention,
    llama.KvCacheType? cacheTypeK,
    llama.KvCacheType? cacheTypeV,
  }) {
    return LlamaDartInferenceOptions(
      contextSize: contextSize ?? this.contextSize,
      gpuLayers: gpuLayers ?? this.gpuLayers,
      preferredBackend: preferredBackend ?? this.preferredBackend,
      splitMode: splitMode ?? this.splitMode,
      mainGpu: mainGpu ?? this.mainGpu,
      numberOfThreads: numberOfThreads ?? this.numberOfThreads,
      numberOfThreadsBatch: numberOfThreadsBatch ?? this.numberOfThreadsBatch,
      batchSize: batchSize ?? this.batchSize,
      microBatchSize: microBatchSize ?? this.microBatchSize,
      maxParallelSequences: maxParallelSequences ?? this.maxParallelSequences,
      useMmap: useMmap ?? this.useMmap,
      useMlock: useMlock ?? this.useMlock,
      flashAttention: flashAttention ?? this.flashAttention,
      cacheTypeK: cacheTypeK ?? this.cacheTypeK,
      cacheTypeV: cacheTypeV ?? this.cacheTypeV,
    );
  }

  llama.ModelParams toModelParams() {
    return llama.ModelParams(
      contextSize: contextSize,
      gpuLayers: gpuLayers,
      preferredBackend: preferredBackend,
      splitMode: splitMode,
      mainGpu: mainGpu,
      numberOfThreads: numberOfThreads,
      numberOfThreadsBatch: numberOfThreadsBatch,
      batchSize: batchSize,
      microBatchSize: microBatchSize,
      maxParallelSequences: maxParallelSequences,
      useMmap: useMmap,
      useMlock: useMlock,
      flashAttention: flashAttention,
      cacheTypeK: cacheTypeK,
      cacheTypeV: cacheTypeV,
    );
  }
}

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
    this.inferenceOptions = LlamaDartInferenceOptions.mobileGenUi,
    this.temperature = 0.2,
    this.maxTokens = 512,
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
  final LlamaDartInferenceOptions inferenceOptions;
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

  Future<void> prepare({String? warmUpSystemPrompt}) async {
    if (_disposed) {
      throw StateError('LlamaDartGenUiBackend has been disposed.');
    }
    await _ensureInitialized(warmUpSystemPrompt: warmUpSystemPrompt);
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

  Future<void> _ensureInitialized({String? warmUpSystemPrompt}) async {
    if (_backend != null) return;
    final activeInitialization = _initialization;
    if (activeInitialization != null) {
      await activeInitialization;
      return;
    }

    final initialization = _initialize(warmUpSystemPrompt: warmUpSystemPrompt);
    _initialization = initialization;
    try {
      await initialization;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _initialize({String? warmUpSystemPrompt}) async {
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

    LlamaDartPlugin? plugin;
    genkit.Genkit? ai;
    GenkitBackend<LlamaDartGenerationConfig>? backend;
    try {
      plugin = llamaDart(
        models: [
          LlamaModelDefinition(
            name: config.modelName,
            modelPath: modelEntry.filePath,
            mmprojPath: mmprojPath,
            modelParams: config.inferenceOptions.toModelParams(),
          ),
        ],
      );
      ai = genkit.Genkit(plugins: [plugin]);
      backend = GenkitBackend<LlamaDartGenerationConfig>(
        ai: ai,
        model: llamaDart.model(config.modelName),
        config: LlamaDartGenerationConfig(
          temperature: config.temperature,
          maxTokens: config.maxTokens,
          enableThinking: config.enableThinking,
        ),
      );

      _plugin = plugin;
      _ai = ai;
      _backend = backend;
      await _warmUp(ai, systemPrompt: warmUpSystemPrompt);
    } catch (_) {
      _backend = null;
      _plugin = null;
      _ai = null;
      await backend?.dispose();
      await plugin?.dispose();
      await ai?.shutdown();
      rethrow;
    }
  }

  Future<void> _warmUp(genkit.Genkit ai, {String? systemPrompt}) async {
    final trimmedSystemPrompt = systemPrompt?.trim();
    final stream = ai.generateStream<LlamaDartGenerationConfig, Object?>(
      model: llamaDart.model(config.modelName),
      messages: [
        if (trimmedSystemPrompt != null && trimmedSystemPrompt.isNotEmpty)
          genkit.Message(
            role: genkit.Role.system,
            content: [genkit.TextPart(text: trimmedSystemPrompt)],
          ),
        genkit.Message(
          role: genkit.Role.user,
          content: [
            genkit.TextPart(
              text: trimmedSystemPrompt == null || trimmedSystemPrompt.isEmpty
                  ? 'Reply with one token: ready'
                  : 'Warm up the GenUI instruction prefix. Reply with one token: ready',
            ),
          ],
        ),
      ],
      config: LlamaDartGenerationConfig(
        temperature: 0,
        maxTokens: 1,
        enableThinking: config.enableThinking,
      ),
    );

    await for (final _ in stream) {}
    await stream.onResult;
  }
}
