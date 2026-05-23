import 'package:genui_backend_server/src/server_config.dart';
import 'package:test/test.dart';

void main() {
  test('uses backend server defaults', () {
    final config = GenUiBackendServerConfig.fromEnvironment(const {
      'HOME': '/Users/test',
    });

    expect(config.modelName, 'backend-gemma4');
    expect(config.modelSource.canonicalKey, contains('gemma-4-E2B-it-GGUF'));
    expect(config.modelSourceDisplayName, defaultModelDisplayName);
    expect(config.cacheDirectory, '/Users/test/.cache/llamadart/genui');
    expect(config.port, defaultServerPort);
    expect(config.temperature, 0.2);
    expect(config.maxTokens, 2048);
    expect(config.contextSize, 8192);
  });

  test('parses Gemma and server overrides', () {
    final config = GenUiBackendServerConfig.fromEnvironment(const {
      'HOME': '/Users/test',
      'GENUI_BACKEND_MODEL_SOURCE': '~/Models/gemma4.gguf',
      'GENUI_BACKEND_MODEL_LABEL': 'Gemma local',
      'GENUI_BACKEND_MODEL_NAME': 'gemma-local',
      'GENUI_BACKEND_PORT': '8099',
      'GENUI_BACKEND_CACHE_DIR': '/models/cache',
      'GENUI_BACKEND_TEMPERATURE': '0.1',
      'GENUI_BACKEND_MAX_TOKENS': '512',
      'GENUI_BACKEND_CONTEXT_SIZE': '4096',
      'GENUI_BACKEND_ENABLE_THINKING': 'true',
    });

    expect(config.modelSource.path, '/Users/test/Models/gemma4.gguf');
    expect(config.modelSourceDisplayName, 'Gemma local');
    expect(config.modelName, 'gemma-local');
    expect(config.port, 8099);
    expect(config.cacheDirectory, '/models/cache');
    expect(config.temperature, 0.1);
    expect(config.maxTokens, 512);
    expect(config.contextSize, 4096);
    expect(config.enableThinking, isTrue);
  });
}
