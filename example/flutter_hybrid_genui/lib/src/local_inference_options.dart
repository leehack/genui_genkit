import 'package:llamadart/llamadart.dart' as llama;

/// Load-time inference controls passed to llamadart for the local example route.
///
/// These values are fixed once the model/context is loaded. Generation controls
/// such as temperature and max tokens stay on the app model config.
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

  /// Smaller profile useful for plain chat benchmarks and compact prompts.
  static const mobileCompact = LlamaDartInferenceOptions(
    contextSize: 2048,
    batchSize: 512,
    microBatchSize: 128,
  );

  /// Default local GenUI profile for mobile-class devices.
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
