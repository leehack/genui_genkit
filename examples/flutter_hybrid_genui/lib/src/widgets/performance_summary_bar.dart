import 'package:flutter/material.dart';

import '../model_config.dart';
import '../runtime/app_runtime.dart';
import '../runtime/performance_tracking_backend.dart';

class PerformanceSummaryBar extends StatelessWidget {
  const PerformanceSummaryBar({
    super.key,
    required this.runtime,
    this.compact = false,
  });

  final AppRuntime runtime;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TurnPerformanceSnapshot>(
      valueListenable: runtime.turnPerformance,
      builder: (context, snapshot, _) {
        if (snapshot.phase == TurnPerformancePhase.idle) {
          return const SizedBox.shrink();
        }

        final colorScheme = Theme.of(context).colorScheme;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 7 : 8,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final chip in _chips(snapshot)) ...[
                    chip,
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _chips(TurnPerformanceSnapshot snapshot) {
    return [
      _MetricChip(
        icon: _phaseIcon(snapshot.phase),
        label: _routeLabel(snapshot.routeName),
        value: _phaseLabel(snapshot.phase),
        emphasized: snapshot.phase == TurnPerformancePhase.running,
        isError: snapshot.phase == TurnPerformancePhase.failed,
      ),
      if (snapshot.profile case final profile?) ..._profileChips(profile),
      _MetricChip(
        icon: Icons.timer_outlined,
        label: 'TTFT',
        value: _durationLabel(snapshot.timeToFirstChunk),
      ),
      _MetricChip(
        icon: Icons.schedule,
        label: snapshot.isActive ? 'Elapsed' : 'Total',
        value: _durationLabel(snapshot.elapsed),
      ),
      _MetricChip(
        icon: Icons.speed,
        label: 'Decode',
        value: _rateLabel(snapshot.decodeTokensPerSecond),
      ),
      _MetricChip(
        icon: Icons.functions,
        label: 'Effective',
        value: _rateLabel(snapshot.effectiveTokensPerSecond),
      ),
      _MetricChip(
        icon: Icons.data_object,
        label: 'Output',
        value:
            '${snapshot.estimatedOutputTokens} est tok / '
            '${snapshot.outputCharacters} chars',
      ),
    ];
  }

  List<Widget> _profileChips(TurnPerformanceProfile profile) {
    return [
      if (profile.backendName != null)
        _MetricChip(
          icon: Icons.memory,
          label: 'Backend',
          value:
              '${profile.backendName}'
              '${profile.gpuLayers == null ? '' : ' / ${_gpuLayerLabel(profile.gpuLayers!)}'}',
        ),
      if (profile.contextSize != null)
        _MetricChip(
          icon: Icons.dashboard_customize_outlined,
          label: 'Context',
          value:
              '${profile.contextSize}'
              '${profile.maxTokens == null ? '' : ' / ${profile.maxTokens} max'}',
        ),
      if (profile.batchSize != null || profile.microBatchSize != null)
        _MetricChip(
          icon: Icons.view_week_outlined,
          label: 'Batch',
          value:
              '${profile.batchSize ?? '-'}'
              ' / ${profile.microBatchSize ?? '-'}',
        ),
    ];
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
    this.isError = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isError
        ? colorScheme.onErrorContainer
        : emphasized
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    return Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: isError
            ? colorScheme.errorContainer
            : emphasized
            ? colorScheme.primaryContainer
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError
              ? colorScheme.error
              : emphasized
              ? colorScheme.primary.withValues(alpha: 0.28)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$label '),
                  TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

String _routeLabel(String? routeName) {
  return switch (routeName) {
    'local' => GenUiAiRoute.local.label,
    'gemini' => GenUiAiRoute.gemini.label,
    'backend' => GenUiAiRoute.backend.label,
    final value? when value.isNotEmpty => value,
    _ => 'Turn',
  };
}

IconData _phaseIcon(TurnPerformancePhase phase) {
  return switch (phase) {
    TurnPerformancePhase.idle => Icons.timeline,
    TurnPerformancePhase.running => Icons.sync,
    TurnPerformancePhase.completed => Icons.check,
    TurnPerformancePhase.failed => Icons.error_outline,
    TurnPerformancePhase.cancelled => Icons.cancel_outlined,
  };
}

String _phaseLabel(TurnPerformancePhase phase) {
  return switch (phase) {
    TurnPerformancePhase.idle => 'idle',
    TurnPerformancePhase.running => 'running',
    TurnPerformancePhase.completed => 'done',
    TurnPerformancePhase.failed => 'failed',
    TurnPerformancePhase.cancelled => 'cancelled',
  };
}

String _durationLabel(Duration? duration) {
  if (duration == null) return 'pending';
  if (duration.inMilliseconds < 1000) return '${duration.inMilliseconds} ms';
  return '${(duration.inMilliseconds / 1000).toStringAsFixed(1)} s';
}

String _rateLabel(double? tokensPerSecond) {
  if (tokensPerSecond == null || !tokensPerSecond.isFinite) return 'pending';
  return '${tokensPerSecond.toStringAsFixed(1)} est tok/s';
}

String _gpuLayerLabel(int gpuLayers) {
  if (gpuLayers >= 999) return 'all layers';
  if (gpuLayers <= 0) return 'CPU layers';
  return '$gpuLayers layers';
}
