import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_hybrid_genui/src/model_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:llamadart/llamadart.dart' as llama;

const _runBenchmark = bool.fromEnvironment('GENUI_RUN_LOCAL_BENCHMARK');
const _modelSource = String.fromEnvironment(
  'LLAMADART_GENUI_MODEL_SOURCE',
  defaultValue: defaultModelSource,
);
const _expectedModelBytes = int.fromEnvironment('LLAMADART_GENUI_MODEL_BYTES');
const _profileFilter = String.fromEnvironment('GENUI_BENCHMARK_PROFILE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'benchmarks llamadart local inference profiles',
    skip: !_runBenchmark,
    timeout: const Timeout(Duration(minutes: 45)),
    (tester) async {
      final source = llama.ModelSource.parse(_modelSource);
      if (source.isLocal) {
        await _waitForLocalModelFile(source.path!);
      }

      final controller = llama.ModelDownloadController();
      addTearDown(controller.dispose);

      final entry = await controller.start(
        source,
        options: llama.ModelLoadOptions(
          cachePolicy: source.isLocal
              ? llama.ModelCachePolicy.preferCached
              : llama.ModelCachePolicy.cacheOnly,
        ),
      );

      _logBenchmark({
        'event': 'model_ready',
        'modelSource': _modelSource,
        'fileName': entry.fileName,
        'bytes': entry.bytes,
      });

      final results = <_BenchmarkResult>[];
      for (final profile in _selectedProfiles()) {
        final result = await _runProfile(profile, entry.filePath);
        results.add(result);
        _logBenchmark({'event': 'profile_result', ...result.toJson()});
        await tester.pump(const Duration(seconds: 1));
      }

      final successful = results.where((result) => result.error == null);
      final ranked = successful.toList()
        ..sort(
          (a, b) => b.decodeTokensPerSecond.compareTo(a.decodeTokensPerSecond),
        );

      _logBenchmark({
        'event': 'profile_ranking',
        'profiles': [
          for (final result in ranked)
            {
              'name': result.profile.name,
              'decodeTokensPerSecond': result.decodeTokensPerSecond,
              'promptTokensPerSecond': result.promptTokensPerSecond,
              'timeToFirstChunkMs': result.timeToFirstChunkMs,
              'totalMs': result.totalMs,
            },
        ],
      });
    },
  );
}

Iterable<_BenchmarkProfile> _selectedProfiles() {
  if (_profileFilter.trim().isEmpty) return _profiles;
  final pattern = RegExp(_profileFilter, caseSensitive: false);
  return _profiles.where((profile) => pattern.hasMatch(profile.name));
}

Future<void> _waitForLocalModelFile(String path) async {
  final file = File(path);
  if (await _isReadyLocalModelFile(file)) return;

  _logBenchmark({
    'event': 'waiting_for_model_file',
    'path': path,
    if (_expectedModelBytes > 0) 'expectedBytes': _expectedModelBytes,
    'timeoutSeconds': 600,
  });

  final deadline = DateTime.now().add(const Duration(minutes: 10));
  while (DateTime.now().isBefore(deadline)) {
    if (await _isReadyLocalModelFile(file)) {
      _logBenchmark({'event': 'model_file_detected', 'path': path});
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  throw StateError('Local model file did not appear before timeout: $path');
}

Future<bool> _isReadyLocalModelFile(File file) async {
  if (!await file.exists()) return false;
  if (_expectedModelBytes <= 0) return true;
  return await file.length() == _expectedModelBytes;
}

const _profiles = <_BenchmarkProfile>[
  _BenchmarkProfile(
    name: 'app_baseline_auto_f16_ctx8192',
    modelParams: llama.ModelParams(contextSize: 8192),
  ),
  _BenchmarkProfile(
    name: 'mobile_auto_f16_ctx4096_b512_ub256',
    modelParams: llama.ModelParams(batchSize: 512, microBatchSize: 256),
  ),
  _BenchmarkProfile(
    name: 'mobile_auto_f16_ctx4096_b512_ub128',
    modelParams: llama.ModelParams(batchSize: 512, microBatchSize: 128),
  ),
  _BenchmarkProfile(
    name: 'mobile_auto_f16_ctx4096_b256_ub64',
    modelParams: llama.ModelParams(batchSize: 256, microBatchSize: 64),
  ),
  _BenchmarkProfile(
    name: 'mobile_auto_f16_ctx4096_b1024_ub256',
    modelParams: llama.ModelParams(batchSize: 1024, microBatchSize: 256),
  ),
  _BenchmarkProfile(
    name: 'mobile_auto_f16_ctx2048_b512_ub128',
    modelParams: llama.ModelParams(
      contextSize: 2048,
      batchSize: 512,
      microBatchSize: 128,
    ),
  ),
  _BenchmarkProfile(
    name: 'mobile_auto_q8_ctx2048_b512_ub128',
    modelParams: llama.ModelParams(
      contextSize: 2048,
      batchSize: 512,
      microBatchSize: 128,
      cacheTypeK: llama.KvCacheType.q8_0,
      cacheTypeV: llama.KvCacheType.q8_0,
    ),
  ),
  _BenchmarkProfile(
    name: 'mobile_vulkan_f16_ctx2048_ngl16_b512_ub128',
    modelParams: llama.ModelParams(
      contextSize: 2048,
      preferredBackend: llama.GpuBackend.vulkan,
      gpuLayers: 16,
      batchSize: 512,
      microBatchSize: 128,
    ),
  ),
  _BenchmarkProfile(
    name: 'mobile_vulkan_f16_ctx2048_ngl999_b512_ub128',
    modelParams: llama.ModelParams(
      contextSize: 2048,
      preferredBackend: llama.GpuBackend.vulkan,
      batchSize: 512,
      microBatchSize: 128,
    ),
  ),
  _BenchmarkProfile(
    name: 'mobile_cpu_f16_ctx2048_threads4',
    modelParams: llama.ModelParams(
      contextSize: 2048,
      preferredBackend: llama.GpuBackend.cpu,
      numberOfThreads: 4,
      numberOfThreadsBatch: 4,
      batchSize: 512,
      microBatchSize: 128,
    ),
  ),
  _BenchmarkProfile(
    name: 'mobile_cpu_f16_ctx2048_threads6',
    modelParams: llama.ModelParams(
      contextSize: 2048,
      preferredBackend: llama.GpuBackend.cpu,
      numberOfThreads: 6,
      numberOfThreadsBatch: 6,
      batchSize: 512,
      microBatchSize: 128,
    ),
  ),
];

Future<_BenchmarkResult> _runProfile(
  _BenchmarkProfile profile,
  String modelPath,
) async {
  final engine = llama.LlamaEngine(llama.LlamaBackend());
  final loadStopwatch = Stopwatch()..start();
  try {
    await engine.loadModel(modelPath, modelParams: profile.modelParams);
    loadStopwatch.stop();

    final backendName = await engine.getBackendName();
    final resolvedGpuLayers = await engine.getResolvedGpuLayers();
    final totalStopwatch = Stopwatch()..start();
    int? timeToFirstChunkMs;
    var chunkCount = 0;
    final output = StringBuffer();

    await for (final chunk in engine.create(
      const <llama.LlamaChatMessage>[
        llama.LlamaChatMessage.fromText(
          role: llama.LlamaChatRole.system,
          text:
              'You are a concise assistant. Answer with plain text only. '
              'Do not use markdown.',
        ),
        llama.LlamaChatMessage.fromText(
          role: llama.LlamaChatRole.user,
          text:
              'List practical ideas for spending a rainy afternoon in Montreal. '
              'Write exactly 8 short numbered items.',
        ),
      ],
      params: const llama.GenerationParams(
        maxTokens: 128,
        temp: 0.2,
        seed: 42,
        streamBatchTokenThreshold: 1,
        streamBatchByteThreshold: 128,
      ),
      enableThinking: false,
    )) {
      timeToFirstChunkMs ??= totalStopwatch.elapsedMilliseconds;
      chunkCount += 1;
      final text = chunk.choices.first.delta.content;
      if (text != null) output.write(text);
    }

    totalStopwatch.stop();
    final perf = await engine.getPerformanceContext();
    return _BenchmarkResult(
      profile: profile,
      backendName: backendName,
      resolvedGpuLayers: resolvedGpuLayers,
      loadMs: loadStopwatch.elapsedMilliseconds,
      totalMs: totalStopwatch.elapsedMilliseconds,
      timeToFirstChunkMs: timeToFirstChunkMs,
      chunkCount: chunkCount,
      outputCharacters: output.length,
      perf: perf,
    );
  } catch (error, stackTrace) {
    loadStopwatch.stop();
    return _BenchmarkResult(
      profile: profile,
      loadMs: loadStopwatch.elapsedMilliseconds,
      error: error.toString(),
      stackTrace: stackTrace.toString(),
    );
  } finally {
    await engine.dispose();
  }
}

void _logBenchmark(Map<String, Object?> payload) {
  debugPrint('GENUI_BENCHMARK ${jsonEncode(payload)}', wrapWidth: 1024);
}

final class _BenchmarkProfile {
  const _BenchmarkProfile({required this.name, required this.modelParams});

  final String name;
  final llama.ModelParams modelParams;

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'contextSize': modelParams.contextSize,
      'preferredBackend': modelParams.preferredBackend.name,
      'gpuLayers': modelParams.gpuLayers,
      'threads': modelParams.numberOfThreads,
      'threadsBatch': modelParams.numberOfThreadsBatch,
      'batchSize': modelParams.batchSize,
      'microBatchSize': modelParams.microBatchSize,
      'flashAttention': modelParams.flashAttention.name,
      'cacheTypeK': modelParams.cacheTypeK.name,
      'cacheTypeV': modelParams.cacheTypeV.name,
    };
  }
}

final class _BenchmarkResult {
  const _BenchmarkResult({
    required this.profile,
    required this.loadMs,
    this.backendName,
    this.resolvedGpuLayers,
    this.totalMs,
    this.timeToFirstChunkMs,
    this.chunkCount,
    this.outputCharacters,
    this.perf,
    this.error,
    this.stackTrace,
  });

  final _BenchmarkProfile profile;
  final String? backendName;
  final int? resolvedGpuLayers;
  final int loadMs;
  final int? totalMs;
  final int? timeToFirstChunkMs;
  final int? chunkCount;
  final int? outputCharacters;
  final llama.BackendPerfContextData? perf;
  final String? error;
  final String? stackTrace;

  double get decodeTokensPerSecond {
    final currentPerf = perf;
    if (currentPerf == null || currentPerf.evalMs <= 0) return 0;
    return currentPerf.evalTokens * 1000 / currentPerf.evalMs;
  }

  double get promptTokensPerSecond {
    final currentPerf = perf;
    if (currentPerf == null || currentPerf.promptEvalMs <= 0) return 0;
    return currentPerf.promptEvalTokens * 1000 / currentPerf.promptEvalMs;
  }

  Map<String, Object?> toJson() {
    return {
      'profile': profile.toJson(),
      if (backendName != null) 'backendName': backendName,
      if (resolvedGpuLayers != null) 'resolvedGpuLayers': resolvedGpuLayers,
      'loadMs': loadMs,
      if (totalMs != null) 'totalMs': totalMs,
      if (timeToFirstChunkMs != null) 'timeToFirstChunkMs': timeToFirstChunkMs,
      if (chunkCount != null) 'chunkCount': chunkCount,
      if (outputCharacters != null) 'outputCharacters': outputCharacters,
      if (perf != null) ...{
        'promptEvalMs': perf!.promptEvalMs,
        'evalMs': perf!.evalMs,
        'sampleMs': perf!.sampleMs,
        'promptEvalTokens': perf!.promptEvalTokens,
        'evalTokens': perf!.evalTokens,
        'sampleCount': perf!.sampleCount,
        'reusedGraphs': perf!.reusedGraphs,
        'promptTokensPerSecond': promptTokensPerSecond,
        'decodeTokensPerSecond': decodeTokensPerSecond,
      },
      if (error != null) 'error': error,
      if (stackTrace != null) 'stackTrace': stackTrace,
    };
  }
}
