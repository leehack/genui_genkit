import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_hybrid_genui/src/activity_catalog.dart';
import 'package:flutter_hybrid_genui/src/model_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_genkit/genui_genkit.dart';
import 'package:genui_genkit/src/a2ui_stream_repairer.dart';
import 'package:llamadart/llamadart.dart' as llama;

const _runBenchmark = bool.fromEnvironment('GENUI_RUN_LOCAL_QUALITY_BENCHMARK');
const _modelSpecsText = String.fromEnvironment(
  'GENUI_QUALITY_BENCHMARK_MODELS',
  defaultValue:
      'gemma4|hf://unsloth/gemma-4-E2B-it-GGUF/gemma-4-E2B-it-Q4_K_S.gguf;'
      'lfm2.5-1.2b-q4_0|hf://LiquidAI/LFM2.5-1.2B-Instruct-GGUF/LFM2.5-1.2B-Instruct-Q4_0.gguf;'
      'qwen3-0.6b-q8_0|hf://Qwen/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf;'
      'qwen3-1.7b-q4_k_m|hf://bartowski/Qwen_Qwen3-1.7B-GGUF/Qwen_Qwen3-1.7B-Q4_K_M.gguf',
);
const _outputPath = String.fromEnvironment(
  'GENUI_QUALITY_BENCHMARK_OUTPUT',
  defaultValue: '/private/tmp/genui_quality_benchmark.jsonl',
);
const _rawOutputDirectoryPath = String.fromEnvironment(
  'GENUI_QUALITY_BENCHMARK_RAW_OUTPUT_DIR',
  defaultValue: '/private/tmp/genui_quality_benchmark_raw',
);
const _maxTokens = int.fromEnvironment(
  'GENUI_QUALITY_BENCHMARK_MAX_TOKENS',
  defaultValue: 512,
);

void main() {
  test(
    'benchmarks local GenUI quality and throughput',
    skip: !_runBenchmark,
    timeout: const Timeout(Duration(minutes: 90)),
    () async {
      final outputFile = File(_outputPath);
      await outputFile.parent.create(recursive: true);
      if (await outputFile.exists()) await outputFile.delete();
      final rawOutputDirectory = Directory(_rawOutputDirectoryPath);
      if (await rawOutputDirectory.exists()) {
        await rawOutputDirectory.delete(recursive: true);
      }
      await rawOutputDirectory.create(recursive: true);

      final cacheDirectory = ModelConfig.fromEnvironment(
        Platform.environment,
      ).cacheDirectory;
      final prompt = compactGenUiSystemPromptBuilder([
        activityCatalog,
      ], const GenUiSystemPromptOptions());
      final models = _parseModelSpecs(_modelSpecsText);

      for (final model in models) {
        final result = await _runModel(
          model,
          cacheDirectory: cacheDirectory,
          rawOutputDirectory: rawOutputDirectory,
          systemPrompt: prompt,
        );
        final json = jsonEncode(result.toJson());
        debugPrint('GENUI_QUALITY $json', wrapWidth: 1024);
        await outputFile.writeAsString('$json\n', mode: FileMode.append);
      }

      debugPrint(
        'GENUI_QUALITY ${jsonEncode({'event': 'output_file', 'path': outputFile.path})}',
        wrapWidth: 1024,
      );
    },
  );
}

Future<_ModelBenchmarkResult> _runModel(
  _ModelSpec model, {
  required String? cacheDirectory,
  required Directory rawOutputDirectory,
  required String systemPrompt,
}) async {
  final source = llama.ModelSource.parse(model.source);
  final controller = llama.ModelDownloadController(
    manager: llama.DefaultModelDownloadManager(
      defaultCacheDirectory: cacheDirectory,
    ),
  );
  StreamSubscription<llama.ModelDownloadTaskSnapshot>? snapshotSub;
  llama.ModelDownloadTaskStage? lastStage;
  int? lastProgressBucket;
  try {
    snapshotSub = controller.snapshots.listen((snapshot) {
      final progress = snapshot.fraction;
      final progressBucket = progress == null ? null : (progress * 20).floor();
      final isTerminal = switch (snapshot.stage) {
        llama.ModelDownloadTaskStage.ready ||
        llama.ModelDownloadTaskStage.failed ||
        llama.ModelDownloadTaskStage.cancelled => true,
        _ => false,
      };
      if (snapshot.stage == lastStage &&
          progressBucket == lastProgressBucket &&
          !isTerminal) {
        return;
      }
      lastStage = snapshot.stage;
      lastProgressBucket = progressBucket;

      final payload = {
        'event': 'download',
        'model': model.name,
        'stage': snapshot.stage.name,
        'progress': ?progress,
      };
      debugPrint('GENUI_QUALITY ${jsonEncode(payload)}', wrapWidth: 1024);
    });
    final entry = await controller.start(source);
    return _runInference(
      model,
      entry.filePath,
      systemPrompt,
      rawOutputDirectory: rawOutputDirectory,
    );
  } finally {
    await snapshotSub?.cancel();
    await controller.dispose();
  }
}

Future<_ModelBenchmarkResult> _runInference(
  _ModelSpec model,
  String modelPath,
  String systemPrompt, {
  required Directory rawOutputDirectory,
}) async {
  final engine = llama.LlamaEngine(llama.LlamaBackend());
  final loadStopwatch = Stopwatch()..start();
  try {
    const modelParams = llama.ModelParams(batchSize: 512, microBatchSize: 256);
    await engine.loadModel(modelPath, modelParams: modelParams);
    loadStopwatch.stop();

    final backendName = await engine.getBackendName();
    final resolvedGpuLayers = await engine.getResolvedGpuLayers();
    final stopwatch = Stopwatch()..start();
    int? timeToFirstChunkMs;
    var chunkCount = 0;
    final output = StringBuffer();

    await for (final chunk in engine.create(
      [
        llama.LlamaChatMessage.fromText(
          role: llama.LlamaChatRole.system,
          text: systemPrompt,
        ),
        const llama.LlamaChatMessage.fromText(
          role: llama.LlamaChatRole.user,
          text:
              'Create a rainy afternoon Montreal itinerary under \$50. '
              'Render an ItineraryPlan, one ActivityCard, and a short Checklist.',
        ),
      ],
      params: const llama.GenerationParams(
        maxTokens: _maxTokens,
        temp: 0.2,
        seed: 42,
        streamBatchTokenThreshold: 1,
        streamBatchByteThreshold: 128,
      ),
      enableThinking: false,
    )) {
      timeToFirstChunkMs ??= stopwatch.elapsedMilliseconds;
      chunkCount += 1;
      final text = chunk.choices.first.delta.content;
      if (text != null) output.write(text);
    }

    stopwatch.stop();
    final rawOutput = output.toString();
    final rawOutputFile = File(
      '${rawOutputDirectory.path}/${_safeFileName(model.name)}.txt',
    );
    await rawOutputFile.writeAsString(rawOutput);
    final strictAnalysis = await _analyzeOutput(rawOutput, repair: false);
    final repairedAnalysis = await _analyzeOutput(rawOutput, repair: true);
    final perf = await engine.getPerformanceContext();

    return _ModelBenchmarkResult(
      model: model,
      modelPath: modelPath,
      backendName: backendName,
      resolvedGpuLayers: resolvedGpuLayers,
      loadMs: loadStopwatch.elapsedMilliseconds,
      totalMs: stopwatch.elapsedMilliseconds,
      timeToFirstChunkMs: timeToFirstChunkMs,
      chunkCount: chunkCount,
      outputCharacters: rawOutput.length,
      perf: perf,
      strictAnalysis: strictAnalysis,
      repairedAnalysis: repairedAnalysis,
      rawPreview: _preview(rawOutput),
      rawOutputPath: rawOutputFile.path,
    );
  } catch (error, stackTrace) {
    loadStopwatch.stop();
    return _ModelBenchmarkResult(
      model: model,
      modelPath: modelPath,
      loadMs: loadStopwatch.elapsedMilliseconds,
      error: error.toString(),
      stackTrace: stackTrace.toString(),
    );
  } finally {
    await engine.dispose();
  }
}

Future<_QualityAnalysis> _analyzeOutput(
  String output, {
  required bool repair,
}) async {
  final messages = <A2uiMessage>[];
  final textBuffer = StringBuffer();
  final errors = <String>[];
  Stream<String> stream = Stream.value(output);
  if (repair) {
    stream = stream.transform(const A2uiStreamRepairer());
  }

  try {
    await for (final event in stream.transform(const A2uiParserTransformer())) {
      switch (event) {
        case TextEvent(:final text):
          textBuffer.write(text);
        case A2uiMessageEvent(:final message):
          messages.add(message);
      }
    }
  } catch (error) {
    errors.add(error.toString());
  }

  final creates = messages.whereType<CreateSurface>().toList();
  final updates = messages.whereType<UpdateComponents>().toList();
  final components = updates.expand((message) => message.components).toList();
  final componentTypes = components.map((component) => component.type).toSet();
  final root = components
      .where((component) => component.id == 'root')
      .firstOrNull;
  final componentsById = {
    for (final component in components) component.id: component,
  };
  final visibleComponentTypes = _visibleComponentTypes(componentsById, root);
  final surfaceIds = {
    ...creates.map((message) => message.surfaceId),
    ...updates.map((message) => message.surfaceId),
  };

  return _QualityAnalysis(
    repaired: repair,
    textCharacters: textBuffer.length,
    errors: errors,
    createSurfaceCount: creates.length,
    updateComponentsCount: updates.length,
    surfaceIds: surfaceIds.toList()..sort(),
    componentTypes: componentTypes.toList()..sort(),
    visibleComponentTypes: visibleComponentTypes.toList()..sort(),
    hasCorrectCatalog: creates.any(
      (message) => message.catalogId == activityCatalog.catalogId,
    ),
    hasRoot: root != null,
    rootType: root?.type,
    score: _qualityScore(
      errors: errors,
      creates: creates,
      updates: updates,
      visibleComponentTypes: visibleComponentTypes,
      hasRoot: root != null,
      output: output,
    ),
  );
}

int _qualityScore({
  required List<String> errors,
  required List<CreateSurface> creates,
  required List<UpdateComponents> updates,
  required Set<String> visibleComponentTypes,
  required bool hasRoot,
  required String output,
}) {
  var score = 0;
  if (errors.isEmpty && (creates.isNotEmpty || updates.isNotEmpty)) score += 25;
  if (creates.any(
    (message) => message.catalogId == activityCatalog.catalogId,
  )) {
    score += 15;
  }
  if (_hasMatchingSurface(creates, updates)) score += 15;
  if (hasRoot) score += 15;
  if (visibleComponentTypes.contains('ItineraryPlan')) score += 9;
  if (visibleComponentTypes.contains('ActivityCard')) score += 8;
  if (visibleComponentTypes.contains('Checklist')) score += 8;

  final normalized = output.toLowerCase();
  if (normalized.contains('montreal') || normalized.contains('montréal')) {
    score += 2;
  }
  if (normalized.contains('rain')) score += 1;
  if (normalized.contains(r'$50') ||
      normalized.contains('under 50') ||
      normalized.contains('under \$50')) {
    score += 2;
  }
  return score.clamp(0, 100);
}

Set<String> _visibleComponentTypes(
  Map<String, Component> componentsById,
  Component? root,
) {
  if (root == null) return const {};

  final visible = <String>{};
  final visited = <String>{};

  void visit(Component component) {
    if (!visited.add(component.id)) return;
    visible.add(component.type);

    final children = component.properties['children'];
    if (children is List) {
      for (final childId in children.whereType<String>()) {
        final child = componentsById[childId];
        if (child != null) visit(child);
      }
    }
  }

  visit(root);
  return visible;
}

bool _hasMatchingSurface(
  List<CreateSurface> creates,
  List<UpdateComponents> updates,
) {
  final created = creates.map((message) => message.surfaceId).toSet();
  return updates.any((message) => created.contains(message.surfaceId));
}

List<_ModelSpec> _parseModelSpecs(String specs) {
  return specs
      .split(';')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .map((entry) {
        final parts = entry.split('|');
        if (parts.length != 2) {
          throw FormatException(
            'Model specs must use "name|source" entries: $entry',
          );
        }
        return _ModelSpec(name: parts[0], source: parts[1]);
      })
      .toList(growable: false);
}

String _preview(String value) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= 420) return normalized;
  return '${normalized.substring(0, 420)}...';
}

final class _ModelSpec {
  const _ModelSpec({required this.name, required this.source});

  final String name;
  final String source;

  Map<String, Object?> toJson() => {'name': name, 'source': source};
}

final class _QualityAnalysis {
  const _QualityAnalysis({
    required this.repaired,
    required this.textCharacters,
    required this.errors,
    required this.createSurfaceCount,
    required this.updateComponentsCount,
    required this.surfaceIds,
    required this.componentTypes,
    required this.visibleComponentTypes,
    required this.hasCorrectCatalog,
    required this.hasRoot,
    required this.rootType,
    required this.score,
  });

  final bool repaired;
  final int textCharacters;
  final List<String> errors;
  final int createSurfaceCount;
  final int updateComponentsCount;
  final List<String> surfaceIds;
  final List<String> componentTypes;
  final List<String> visibleComponentTypes;
  final bool hasCorrectCatalog;
  final bool hasRoot;
  final String? rootType;
  final int score;

  Map<String, Object?> toJson() => {
    'repaired': repaired,
    'score': score,
    'textCharacters': textCharacters,
    'errors': errors,
    'createSurfaceCount': createSurfaceCount,
    'updateComponentsCount': updateComponentsCount,
    'surfaceIds': surfaceIds,
    'componentTypes': componentTypes,
    'visibleComponentTypes': visibleComponentTypes,
    'hasCorrectCatalog': hasCorrectCatalog,
    'hasRoot': hasRoot,
    if (rootType != null) 'rootType': rootType,
  };
}

final class _ModelBenchmarkResult {
  const _ModelBenchmarkResult({
    required this.model,
    required this.modelPath,
    required this.loadMs,
    this.backendName,
    this.resolvedGpuLayers,
    this.totalMs,
    this.timeToFirstChunkMs,
    this.chunkCount,
    this.outputCharacters,
    this.perf,
    this.strictAnalysis,
    this.repairedAnalysis,
    this.rawPreview,
    this.rawOutputPath,
    this.error,
    this.stackTrace,
  });

  final _ModelSpec model;
  final String modelPath;
  final String? backendName;
  final int? resolvedGpuLayers;
  final int loadMs;
  final int? totalMs;
  final int? timeToFirstChunkMs;
  final int? chunkCount;
  final int? outputCharacters;
  final llama.BackendPerfContextData? perf;
  final _QualityAnalysis? strictAnalysis;
  final _QualityAnalysis? repairedAnalysis;
  final String? rawPreview;
  final String? rawOutputPath;
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

  Map<String, Object?> toJson() => {
    'event': 'model_result',
    'model': model.toJson(),
    'modelPath': modelPath,
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
      'promptTokensPerSecond': promptTokensPerSecond,
      'decodeTokensPerSecond': decodeTokensPerSecond,
    },
    if (strictAnalysis != null) 'strictQuality': strictAnalysis!.toJson(),
    if (repairedAnalysis != null) 'repairedQuality': repairedAnalysis!.toJson(),
    if (rawPreview != null) 'rawPreview': rawPreview,
    if (rawOutputPath != null) 'rawOutputPath': rawOutputPath,
    if (error != null) 'error': error,
    if (stackTrace != null) 'stackTrace': stackTrace,
  };
}

String _safeFileName(String value) {
  final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_');
  return cleaned.isEmpty ? 'model' : cleaned;
}
