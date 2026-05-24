import 'dart:async';

import 'package:flutter/material.dart';

import '../model_config.dart';
import '../runtime/app_runtime.dart';
import 'route_settings_dialog.dart';

class RuntimeStatusCard extends StatelessWidget {
  const RuntimeStatusCard({
    super.key,
    required this.runtime,
    required this.isProcessing,
    this.compact = false,
  });

  final AppRuntime runtime;
  final bool isProcessing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        runtime.selectedRoute,
        runtime.geminiConfig,
        runtime.backendConfig,
      ]),
      builder: (context, _) {
        final selectedRoute = runtime.selectedRoute.value;
        final modelStatus = runtime.modelStatus;
        if (modelStatus != null) {
          return ValueListenableBuilder<ModelRuntimeStatus>(
            valueListenable: modelStatus,
            builder: (context, status, _) {
              return _StatusSurface(
                runtime: runtime,
                status: status,
                selectedRoute: selectedRoute,
                isProcessing: isProcessing,
                compact: compact,
              );
            },
          );
        }

        return _InjectedStatusSurface(
          runtime: runtime,
          selectedRoute: selectedRoute,
          isProcessing: isProcessing,
          compact: compact,
        );
      },
    );
  }
}

class _StatusSurface extends StatelessWidget {
  const _StatusSurface({
    required this.runtime,
    required this.status,
    required this.selectedRoute,
    required this.isProcessing,
    required this.compact,
  });

  final AppRuntime runtime;
  final ModelRuntimeStatus status;
  final GenUiAiRoute selectedRoute;
  final bool isProcessing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactStatusSurface(
        runtime: runtime,
        status: status,
        selectedRoute: selectedRoute,
        isProcessing: isProcessing,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = status.progress;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RouteHeader(
              runtime: runtime,
              selectedRoute: selectedRoute,
              isProcessing: isProcessing,
            ),
            if (selectedRoute == GenUiAiRoute.local) ...[
              Divider(height: 22, color: colorScheme.outlineVariant),
              Row(
                children: [
                  _StatusIcon(status: status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _phaseTitle(status),
                              style: textTheme.titleMedium,
                            ),
                            _StatusChip(
                              label: status.config.modelSourceDisplayName,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _statusDetail(status),
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _PrepareModelButton(
                    runtime: runtime,
                    status: status,
                    isProcessing: isProcessing,
                  ),
                ],
              ),
              if (status.isRunning || progress != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: progress?.clamp(0.0, 1.0),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(
                    icon: Icons.storage_outlined,
                    text: _cacheLabel(status.config.cacheDirectory),
                  ),
                  _MetaChip(
                    icon: Icons.policy_outlined,
                    text: _cachePolicyLabel(status.config.cachePolicy.name),
                  ),
                  if (status.errorMessage != null)
                    _MetaChip(
                      icon: Icons.error_outline,
                      text: status.errorMessage!,
                      isError: true,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InjectedStatusSurface extends StatelessWidget {
  const _InjectedStatusSurface({
    required this.runtime,
    required this.selectedRoute,
    required this.isProcessing,
    required this.compact,
  });

  final AppRuntime runtime;
  final GenUiAiRoute selectedRoute;
  final bool isProcessing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactStatusSurface(
        runtime: runtime,
        selectedRoute: selectedRoute,
        isProcessing: isProcessing,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SquareIcon(icon: _routeIcon(selectedRoute)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Injected backend',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    runtime.backendLabel,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  _RouteSelector(
                    runtime: runtime,
                    selectedRoute: selectedRoute,
                    isProcessing: isProcessing,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isProcessing)
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompactStatusSurface extends StatelessWidget {
  const _CompactStatusSurface({
    required this.runtime,
    required this.selectedRoute,
    required this.isProcessing,
    this.status,
  });

  final AppRuntime runtime;
  final GenUiAiRoute selectedRoute;
  final bool isProcessing;
  final ModelRuntimeStatus? status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = status?.progress;
    final showProgress = (status?.isRunning ?? false) || progress != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _SquareIcon(icon: _routeIcon(selectedRoute), dimension: 32),
                const SizedBox(width: 9),
                Expanded(
                  child: _CompactRouteSummary(
                    runtime: runtime,
                    status: status,
                    selectedRoute: selectedRoute,
                  ),
                ),
                if (selectedRoute == GenUiAiRoute.local && status != null) ...[
                  const SizedBox(width: 6),
                  _PrepareModelButton(
                    runtime: runtime,
                    status: status!,
                    isProcessing: isProcessing,
                    compact: true,
                  ),
                ],
                const SizedBox(width: 4),
                _RouteMenuButton(
                  runtime: runtime,
                  selectedRoute: selectedRoute,
                  isProcessing: isProcessing,
                ),
                const SizedBox(width: 4),
                _RouteSettingsButton(
                  runtime: runtime,
                  selectedRoute: selectedRoute,
                  isProcessing: isProcessing,
                  compact: true,
                ),
              ],
            ),
            if (showProgress) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  value: progress?.clamp(0.0, 1.0),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactRouteSummary extends StatelessWidget {
  const _CompactRouteSummary({
    required this.runtime,
    required this.selectedRoute,
    this.status,
  });

  final AppRuntime runtime;
  final GenUiAiRoute selectedRoute;
  final ModelRuntimeStatus? status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${selectedRoute.label} route',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 1),
        Text(
          _compactRouteDetail(runtime, selectedRoute, status),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RouteHeader extends StatelessWidget {
  const _RouteHeader({
    required this.runtime,
    required this.selectedRoute,
    required this.isProcessing,
  });

  final AppRuntime runtime;
  final GenUiAiRoute selectedRoute;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final selector = _RouteSelector(
      runtime: runtime,
      selectedRoute: selectedRoute,
      isProcessing: isProcessing,
    );
    final settingsButton = _RouteSettingsButton(
      runtime: runtime,
      selectedRoute: selectedRoute,
      isProcessing: isProcessing,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final summary = _RouteSummary(
          runtime: runtime,
          selectedRoute: selectedRoute,
        );
        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _SquareIcon(icon: _routeIcon(selectedRoute)),
                  const SizedBox(width: 12),
                  Expanded(child: summary),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [selector, settingsButton],
              ),
            ],
          );
        }

        return Row(
          children: [
            _SquareIcon(icon: _routeIcon(selectedRoute)),
            const SizedBox(width: 12),
            Expanded(child: summary),
            const SizedBox(width: 12),
            selector,
            const SizedBox(width: 8),
            settingsButton,
          ],
        );
      },
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.runtime, required this.selectedRoute});

  final AppRuntime runtime;
  final GenUiAiRoute selectedRoute;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Active AI route', style: textTheme.titleMedium),
        const SizedBox(height: 3),
        Text(
          _routeDetail(runtime, selectedRoute),
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (selectedRoute == GenUiAiRoute.gemini &&
                !runtime.geminiConfig.value.hasApiKey)
              const _MetaChip(
                icon: Icons.key_off_outlined,
                text: 'Gemini key missing',
                isError: true,
              ),
            if (selectedRoute == GenUiAiRoute.backend)
              _MetaChip(
                icon: Icons.link_outlined,
                text: _shortPath(
                  runtime.backendConfig.value.endpoint.toString(),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RouteSettingsButton extends StatelessWidget {
  const _RouteSettingsButton({
    required this.runtime,
    required this.selectedRoute,
    required this.isProcessing,
    this.compact = false,
  });

  final AppRuntime runtime;
  final GenUiAiRoute selectedRoute;
  final bool isProcessing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: compact ? 36 : 40,
      child: IconButton.outlined(
        tooltip: 'Route settings',
        onPressed: isProcessing
            ? null
            : () => showRouteSettingsDialog(context, runtime, selectedRoute),
        icon: Icon(Icons.tune, size: compact ? 18 : 20),
      ),
    );
  }
}

class _RouteMenuButton extends StatelessWidget {
  const _RouteMenuButton({
    required this.runtime,
    required this.selectedRoute,
    required this.isProcessing,
  });

  final AppRuntime runtime;
  final GenUiAiRoute selectedRoute;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 36,
      child: PopupMenuButton<GenUiAiRoute>(
        tooltip: 'AI route',
        enabled: !isProcessing,
        icon: const Icon(Icons.swap_horiz, size: 20),
        initialValue: selectedRoute,
        onSelected: (route) => runtime.selectedRoute.value = route,
        itemBuilder: (context) {
          return [
            for (final route in GenUiAiRoute.values)
              PopupMenuItem<GenUiAiRoute>(
                value: route,
                child: ListTile(
                  dense: true,
                  leading: Icon(_routeIcon(route), size: 18),
                  title: Text(route.label),
                  selected: route == selectedRoute,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
          ];
        },
      ),
    );
  }
}

class _PrepareModelButton extends StatelessWidget {
  const _PrepareModelButton({
    required this.runtime,
    required this.status,
    required this.isProcessing,
    this.compact = false,
  });

  final AppRuntime runtime;
  final ModelRuntimeStatus status;
  final bool isProcessing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: compact ? 36 : 40,
      child: IconButton.outlined(
        tooltip: status.isReady ? 'Model ready' : 'Prepare model',
        onPressed: status.isRunning || isProcessing
            ? null
            : _prepareModel(runtime),
        icon: Icon(
          status.isReady ? Icons.check : Icons.download,
          size: compact ? 18 : 20,
        ),
      ),
    );
  }
}

class _RouteSelector extends StatelessWidget {
  const _RouteSelector({
    required this.runtime,
    required this.selectedRoute,
    required this.isProcessing,
  });

  final AppRuntime runtime;
  final GenUiAiRoute selectedRoute;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<GenUiAiRoute>(
      selected: {selectedRoute},
      onSelectionChanged: isProcessing
          ? null
          : (selection) {
              runtime.selectedRoute.value = selection.single;
            },
      showSelectedIcon: false,
      segments: [
        for (final route in GenUiAiRoute.values)
          ButtonSegment<GenUiAiRoute>(
            value: route,
            icon: Icon(_routeIcon(route), size: 18),
            label: Text(route.label),
          ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final ModelRuntimeStatus status;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status.phase) {
      ModelRuntimePhase.downloading => Icons.downloading,
      ModelRuntimePhase.failed => Icons.error_outline,
      ModelRuntimePhase.ready => Icons.memory,
      _ => Icons.memory_outlined,
    };
    return _SquareIcon(icon: icon);
  }
}

class _SquareIcon extends StatelessWidget {
  const _SquareIcon({required this.icon, this.dimension = 38});

  final IconData icon;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Icon(
        icon,
        size: dimension <= 32 ? 18 : null,
        color: colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.text,
    this.isError = false,
  });

  final IconData icon;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: isError ? colorScheme.errorContainer : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? colorScheme.error : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isError
                ? colorScheme.onErrorContainer
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isError
                    ? colorScheme.onErrorContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _phaseTitle(ModelRuntimeStatus status) {
  return switch (status.phase) {
    ModelRuntimePhase.idle => 'Local model queued',
    ModelRuntimePhase.resolving => 'Resolving ${status.assetLabel}',
    ModelRuntimePhase.checkingCache => 'Checking cache',
    ModelRuntimePhase.downloading => 'Downloading ${status.assetLabel}',
    ModelRuntimePhase.verifying => 'Verifying ${status.assetLabel}',
    ModelRuntimePhase.loading => 'Loading llamadart',
    ModelRuntimePhase.ready => 'Local model ready',
    ModelRuntimePhase.failed => 'Model setup failed',
    ModelRuntimePhase.cancelled => 'Model setup cancelled',
  };
}

String _statusDetail(ModelRuntimeStatus status) {
  final resolvedPath = status.resolvedModelPath;
  if (status.phase == ModelRuntimePhase.ready && resolvedPath != null) {
    return _shortPath(resolvedPath);
  }
  if (status.phase == ModelRuntimePhase.failed && status.errorMessage != null) {
    return status.errorMessage!;
  }
  return status.config.modelSource.metadataSourceKey;
}

String _cacheLabel(String? cacheDirectory) {
  if (cacheDirectory == null || cacheDirectory.isEmpty) return 'default cache';
  return _shortPath(cacheDirectory);
}

String _cachePolicyLabel(String value) {
  return value
      .replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}')
      .trim()
      .toLowerCase();
}

String _shortPath(String value) {
  if (value.length <= 52) return value;
  return '...${value.substring(value.length - 49)}';
}

IconData _routeIcon(GenUiAiRoute route) {
  return switch (route) {
    GenUiAiRoute.local => Icons.memory,
    GenUiAiRoute.gemini => Icons.auto_awesome,
    GenUiAiRoute.backend => Icons.dns_outlined,
  };
}

String _routeDetail(AppRuntime runtime, GenUiAiRoute route) {
  return switch (route) {
    GenUiAiRoute.local =>
      'On-device llamadart using ${runtime.config.localModel.modelSourceDisplayName}',
    GenUiAiRoute.gemini =>
      'Direct Genkit Gemini provider using ${runtime.geminiConfig.value.modelName}',
    GenUiAiRoute.backend =>
      'Remote Genkit flow at ${runtime.backendConfig.value.endpoint}',
  };
}

String _compactRouteDetail(
  AppRuntime runtime,
  GenUiAiRoute route,
  ModelRuntimeStatus? status,
) {
  return switch (route) {
    GenUiAiRoute.local =>
      status == null
          ? runtime.config.localModel.modelSourceDisplayName
          : _compactLocalStatus(status),
    GenUiAiRoute.gemini =>
      runtime.geminiConfig.value.hasApiKey
          ? runtime.geminiConfig.value.modelName
          : 'API key missing',
    GenUiAiRoute.backend => _shortPath(
      runtime.backendConfig.value.endpoint.toString(),
    ),
  };
}

String _compactLocalStatus(ModelRuntimeStatus status) {
  if (status.phase == ModelRuntimePhase.ready) {
    return status.config.modelSourceDisplayName;
  }
  if (status.phase == ModelRuntimePhase.failed && status.errorMessage != null) {
    return status.errorMessage!;
  }
  return _phaseTitle(status);
}

VoidCallback? _prepareModel(AppRuntime runtime) {
  final prepareModel = runtime.prepareModel;
  if (prepareModel == null) return null;
  return () => unawaited(prepareModel());
}
