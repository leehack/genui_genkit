import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:genui_genkit/genui_genkit.dart';

typedef TurnRouteResolver = String Function(GenUiTurnRequest request);
typedef TurnProfileResolver =
    TurnPerformanceProfile? Function(String routeName);

final class TurnPerformanceProfile {
  const TurnPerformanceProfile({
    this.backendName,
    this.gpuLayers,
    this.contextSize,
    this.batchSize,
    this.microBatchSize,
    this.maxTokens,
  });

  final String? backendName;
  final int? gpuLayers;
  final int? contextSize;
  final int? batchSize;
  final int? microBatchSize;
  final int? maxTokens;
}

enum TurnPerformancePhase { idle, running, completed, failed, cancelled }

final class TurnPerformanceSnapshot {
  const TurnPerformanceSnapshot({
    required this.phase,
    this.routeName,
    this.profile,
    this.elapsed = Duration.zero,
    this.timeToFirstChunk,
    this.outputCharacters = 0,
    this.chunkCount = 0,
    this.errorMessage,
    this.metadata = const {},
  });

  const TurnPerformanceSnapshot.idle() : this(phase: TurnPerformancePhase.idle);

  final TurnPerformancePhase phase;
  final String? routeName;
  final TurnPerformanceProfile? profile;
  final Duration elapsed;
  final Duration? timeToFirstChunk;
  final int outputCharacters;
  final int chunkCount;
  final String? errorMessage;
  final Map<String, Object?> metadata;

  int get estimatedOutputTokens {
    if (outputCharacters <= 0) return 0;
    final estimate = (outputCharacters / 4).ceil();
    return estimate < 1 ? 1 : estimate;
  }

  double? get effectiveTokensPerSecond {
    return _tokensPerSecond(elapsed);
  }

  double? get decodeTokensPerSecond {
    final firstChunk = timeToFirstChunk;
    if (firstChunk == null) return null;
    final decodeElapsed = elapsed - firstChunk;
    return _tokensPerSecond(decodeElapsed);
  }

  bool get isActive => phase == TurnPerformancePhase.running;

  TurnPerformanceSnapshot copyWith({
    TurnPerformancePhase? phase,
    String? routeName,
    TurnPerformanceProfile? profile,
    Duration? elapsed,
    Duration? timeToFirstChunk,
    int? outputCharacters,
    int? chunkCount,
    String? errorMessage,
    Map<String, Object?>? metadata,
  }) {
    return TurnPerformanceSnapshot(
      phase: phase ?? this.phase,
      routeName: routeName ?? this.routeName,
      profile: profile ?? this.profile,
      elapsed: elapsed ?? this.elapsed,
      timeToFirstChunk: timeToFirstChunk ?? this.timeToFirstChunk,
      outputCharacters: outputCharacters ?? this.outputCharacters,
      chunkCount: chunkCount ?? this.chunkCount,
      errorMessage: errorMessage ?? this.errorMessage,
      metadata: metadata ?? this.metadata,
    );
  }

  double? _tokensPerSecond(Duration duration) {
    if (estimatedOutputTokens <= 0) return null;
    final seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds <= 0) return null;
    return estimatedOutputTokens / seconds;
  }
}

final class PerformanceTrackingBackend implements GenUiBackend {
  PerformanceTrackingBackend({
    required GenUiBackend delegate,
    required ValueNotifier<TurnPerformanceSnapshot> metrics,
    required TurnRouteResolver routeForRequest,
    TurnProfileResolver? profileForRoute,
  }) : _delegate = delegate,
       _metrics = metrics,
       _routeForRequest = routeForRequest,
       _profileForRoute = profileForRoute;

  final GenUiBackend _delegate;
  final ValueNotifier<TurnPerformanceSnapshot> _metrics;
  final TurnRouteResolver _routeForRequest;
  final TurnProfileResolver? _profileForRoute;
  Stopwatch? _activeStopwatch;

  @override
  Stream<GenUiBackendEvent> send(GenUiTurnRequest request) async* {
    final routeName = _routeForRequest(request);
    final profile = _profileForRoute?.call(routeName);
    final stopwatch = Stopwatch()..start();
    _activeStopwatch = stopwatch;
    late final Timer elapsedTimer;
    Duration? timeToFirstChunk;
    var outputCharacters = 0;
    var chunkCount = 0;
    var failed = false;

    _metrics.value = TurnPerformanceSnapshot(
      phase: TurnPerformancePhase.running,
      routeName: routeName,
      profile: profile,
    );
    elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!identical(_activeStopwatch, stopwatch)) return;
      final current = _metrics.value;
      if (current.phase != TurnPerformancePhase.running) return;
      _metrics.value = current.copyWith(elapsed: stopwatch.elapsed);
    });

    try {
      await for (final event in _delegate.send(request)) {
        switch (event) {
          case GenUiTextChunk(:final text):
            if (text.isNotEmpty) {
              timeToFirstChunk ??= stopwatch.elapsed;
              outputCharacters += text.length;
              chunkCount += 1;
              _metrics.value = TurnPerformanceSnapshot(
                phase: TurnPerformancePhase.running,
                routeName: routeName,
                profile: profile,
                elapsed: stopwatch.elapsed,
                timeToFirstChunk: timeToFirstChunk,
                outputCharacters: outputCharacters,
                chunkCount: chunkCount,
              );
            }
          case GenUiBackendError(:final message):
            failed = true;
            _metrics.value = TurnPerformanceSnapshot(
              phase: TurnPerformancePhase.failed,
              routeName: routeName,
              profile: profile,
              elapsed: stopwatch.elapsed,
              timeToFirstChunk: timeToFirstChunk,
              outputCharacters: outputCharacters,
              chunkCount: chunkCount,
              errorMessage: message,
            );
          case GenUiTurnDone(:final metadata):
            if (!failed) {
              _metrics.value = TurnPerformanceSnapshot(
                phase: TurnPerformancePhase.completed,
                routeName: routeName,
                profile: profile,
                elapsed: stopwatch.elapsed,
                timeToFirstChunk: timeToFirstChunk,
                outputCharacters: outputCharacters,
                chunkCount: chunkCount,
                metadata: metadata,
              );
            }
        }
        yield event;
      }

      if (_metrics.value.phase == TurnPerformancePhase.running) {
        _metrics.value = TurnPerformanceSnapshot(
          phase: TurnPerformancePhase.completed,
          routeName: routeName,
          profile: profile,
          elapsed: stopwatch.elapsed,
          timeToFirstChunk: timeToFirstChunk,
          outputCharacters: outputCharacters,
          chunkCount: chunkCount,
        );
      }
    } catch (error) {
      _metrics.value = TurnPerformanceSnapshot(
        phase: TurnPerformancePhase.failed,
        routeName: routeName,
        profile: profile,
        elapsed: stopwatch.elapsed,
        timeToFirstChunk: timeToFirstChunk,
        outputCharacters: outputCharacters,
        chunkCount: chunkCount,
        errorMessage: error.toString(),
      );
      rethrow;
    } finally {
      elapsedTimer.cancel();
      if (identical(_activeStopwatch, stopwatch)) {
        _activeStopwatch = null;
      }
    }
  }

  @override
  Future<void> cancelActiveTurn() async {
    final active = _activeStopwatch;
    if (active != null &&
        _metrics.value.phase == TurnPerformancePhase.running) {
      _metrics.value = _metrics.value.copyWith(
        phase: TurnPerformancePhase.cancelled,
        elapsed: active.elapsed,
      );
    }
    await Future<void>.sync(_delegate.cancelActiveTurn);
  }

  @override
  Future<void> dispose() async {
    await Future<void>.sync(_delegate.dispose);
  }
}
