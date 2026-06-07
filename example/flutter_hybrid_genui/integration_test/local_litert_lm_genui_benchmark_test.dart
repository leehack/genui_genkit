import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_hybrid_genui/src/activity_catalog.dart';
import 'package:flutter_hybrid_genui/src/activity_prompt.dart';
import 'package:flutter_hybrid_genui/src/llama_backend.dart';
import 'package:flutter_hybrid_genui/src/model_config.dart';
import 'package:flutter_hybrid_genui/src/runtime/app_runtime.dart';
import 'package:flutter_hybrid_genui/src/runtime/cache_environment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_genkit/genui_genkit.dart';
import 'package:integration_test/integration_test.dart';

const _runBenchmark = bool.fromEnvironment(
  'GENUI_RUN_LOCAL_LITERT_GENUI_BENCHMARK',
);

const _prompt = String.fromEnvironment(
  'GENUI_LOCAL_BENCHMARK_PROMPT',
  defaultValue:
      'Create a rainy afternoon Montreal itinerary under \$50. '
      'Render an ItineraryPlan, one ActivityCard, and a short Checklist.',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'benchmarks Gemma 4 LiteRT-LM GenUI output on device',
    (tester) async {
      final environment = await resolveEnvironmentForFlutterApp(
        environmentWithDartDefines(Platform.environment),
      );
      final config = ModelConfig.fromEnvironment(environment);
      expect(config.isLiteRtLmModel, isTrue);

      final configNotifier = ValueNotifier(config);
      final status = ValueNotifier(ModelRuntimeStatus.idle(config));
      final backend = LlamaLocalGenkitBackend(
        configNotifier,
        modelStatus: status,
      );
      final session = GenkitGenUiSession(
        backend: backend,
        catalog: activityCatalog,
        systemPromptBuilder: activityGenUiSystemPromptBuilder,
        metadata: const {'route': 'local', 'benchmark': 'litert-genui'},
      );
      final rawOutput = StringBuffer();
      final errors = <Object>[];
      StreamSubscription<String>? rawSub;
      StreamSubscription<Object>? errorSub;

      addTearDown(() async {
        await rawSub?.cancel();
        await errorSub?.cancel();
        session.dispose();
        configNotifier.dispose();
        status.dispose();
      });

      rawSub = session.rawText.listen(rawOutput.write);
      errorSub = session.errors.listen(errors.add);

      final warmUpPrompt = activityGenUiSystemPromptBuilder([
        activityCatalog,
      ], const GenUiSystemPromptOptions());
      final loadStopwatch = Stopwatch()..start();
      await backend
          .prepare(warmUpSystemPrompt: warmUpPrompt)
          .timeout(const Duration(minutes: 30));
      loadStopwatch.stop();

      expect(status.value.phase, ModelRuntimePhase.ready);
      expect(status.value.resolvedModelPath, endsWith('.litertlm'));

      int? timeToFirstChunkMs;
      await rawSub.cancel();
      final turnStopwatch = Stopwatch()..start();
      rawSub = session.rawText.listen((chunk) {
        timeToFirstChunkMs ??= turnStopwatch.elapsedMilliseconds;
        rawOutput.write(chunk);
      });

      await session.sendText(_prompt).timeout(const Duration(minutes: 10));
      turnStopwatch.stop();

      final surfaceIds = session.surfaceController.activeSurfaceIds.toList();
      final visibleTypes = <String>{};
      var hasRoot = false;
      for (final surfaceId in surfaceIds) {
        final definition = session.surfaceController.registry.getSurface(
          surfaceId,
        );
        if (definition == null) continue;
        hasRoot = hasRoot || definition.components.containsKey('root');
        visibleTypes.addAll(
          definition.components.values.map((component) => component.type),
        );
      }

      final result = {
        'event': 'litert_genui_benchmark',
        'model': config.modelSourceDisplayName,
        'source': config.modelSource.metadataSourceKey,
        'litertBackend': config.inferenceOptions.liteRtLmBackend.name,
        'loadMs': loadStopwatch.elapsedMilliseconds,
        'turnMs': turnStopwatch.elapsedMilliseconds,
        'timeToFirstChunkMs': timeToFirstChunkMs,
        'rawCharacters': rawOutput.length,
        'surfaceCount': surfaceIds.length,
        'surfaceIds': surfaceIds,
        'hasRoot': hasRoot,
        'componentTypes': visibleTypes.toList()..sort(),
        'messageCount': session.messages.length,
        'errorCount': errors.length,
        'errors': errors.map((error) => error.toString()).toList(),
        'rawPreview': _preview(rawOutput.toString()),
        'score': _score(
          rawOutput.toString(),
          surfaceCount: surfaceIds.length,
          hasRoot: hasRoot,
          componentTypes: visibleTypes,
          errors: errors,
        ),
      };
      debugPrint('GENUI_LITERT_BENCHMARK ${jsonEncode(result)}');

      expect(rawOutput.toString().trim(), isNotEmpty);
      expect(errors, isEmpty);
    },
    skip: !_runBenchmark,
    timeout: const Timeout(Duration(minutes: 45)),
  );
}

int _score(
  String output, {
  required int surfaceCount,
  required bool hasRoot,
  required Set<String> componentTypes,
  required List<Object> errors,
}) {
  var score = 0;
  if (errors.isEmpty) score += 20;
  if (output.trim().isNotEmpty) score += 15;
  if (surfaceCount > 0) score += 20;
  if (hasRoot) score += 15;
  if (componentTypes.contains('ItineraryPlan')) score += 10;
  if (componentTypes.contains('ActivityCard')) score += 8;
  if (componentTypes.contains('Checklist')) score += 8;
  final normalized = output.toLowerCase();
  if (normalized.contains('montreal') || normalized.contains('montréal')) {
    score += 2;
  }
  if (normalized.contains('rain')) score += 1;
  if (normalized.contains(r'$50') || normalized.contains('under 50')) {
    score += 1;
  }
  return score.clamp(0, 100);
}

String _preview(String value) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= 500) return normalized;
  return '${normalized.substring(0, 500)}...';
}
