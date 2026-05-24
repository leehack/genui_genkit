import 'package:flutter_test/flutter_test.dart';
import 'package:genui_genkit_llamadart/genui_genkit_llamadart.dart';
import 'package:llamadart/llamadart.dart' as llama;

void main() {
  test('mobile GenUI profile maps to llamadart model params', () {
    final params = LlamaDartInferenceOptions.mobileGenUi.toModelParams();

    expect(params.contextSize, 4096);
    expect(params.batchSize, 512);
    expect(params.microBatchSize, 256);
    expect(params.preferredBackend, llama.GpuBackend.auto);
    expect(params.cacheTypeK, llama.KvCacheType.f16);
    expect(params.cacheTypeV, llama.KvCacheType.f16);
  });

  test('mobile compact profile keeps the benchmark context size', () {
    final params = LlamaDartInferenceOptions.mobileCompact.toModelParams();

    expect(params.contextSize, 2048);
    expect(params.batchSize, 512);
    expect(params.microBatchSize, 128);
  });

  test('remote model load options keep cache policy and bearer token', () {
    final source = llama.ModelSource.parse('hf://owner/repo/model.gguf');
    final config = LlamaDartGenUiConfig(
      modelSource: source,
      cachePolicy: llama.ModelCachePolicy.refresh,
      bearerToken: 'token',
    );

    final options = config.loadOptionsFor(source, sha256: 'A' * 64);

    expect(options.cachePolicy, llama.ModelCachePolicy.refresh);
    expect(options.bearerToken, 'token');
    expect(options.sha256, 'a' * 64);
  });

  test('local model load options ignore remote-only controls', () {
    final source = llama.ModelSource.parse('/tmp/model.gguf');
    final config = LlamaDartGenUiConfig(
      modelSource: source,
      cachePolicy: llama.ModelCachePolicy.refresh,
      bearerToken: 'token',
    );

    final options = config.loadOptionsFor(source);

    expect(options.cachePolicy, llama.ModelCachePolicy.preferCached);
    expect(options.bearerToken, isNull);
  });
}
