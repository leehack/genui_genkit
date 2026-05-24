import 'package:flutter/foundation.dart';
import 'package:flutter_hybrid_genui/src/runtime/performance_tracking_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_genkit/genui_genkit.dart';

void main() {
  test('tracks route, output size, and estimated throughput', () async {
    final metrics = ValueNotifier<TurnPerformanceSnapshot>(
      const TurnPerformanceSnapshot.idle(),
    );
    addTearDown(metrics.dispose);
    final backend = PerformanceTrackingBackend(
      delegate: LocalGenkitBackend(generate: (_) => _delayedChunks()),
      metrics: metrics,
      routeForRequest: (_) => 'local',
      profileForRoute: (_) =>
          const TurnPerformanceProfile(backendName: 'vulkan', gpuLayers: 999),
    );
    addTearDown(backend.dispose);

    final events = await backend
        .send(GenUiTurnRequest(message: ChatMessage.user('Measure this turn')))
        .toList();

    expect(events.whereType<GenUiTextChunk>().length, 2);
    expect(metrics.value.phase, TurnPerformancePhase.completed);
    expect(metrics.value.routeName, 'local');
    expect(metrics.value.profile?.backendName, 'vulkan');
    expect(metrics.value.outputCharacters, 8);
    expect(metrics.value.estimatedOutputTokens, 2);
    expect(metrics.value.effectiveTokensPerSecond, isNotNull);
  });

  test('marks failed turns', () async {
    final metrics = ValueNotifier<TurnPerformanceSnapshot>(
      const TurnPerformanceSnapshot.idle(),
    );
    addTearDown(metrics.dispose);
    final backend = PerformanceTrackingBackend(
      delegate: LocalGenkitBackend(
        generate: (_) => throw StateError('backend failed'),
      ),
      metrics: metrics,
      routeForRequest: (_) => 'local',
    );
    addTearDown(backend.dispose);

    final events = await backend
        .send(GenUiTurnRequest(message: ChatMessage.user('Measure this turn')))
        .toList();

    expect(events.whereType<GenUiBackendError>(), isNotEmpty);
    expect(metrics.value.phase, TurnPerformancePhase.failed);
    expect(metrics.value.errorMessage, contains('backend failed'));
  });
}

Stream<String> _delayedChunks() async* {
  await Future<void>.delayed(const Duration(milliseconds: 1));
  yield 'abcd';
  await Future<void>.delayed(const Duration(milliseconds: 1));
  yield 'efgh';
}
