import 'package:flutter_hybrid_genui/src/model_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llamadart/llamadart.dart' as llama;

void main() {
  test('fromEnvironment uses a configurable default remote model source', () {
    final config = ModelConfig.fromEnvironment(const {'HOME': '/Users/test'});

    expect(config.modelSource.kind, llama.ModelSourceKind.huggingFace);
    expect(config.modelSource.canonicalKey, contains('gemma-4-E2B-it-GGUF'));
    expect(config.modelSourceDisplayName, defaultModelDisplayName);
    expect(config.cacheDirectory, '/Users/test/.cache/llamadart/genui');
  });

  test('fromEnvironment parses overrides', () {
    final config = ModelConfig.fromEnvironment(const {
      'LLAMADART_MODEL_PATH': '/models/model.gguf',
      'LLAMADART_MMPROJ_PATH': '/models/mmproj.gguf',
      'LLAMADART_GENUI_CACHE_DIR': '/models/cache',
      'LLAMADART_GENUI_CACHE_POLICY': 'refresh',
      'LLAMADART_GENUI_MODEL_NAME': 'custom-genui',
      'LLAMADART_GENUI_CONTEXT_SIZE': '16384',
      'LLAMADART_GENUI_MAX_TOKENS': '1024',
      'LLAMADART_GENUI_TEMPERATURE': '0.1',
      'LLAMADART_GENUI_ENABLE_THINKING': 'true',
    });

    expect(config.modelSource.path, '/models/model.gguf');
    expect(config.mmprojSource!.path, '/models/mmproj.gguf');
    expect(config.cacheDirectory, '/models/cache');
    expect(config.cachePolicy, llama.ModelCachePolicy.refresh);
    expect(config.modelName, 'custom-genui');
    expect(config.contextSize, 16384);
    expect(config.maxTokens, 1024);
    expect(config.temperature, 0.1);
    expect(config.enableThinking, isTrue);
  });

  test('fromEnvironment expands home-relative local paths', () {
    final config = ModelConfig.fromEnvironment(const {
      'HOME': '/Users/test',
      'LLAMADART_GENUI_MODEL_SOURCE': '~/Models/local.gguf',
    });

    expect(config.modelSource.path, '/Users/test/Models/local.gguf');
  });

  test('HybridAppConfig parses route and remote providers', () {
    final config = HybridAppConfig.fromEnvironment(const {
      'HOME': '/Users/test',
      'GENUI_AI_ROUTE': 'backend',
      'GENUI_BACKEND_URL': 'http://localhost:9090/genui',
      'GENUI_GEMINI_API_KEY': 'secret',
      'GENUI_GEMINI_MODEL': 'gemini-custom',
      'GENUI_GEMINI_TEMPERATURE': '0.4',
      'GENUI_GEMINI_MAX_TOKENS': '768',
    });

    expect(config.initialRoute, GenUiAiRoute.backend);
    expect(config.backend.endpoint, Uri.parse('http://localhost:9090/genui'));
    expect(config.gemini.hasApiKey, isTrue);
    expect(config.gemini.modelName, 'gemini-custom');
    expect(config.gemini.temperature, 0.4);
    expect(config.gemini.maxTokens, 768);
  });

  test('HybridAppConfig defaults Gemini to 3.5 Flash', () {
    final config = HybridAppConfig.fromEnvironment(const {
      'HOME': '/Users/test',
    });

    expect(config.gemini.modelName, 'gemini-3.5-flash');
  });
}
