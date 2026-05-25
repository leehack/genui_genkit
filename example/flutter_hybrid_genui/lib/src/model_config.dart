import 'package:llamadart/llamadart.dart' as llama;
import 'package:path/path.dart' as p;

import 'local_inference_options.dart';

const defaultModelSource =
    'hf://unsloth/gemma-4-E2B-it-GGUF/gemma-4-E2B-it-Q4_K_S.gguf';
const defaultModelDisplayName = 'Gemma 4 E2B it Q4_K_S';
const defaultGeminiModelName = 'gemini-3.5-flash';
const defaultBackendEndpoint = 'http://localhost:8080/genui';

enum GenUiAiRoute { local, gemini, backend }

extension GenUiAiRouteLabel on GenUiAiRoute {
  String get label {
    return switch (this) {
      GenUiAiRoute.local => 'Local',
      GenUiAiRoute.gemini => 'Gemini',
      GenUiAiRoute.backend => 'Backend',
    };
  }

  String get metadataValue => name;
}

final class HybridAppConfig {
  const HybridAppConfig({
    required this.localModel,
    required this.gemini,
    required this.backend,
    required this.initialRoute,
  });

  factory HybridAppConfig.fromEnvironment(Map<String, String> environment) {
    return HybridAppConfig(
      localModel: ModelConfig.fromEnvironment(environment),
      gemini: GeminiModelConfig.fromEnvironment(environment),
      backend: BackendServerConfig.fromEnvironment(environment),
      initialRoute: _parseRoute(environment['GENUI_AI_ROUTE']),
    );
  }

  final ModelConfig localModel;
  final GeminiModelConfig gemini;
  final BackendServerConfig backend;
  final GenUiAiRoute initialRoute;

  static GenUiAiRoute _parseRoute(String? value) {
    final normalized = ModelConfig._emptyToNull(value)?.toLowerCase();
    return switch (normalized) {
      null => GenUiAiRoute.local,
      'local' ||
      'llama' ||
      'llamadart' ||
      'on-device' ||
      'on_device' => GenUiAiRoute.local,
      'gemini' || 'google' || 'googleai' || 'google_ai' => GenUiAiRoute.gemini,
      'backend' || 'server' || 'remote' || 'genkit' => GenUiAiRoute.backend,
      _ => throw FormatException('Invalid GenUI AI route: $value'),
    };
  }
}

final class GeminiModelConfig {
  const GeminiModelConfig({
    required this.modelName,
    this.apiKey,
    this.temperature = 0.2,
    this.maxTokens = 2048,
  });

  final String modelName;
  final String? apiKey;
  final double temperature;
  final int maxTokens;

  bool get hasApiKey => apiKey != null && apiKey!.isNotEmpty;

  bool sameRuntimeConfig(GeminiModelConfig other) {
    return modelName == other.modelName &&
        apiKey == other.apiKey &&
        temperature == other.temperature &&
        maxTokens == other.maxTokens;
  }

  static GeminiModelConfig fromEnvironment(Map<String, String> environment) {
    return GeminiModelConfig(
      modelName:
          ModelConfig._emptyToNull(environment['GENUI_GEMINI_MODEL']) ??
          defaultGeminiModelName,
      apiKey:
          ModelConfig._emptyToNull(environment['GENUI_GEMINI_API_KEY']) ??
          ModelConfig._emptyToNull(environment['GEMINI_API_KEY']) ??
          ModelConfig._emptyToNull(environment['GOOGLE_API_KEY']),
      temperature: ModelConfig._parseDouble(
        environment['GENUI_GEMINI_TEMPERATURE'],
        fallback: 0.2,
      ),
      maxTokens: ModelConfig._parseInt(
        environment['GENUI_GEMINI_MAX_TOKENS'],
        fallback: 2048,
      ),
    );
  }
}

final class BackendServerConfig {
  const BackendServerConfig({required this.endpoint});

  final Uri endpoint;

  bool sameRuntimeConfig(BackendServerConfig other) {
    return endpoint == other.endpoint;
  }

  static BackendServerConfig fromEnvironment(Map<String, String> environment) {
    return BackendServerConfig(
      endpoint: Uri.parse(
        ModelConfig._emptyToNull(environment['GENUI_BACKEND_URL']) ??
            defaultBackendEndpoint,
      ),
    );
  }
}

final class ModelConfig {
  const ModelConfig({
    required this.modelSource,
    required this.cacheDirectory,
    this.mmprojSource,
    this.modelSourceDisplayName = defaultModelDisplayName,
    this.modelSha256,
    this.mmprojSha256,
    this.bearerToken,
    this.cachePolicy = llama.ModelCachePolicy.preferCached,
    this.modelName = 'local-genui',
    this.inferenceOptions = LlamaDartInferenceOptions.mobileGenUi,
    this.temperature = 0,
    this.maxTokens = 512,
    this.enableThinking = false,
  });

  final llama.ModelSource modelSource;
  final llama.ModelSource? mmprojSource;
  final String modelSourceDisplayName;
  final String? cacheDirectory;
  final String? modelSha256;
  final String? mmprojSha256;
  final String? bearerToken;
  final llama.ModelCachePolicy cachePolicy;
  final String modelName;
  final LlamaDartInferenceOptions inferenceOptions;
  int get contextSize => inferenceOptions.contextSize;
  final double temperature;
  final int maxTokens;
  final bool enableThinking;

  ModelConfig copyWith({
    llama.ModelSource? modelSource,
    llama.ModelSource? mmprojSource,
    String? modelSourceDisplayName,
    String? cacheDirectory,
    String? modelSha256,
    String? mmprojSha256,
    String? bearerToken,
    llama.ModelCachePolicy? cachePolicy,
    String? modelName,
    LlamaDartInferenceOptions? inferenceOptions,
    double? temperature,
    int? maxTokens,
    bool? enableThinking,
  }) {
    return ModelConfig(
      modelSource: modelSource ?? this.modelSource,
      mmprojSource: mmprojSource ?? this.mmprojSource,
      modelSourceDisplayName:
          modelSourceDisplayName ?? this.modelSourceDisplayName,
      cacheDirectory: cacheDirectory ?? this.cacheDirectory,
      modelSha256: modelSha256 ?? this.modelSha256,
      mmprojSha256: mmprojSha256 ?? this.mmprojSha256,
      bearerToken: bearerToken ?? this.bearerToken,
      cachePolicy: cachePolicy ?? this.cachePolicy,
      modelName: modelName ?? this.modelName,
      inferenceOptions: inferenceOptions ?? this.inferenceOptions,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      enableThinking: enableThinking ?? this.enableThinking,
    );
  }

  static ModelConfig fromEnvironment(Map<String, String> environment) {
    final legacyModelPath = _emptyToNull(environment['LLAMADART_MODEL_PATH']);
    final rawModelSource =
        legacyModelPath ??
        _emptyToNull(environment['LLAMADART_GENUI_MODEL_SOURCE']) ??
        defaultModelSource;

    final legacyMmprojPath = _emptyToNull(environment['LLAMADART_MMPROJ_PATH']);
    final rawMmprojSource =
        legacyMmprojPath ??
        _emptyToNull(environment['LLAMADART_GENUI_MMPROJ_SOURCE']);

    return ModelConfig(
      modelSource: llama.ModelSource.parse(
        _expandHome(rawModelSource, environment),
      ),
      mmprojSource: rawMmprojSource == null
          ? null
          : llama.ModelSource.parse(_expandHome(rawMmprojSource, environment)),
      modelSourceDisplayName:
          _emptyToNull(environment['LLAMADART_GENUI_MODEL_LABEL']) ??
          (rawModelSource == defaultModelSource
              ? defaultModelDisplayName
              : null) ??
          _sourceDisplayName(rawModelSource),
      cacheDirectory:
          _emptyToNull(environment['LLAMADART_GENUI_CACHE_DIR']) ??
          _defaultCacheDirectory(environment),
      modelSha256: _emptyToNull(environment['LLAMADART_GENUI_MODEL_SHA256']),
      mmprojSha256: _emptyToNull(environment['LLAMADART_GENUI_MMPROJ_SHA256']),
      bearerToken:
          _emptyToNull(environment['LLAMADART_GENUI_BEARER_TOKEN']) ??
          _emptyToNull(environment['HUGGING_FACE_HUB_TOKEN']),
      cachePolicy: _parseCachePolicy(
        environment['LLAMADART_GENUI_CACHE_POLICY'],
      ),
      modelName:
          _emptyToNull(environment['LLAMADART_GENUI_MODEL_NAME']) ??
          'local-genui',
      inferenceOptions: LlamaDartInferenceOptions(
        contextSize: _parseInt(
          environment['LLAMADART_GENUI_CONTEXT_SIZE'],
          fallback: LlamaDartInferenceOptions.mobileGenUi.contextSize,
        ),
        gpuLayers: _parseInt(
          environment['LLAMADART_GENUI_GPU_LAYERS'],
          fallback: LlamaDartInferenceOptions.mobileGenUi.gpuLayers,
        ),
        preferredBackend: _parseGpuBackend(
          environment['LLAMADART_GENUI_GPU_BACKEND'],
          fallback: LlamaDartInferenceOptions.mobileGenUi.preferredBackend,
        ),
        numberOfThreads: _parseInt(
          environment['LLAMADART_GENUI_THREADS'],
          fallback: LlamaDartInferenceOptions.mobileGenUi.numberOfThreads,
        ),
        numberOfThreadsBatch: _parseInt(
          environment['LLAMADART_GENUI_THREADS_BATCH'],
          fallback: LlamaDartInferenceOptions.mobileGenUi.numberOfThreadsBatch,
        ),
        batchSize: _parseInt(
          environment['LLAMADART_GENUI_BATCH_SIZE'],
          fallback: LlamaDartInferenceOptions.mobileGenUi.batchSize,
        ),
        microBatchSize: _parseInt(
          environment['LLAMADART_GENUI_MICRO_BATCH_SIZE'],
          fallback: LlamaDartInferenceOptions.mobileGenUi.microBatchSize,
        ),
        flashAttention: _parseFlashAttention(
          environment['LLAMADART_GENUI_FLASH_ATTENTION'],
          fallback: LlamaDartInferenceOptions.mobileGenUi.flashAttention,
        ),
        cacheTypeK: _parseKvCacheType(
          environment['LLAMADART_GENUI_CACHE_TYPE_K'],
          fallback: LlamaDartInferenceOptions.mobileGenUi.cacheTypeK,
        ),
        cacheTypeV: _parseKvCacheType(
          environment['LLAMADART_GENUI_CACHE_TYPE_V'],
          fallback: LlamaDartInferenceOptions.mobileGenUi.cacheTypeV,
        ),
      ),
      maxTokens: _parseInt(
        environment['LLAMADART_GENUI_MAX_TOKENS'],
        fallback: 512,
      ),
      temperature: _parseDouble(
        environment['LLAMADART_GENUI_TEMPERATURE'],
        fallback: 0,
      ),
      enableThinking: _parseBool(
        environment['LLAMADART_GENUI_ENABLE_THINKING'],
        fallback: false,
      ),
    );
  }

  llama.ModelLoadOptions loadOptionsFor(
    llama.ModelSource source, {
    String? sha256,
  }) {
    if (source.isLocal) {
      return llama.ModelLoadOptions(sha256: sha256);
    }
    return llama.ModelLoadOptions(
      cachePolicy: cachePolicy,
      cacheDirectory: cacheDirectory,
      sha256: sha256,
      bearerToken: bearerToken,
    );
  }

  static String? _emptyToNull(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  static String _expandHome(String value, Map<String, String> environment) {
    if (!value.startsWith('~/') && !value.startsWith(r'~\')) return value;
    final home =
        _emptyToNull(environment['HOME']) ??
        _emptyToNull(environment['USERPROFILE']);
    if (home == null) return value;
    return p.join(home, value.substring(2));
  }

  static String? _defaultCacheDirectory(Map<String, String> environment) {
    final xdgCacheHome = _emptyToNull(environment['XDG_CACHE_HOME']);
    if (xdgCacheHome != null) {
      return p.join(xdgCacheHome, 'llamadart', 'genui');
    }
    final localAppData = _emptyToNull(environment['LOCALAPPDATA']);
    if (localAppData != null) {
      return p.join(localAppData, 'llamadart', 'genui');
    }
    final home =
        _emptyToNull(environment['HOME']) ??
        _emptyToNull(environment['USERPROFILE']);
    if (home == null) return null;
    return p.join(home, '.cache', 'llamadart', 'genui');
  }

  static String _sourceDisplayName(String source) {
    final parsed = llama.ModelSource.parse(source);
    return parsed.displayName;
  }

  static int _parseInt(String? value, {required int fallback}) {
    if (value == null || value.trim().isEmpty) return fallback;
    return int.parse(value);
  }

  static double _parseDouble(String? value, {required double fallback}) {
    if (value == null || value.trim().isEmpty) return fallback;
    return double.parse(value);
  }

  static bool _parseBool(String? value, {required bool fallback}) {
    if (value == null || value.trim().isEmpty) return fallback;
    return switch (value.trim().toLowerCase()) {
      '1' || 'true' || 'yes' || 'on' => true,
      '0' || 'false' || 'no' || 'off' => false,
      _ => throw FormatException('Invalid boolean value: $value'),
    };
  }

  static llama.ModelCachePolicy _parseCachePolicy(String? value) {
    if (value == null || value.trim().isEmpty) {
      return llama.ModelCachePolicy.preferCached;
    }
    return switch (value.trim().toLowerCase()) {
      'prefercached' ||
      'prefer_cached' ||
      'prefer-cached' => llama.ModelCachePolicy.preferCached,
      'refresh' => llama.ModelCachePolicy.refresh,
      'cacheonly' ||
      'cache_only' ||
      'cache-only' => llama.ModelCachePolicy.cacheOnly,
      'nocache' || 'no_cache' || 'no-cache' => llama.ModelCachePolicy.noCache,
      _ => throw FormatException('Invalid cache policy: $value'),
    };
  }

  static llama.GpuBackend _parseGpuBackend(
    String? value, {
    required llama.GpuBackend fallback,
  }) {
    final normalized = _normalizeToken(value);
    if (normalized == null) return fallback;
    return switch (normalized) {
      'auto' => llama.GpuBackend.auto,
      'cpu' => llama.GpuBackend.cpu,
      'vulkan' => llama.GpuBackend.vulkan,
      'metal' => llama.GpuBackend.metal,
      'cuda' => llama.GpuBackend.cuda,
      'blas' => llama.GpuBackend.blas,
      'opencl' => llama.GpuBackend.opencl,
      'hip' => llama.GpuBackend.hip,
      _ => throw FormatException('Invalid GPU backend: $value'),
    };
  }

  static llama.FlashAttention _parseFlashAttention(
    String? value, {
    required llama.FlashAttention fallback,
  }) {
    final normalized = _normalizeToken(value);
    if (normalized == null) return fallback;
    return switch (normalized) {
      'auto' => llama.FlashAttention.auto,
      'enabled' || 'enable' || 'on' || 'true' => llama.FlashAttention.enabled,
      'disabled' ||
      'disable' ||
      'off' ||
      'false' => llama.FlashAttention.disabled,
      _ => throw FormatException('Invalid flash attention value: $value'),
    };
  }

  static llama.KvCacheType _parseKvCacheType(
    String? value, {
    required llama.KvCacheType fallback,
  }) {
    final normalized = _normalizeToken(value);
    if (normalized == null) return fallback;
    return switch (normalized) {
      'f16' || 'fp16' => llama.KvCacheType.f16,
      'q8_0' || 'q80' || 'q8' => llama.KvCacheType.q8_0,
      'q4_0' || 'q40' || 'q4' => llama.KvCacheType.q4_0,
      _ => throw FormatException('Invalid KV cache type: $value'),
    };
  }

  static String? _normalizeToken(String? value) {
    final trimmed = _emptyToNull(value);
    if (trimmed == null) return null;
    return trimmed.toLowerCase().replaceAll('-', '_');
  }
}
