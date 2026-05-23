import 'package:llamadart/llamadart.dart' as llama;
import 'package:path/path.dart' as p;

const defaultModelSource =
    'hf://unsloth/gemma-4-E2B-it-GGUF/gemma-4-E2B-it-Q4_K_S.gguf';
const defaultModelDisplayName = 'Gemma 4 E2B it Q4_K_S';
const defaultServerPort = 8080;

final class GenUiBackendServerConfig {
  const GenUiBackendServerConfig({
    required this.modelSource,
    required this.port,
    this.modelSourceDisplayName = defaultModelDisplayName,
    this.cacheDirectory,
    this.modelSha256,
    this.bearerToken,
    this.cachePolicy = llama.ModelCachePolicy.preferCached,
    this.modelName = 'backend-gemma4',
    this.contextSize = 8192,
    this.temperature = 0.2,
    this.maxTokens = 2048,
    this.enableThinking = false,
  });

  factory GenUiBackendServerConfig.fromEnvironment(
    Map<String, String> environment,
  ) {
    final rawModelSource =
        _emptyToNull(environment['GENUI_BACKEND_MODEL_SOURCE']) ??
        _emptyToNull(environment['LLAMADART_GENUI_MODEL_SOURCE']) ??
        defaultModelSource;

    return GenUiBackendServerConfig(
      modelSource: llama.ModelSource.parse(
        _expandHome(rawModelSource, environment),
      ),
      port: _parseInt(
        _emptyToNull(environment['GENUI_BACKEND_PORT']) ??
            _emptyToNull(environment['PORT']),
        fallback: defaultServerPort,
      ),
      modelSourceDisplayName:
          _emptyToNull(environment['GENUI_BACKEND_MODEL_LABEL']) ??
          (rawModelSource == defaultModelSource
              ? defaultModelDisplayName
              : null) ??
          llama.ModelSource.parse(rawModelSource).displayName,
      cacheDirectory:
          _emptyToNull(environment['GENUI_BACKEND_CACHE_DIR']) ??
          _emptyToNull(environment['LLAMADART_GENUI_CACHE_DIR']) ??
          _defaultCacheDirectory(environment),
      modelSha256:
          _emptyToNull(environment['GENUI_BACKEND_MODEL_SHA256']) ??
          _emptyToNull(environment['LLAMADART_GENUI_MODEL_SHA256']),
      bearerToken:
          _emptyToNull(environment['GENUI_BACKEND_BEARER_TOKEN']) ??
          _emptyToNull(environment['LLAMADART_GENUI_BEARER_TOKEN']) ??
          _emptyToNull(environment['HUGGING_FACE_HUB_TOKEN']),
      cachePolicy: _parseCachePolicy(
        _emptyToNull(environment['GENUI_BACKEND_CACHE_POLICY']) ??
            _emptyToNull(environment['LLAMADART_GENUI_CACHE_POLICY']),
      ),
      modelName:
          _emptyToNull(environment['GENUI_BACKEND_MODEL_NAME']) ??
          'backend-gemma4',
      contextSize: _parseInt(
        environment['GENUI_BACKEND_CONTEXT_SIZE'],
        fallback: 8192,
      ),
      temperature: _parseDouble(
        environment['GENUI_BACKEND_TEMPERATURE'],
        fallback: 0.2,
      ),
      maxTokens: _parseInt(
        environment['GENUI_BACKEND_MAX_TOKENS'],
        fallback: 2048,
      ),
      enableThinking: _parseBool(
        environment['GENUI_BACKEND_ENABLE_THINKING'],
        fallback: false,
      ),
    );
  }

  final llama.ModelSource modelSource;
  final String modelSourceDisplayName;
  final String? cacheDirectory;
  final String? modelSha256;
  final String? bearerToken;
  final llama.ModelCachePolicy cachePolicy;
  final String modelName;
  final int port;
  final int contextSize;
  final double temperature;
  final int maxTokens;
  final bool enableThinking;

  llama.ModelLoadOptions loadOptionsFor(llama.ModelSource source) {
    return llama.ModelLoadOptions(
      cachePolicy: source.isLocal
          ? llama.ModelCachePolicy.preferCached
          : cachePolicy,
      sha256: modelSha256,
      bearerToken: source.isLocal ? null : bearerToken,
    );
  }
}

String? _emptyToNull(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value.trim();
}

int _parseInt(String? value, {required int fallback}) {
  if (value == null || value.trim().isEmpty) return fallback;
  return int.parse(value);
}

double _parseDouble(String? value, {required double fallback}) {
  if (value == null || value.trim().isEmpty) return fallback;
  return double.parse(value);
}

bool _parseBool(String? value, {required bool fallback}) {
  if (value == null || value.trim().isEmpty) return fallback;
  return switch (value.trim().toLowerCase()) {
    '1' || 'true' || 'yes' || 'on' => true,
    '0' || 'false' || 'no' || 'off' => false,
    _ => throw FormatException('Invalid boolean value: $value'),
  };
}

llama.ModelCachePolicy _parseCachePolicy(String? value) {
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

String _expandHome(String value, Map<String, String> environment) {
  if (!value.startsWith('~/') && !value.startsWith(r'~\')) return value;
  final home =
      _emptyToNull(environment['HOME']) ??
      _emptyToNull(environment['USERPROFILE']);
  if (home == null) return value;
  return p.join(home, value.substring(2));
}

String? _defaultCacheDirectory(Map<String, String> environment) {
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
