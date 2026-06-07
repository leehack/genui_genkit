import 'package:flutter_hybrid_genui/src/activity_catalog.dart';
import 'package:flutter_hybrid_genui/src/activity_prompt.dart';
import 'package:flutter_hybrid_genui/src/local_inference_options.dart';
import 'package:flutter_hybrid_genui/src/model_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_genkit/genui_genkit.dart';
import 'package:llamadart/llamadart.dart' as llama;

void main() {
  test('fromEnvironment uses a configurable default remote model source', () {
    final config = ModelConfig.fromEnvironment(const {'HOME': '/Users/test'});

    expect(config.modelSource.kind, llama.ModelSourceKind.huggingFace);
    expect(config.modelSource.canonicalKey, contains('gemma-4-E2B-it-GGUF'));
    expect(config.modelSourceDisplayName, defaultModelDisplayName);
    expect(config.cacheDirectory, '/Users/test/.cache/llamadart/genui');
    expect(config.contextSize, 4096);
    expect(config.inferenceOptions.batchSize, 512);
    expect(config.inferenceOptions.microBatchSize, 256);
    expect(
      config.inferenceOptions.liteRtLmBackend,
      llama.LiteRtLmBackendPreference.auto,
    );
    expect(config.isLiteRtLmModel, isFalse);
    expect(config.maxTokens, 512);
    expect(config.temperature, 0);
  });

  test('default local context leaves room for the GenUI catalog prompt', () {
    final config = ModelConfig.fromEnvironment(const {'HOME': '/Users/test'});
    final prompt = activityGenUiSystemPromptBuilder([
      activityCatalog,
    ], const GenUiSystemPromptOptions());
    final approximatePromptTokens = (prompt.length / 3).ceil();

    expect(
      approximatePromptTokens + config.maxTokens,
      lessThan(config.contextSize),
    );
  });

  test('compact GenUI prompt is smaller than the default builder', () {
    final compactPrompt = activityGenUiSystemPromptBuilder([
      activityCatalog,
    ], const GenUiSystemPromptOptions());
    final defaultPrompt = defaultGenUiSystemPromptBuilder([
      activityCatalog,
    ], const GenUiSystemPromptOptions());

    expect(compactPrompt.length, lessThan(defaultPrompt.length * 0.75));
  });

  test('activity GenUI prompt contains minimal A2UI shape guidance', () {
    final prompt = activityGenUiSystemPromptBuilder([
      activityCatalog,
    ], const GenUiSystemPromptOptions());

    expect(prompt, contains('"createSurface"'));
    expect(prompt, contains('"updateComponents"'));
    expect(prompt, contains('"version":"v0.9"'));
    expect(prompt, contains('"component":"ItineraryPlan"'));
    expect(prompt, contains('children as component id strings'));
  });

  test('fromEnvironment parses overrides', () {
    final config = ModelConfig.fromEnvironment(const {
      'LLAMADART_MODEL_PATH': '/models/model.gguf',
      'LLAMADART_MMPROJ_PATH': '/models/mmproj.gguf',
      'LLAMADART_GENUI_CACHE_DIR': '/models/cache',
      'LLAMADART_GENUI_CACHE_POLICY': 'refresh',
      'LLAMADART_GENUI_MODEL_NAME': 'custom-genui',
      'LLAMADART_GENUI_CONTEXT_SIZE': '16384',
      'LLAMADART_GENUI_GPU_BACKEND': 'cpu',
      'LLAMADART_GENUI_LITERT_LM_BACKEND': 'npu',
      'LLAMADART_GENUI_GPU_LAYERS': '0',
      'LLAMADART_GENUI_THREADS': '4',
      'LLAMADART_GENUI_THREADS_BATCH': '4',
      'LLAMADART_GENUI_BATCH_SIZE': '256',
      'LLAMADART_GENUI_MICRO_BATCH_SIZE': '128',
      'LLAMADART_GENUI_FLASH_ATTENTION': 'disabled',
      'LLAMADART_GENUI_CACHE_TYPE_K': 'q8_0',
      'LLAMADART_GENUI_CACHE_TYPE_V': 'q8_0',
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
    expect(config.inferenceOptions.preferredBackend, llama.GpuBackend.cpu);
    expect(
      config.inferenceOptions.liteRtLmBackend,
      llama.LiteRtLmBackendPreference.npu,
    );
    expect(config.inferenceOptions.gpuLayers, 0);
    expect(config.inferenceOptions.numberOfThreads, 4);
    expect(config.inferenceOptions.numberOfThreadsBatch, 4);
    expect(config.inferenceOptions.batchSize, 256);
    expect(config.inferenceOptions.microBatchSize, 128);
    expect(
      config.inferenceOptions.flashAttention,
      llama.FlashAttention.disabled,
    );
    expect(config.inferenceOptions.cacheTypeK, llama.KvCacheType.q8_0);
    expect(config.inferenceOptions.cacheTypeV, llama.KvCacheType.q8_0);
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

  test('fromEnvironment recognizes LiteRT-LM model sources', () {
    final config = ModelConfig.fromEnvironment(const {
      'HOME': '/Users/test',
      'LLAMADART_GENUI_MODEL_SOURCE':
          'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm?download=true',
      'LLAMADART_GENUI_LITERT_LM_BACKEND': 'gpu',
    });

    expect(config.modelSource.fileName, 'gemma-4-E2B-it.litertlm');
    expect(config.isLiteRtLmModel, isTrue);
    expect(
      config.inferenceOptions.liteRtLmBackend,
      llama.LiteRtLmBackendPreference.gpu,
    );

    final params = config.inferenceOptions.toModelParams(
      liteRtLmModel: config.isLiteRtLmModel,
    );
    expect(params.liteRtLmBackend, llama.LiteRtLmBackendPreference.gpu);
    expect(params.batchSize, 0);
    expect(params.microBatchSize, 0);
  });

  test('toModelParams keeps llama.cpp knobs out of LiteRT-LM loads', () {
    const options = LlamaDartInferenceOptions(
      contextSize: 2048,
      gpuLayers: 0,
      preferredBackend: llama.GpuBackend.cpu,
      liteRtLmBackend: llama.LiteRtLmBackendPreference.gpu,
      batchSize: 512,
      microBatchSize: 128,
    );

    final params = options.toModelParams(liteRtLmModel: true);

    expect(params.contextSize, 2048);
    expect(params.liteRtLmBackend, llama.LiteRtLmBackendPreference.gpu);
    expect(params.gpuLayers, llama.ModelParams.maxGpuLayers);
    expect(params.preferredBackend, llama.GpuBackend.auto);
    expect(params.batchSize, 0);
    expect(params.microBatchSize, 0);
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
