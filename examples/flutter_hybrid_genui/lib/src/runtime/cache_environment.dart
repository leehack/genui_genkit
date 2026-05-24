import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _cacheDirectoryKey = 'LLAMADART_GENUI_CACHE_DIR';

Map<String, String> environmentWithDartDefines(
  Map<String, String> environment,
) {
  return environmentWithOverrides(environment, const {
    'GENUI_AI_ROUTE': String.fromEnvironment('GENUI_AI_ROUTE'),
    'GENUI_BACKEND_URL': String.fromEnvironment('GENUI_BACKEND_URL'),
    'GENUI_GEMINI_API_KEY': String.fromEnvironment('GENUI_GEMINI_API_KEY'),
    'GEMINI_API_KEY': String.fromEnvironment('GEMINI_API_KEY'),
    'GOOGLE_API_KEY': String.fromEnvironment('GOOGLE_API_KEY'),
    'GENUI_GEMINI_MODEL': String.fromEnvironment('GENUI_GEMINI_MODEL'),
    'GENUI_GEMINI_TEMPERATURE': String.fromEnvironment(
      'GENUI_GEMINI_TEMPERATURE',
    ),
    'GENUI_GEMINI_MAX_TOKENS': String.fromEnvironment(
      'GENUI_GEMINI_MAX_TOKENS',
    ),
    'LLAMADART_MODEL_PATH': String.fromEnvironment('LLAMADART_MODEL_PATH'),
    'LLAMADART_MMPROJ_PATH': String.fromEnvironment('LLAMADART_MMPROJ_PATH'),
    'LLAMADART_GENUI_MODEL_SOURCE': String.fromEnvironment(
      'LLAMADART_GENUI_MODEL_SOURCE',
    ),
    'LLAMADART_GENUI_MODEL_LABEL': String.fromEnvironment(
      'LLAMADART_GENUI_MODEL_LABEL',
    ),
    'LLAMADART_GENUI_MMPROJ_SOURCE': String.fromEnvironment(
      'LLAMADART_GENUI_MMPROJ_SOURCE',
    ),
    'LLAMADART_GENUI_CACHE_DIR': String.fromEnvironment(
      'LLAMADART_GENUI_CACHE_DIR',
    ),
    'LLAMADART_GENUI_CACHE_POLICY': String.fromEnvironment(
      'LLAMADART_GENUI_CACHE_POLICY',
    ),
    'LLAMADART_GENUI_MODEL_SHA256': String.fromEnvironment(
      'LLAMADART_GENUI_MODEL_SHA256',
    ),
    'LLAMADART_GENUI_MMPROJ_SHA256': String.fromEnvironment(
      'LLAMADART_GENUI_MMPROJ_SHA256',
    ),
    'LLAMADART_GENUI_BEARER_TOKEN': String.fromEnvironment(
      'LLAMADART_GENUI_BEARER_TOKEN',
    ),
    'HUGGING_FACE_HUB_TOKEN': String.fromEnvironment('HUGGING_FACE_HUB_TOKEN'),
    'LLAMADART_GENUI_MODEL_NAME': String.fromEnvironment(
      'LLAMADART_GENUI_MODEL_NAME',
    ),
    'LLAMADART_GENUI_CONTEXT_SIZE': String.fromEnvironment(
      'LLAMADART_GENUI_CONTEXT_SIZE',
    ),
    'LLAMADART_GENUI_GPU_BACKEND': String.fromEnvironment(
      'LLAMADART_GENUI_GPU_BACKEND',
    ),
    'LLAMADART_GENUI_GPU_LAYERS': String.fromEnvironment(
      'LLAMADART_GENUI_GPU_LAYERS',
    ),
    'LLAMADART_GENUI_THREADS': String.fromEnvironment(
      'LLAMADART_GENUI_THREADS',
    ),
    'LLAMADART_GENUI_THREADS_BATCH': String.fromEnvironment(
      'LLAMADART_GENUI_THREADS_BATCH',
    ),
    'LLAMADART_GENUI_BATCH_SIZE': String.fromEnvironment(
      'LLAMADART_GENUI_BATCH_SIZE',
    ),
    'LLAMADART_GENUI_MICRO_BATCH_SIZE': String.fromEnvironment(
      'LLAMADART_GENUI_MICRO_BATCH_SIZE',
    ),
    'LLAMADART_GENUI_FLASH_ATTENTION': String.fromEnvironment(
      'LLAMADART_GENUI_FLASH_ATTENTION',
    ),
    'LLAMADART_GENUI_CACHE_TYPE_K': String.fromEnvironment(
      'LLAMADART_GENUI_CACHE_TYPE_K',
    ),
    'LLAMADART_GENUI_CACHE_TYPE_V': String.fromEnvironment(
      'LLAMADART_GENUI_CACHE_TYPE_V',
    ),
    'LLAMADART_GENUI_MAX_TOKENS': String.fromEnvironment(
      'LLAMADART_GENUI_MAX_TOKENS',
    ),
    'LLAMADART_GENUI_TEMPERATURE': String.fromEnvironment(
      'LLAMADART_GENUI_TEMPERATURE',
    ),
    'LLAMADART_GENUI_ENABLE_THINKING': String.fromEnvironment(
      'LLAMADART_GENUI_ENABLE_THINKING',
    ),
  });
}

Map<String, String> environmentWithOverrides(
  Map<String, String> environment,
  Map<String, String> overrides,
) {
  final resolved = Map<String, String>.of(environment);
  for (final entry in overrides.entries) {
    final value = entry.value.trim();
    if (value.isNotEmpty) {
      resolved[entry.key] = value;
    }
  }
  return resolved;
}

Future<Map<String, String>> resolveEnvironmentForFlutterApp(
  Map<String, String> environment,
) async {
  final isMobile = Platform.isAndroid || Platform.isIOS;
  if (!isMobile || _hasExplicitCacheDirectory(environment)) {
    return Map<String, String>.of(environment);
  }

  final supportDirectory = await getApplicationSupportDirectory();
  return environmentWithAppSupportModelCache(
    environment,
    applicationSupportPath: supportDirectory.path,
    isMobile: isMobile,
  );
}

Map<String, String> environmentWithAppSupportModelCache(
  Map<String, String> environment, {
  required String applicationSupportPath,
  required bool isMobile,
}) {
  final resolved = Map<String, String>.of(environment);
  if (!isMobile || _hasExplicitCacheDirectory(resolved)) {
    return resolved;
  }

  resolved[_cacheDirectoryKey] = p.join(
    applicationSupportPath,
    'llamadart',
    'genui',
  );
  return resolved;
}

bool _hasExplicitCacheDirectory(Map<String, String> environment) {
  return (environment[_cacheDirectoryKey]?.trim().isNotEmpty ?? false);
}
