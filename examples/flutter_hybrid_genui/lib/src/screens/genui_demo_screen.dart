import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../runtime/app_runtime.dart';
import '../widgets/conversation_pane.dart';
import '../widgets/prompt_composer.dart';
import '../widgets/prompt_suggestion_bar.dart';
import '../widgets/raw_output_panel.dart';
import '../widgets/runtime_status_card.dart';

class GenUiDemoScreen extends StatefulWidget {
  const GenUiDemoScreen({super.key, required this.runtime});

  final AppRuntime runtime;

  @override
  State<GenUiDemoScreen> createState() => _GenUiDemoScreenState();
}

class _GenUiDemoScreenState extends State<GenUiDemoScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _surfaceKeys = <String, GlobalKey>{};
  final _rawText = _RawTextBuffer();
  Object? _lastError;
  StreamSubscription<String>? _rawSub;
  StreamSubscription<Object>? _errorSub;
  var _knownMessageCount = 0;

  @override
  void initState() {
    super.initState();
    widget.runtime.session.addListener(_handleSessionChanged);
    _rawSub = widget.runtime.session.rawText.listen((chunk) {
      _rawText.append(chunk);
      if (mounted) setState(() {});
    });
    _errorSub = widget.runtime.session.errors.listen((error) {
      if (mounted) setState(() => _lastError = error);
    });
  }

  @override
  void dispose() {
    widget.runtime.session.removeListener(_handleSessionChanged);
    unawaited(_rawSub?.cancel());
    unawaited(_errorSub?.cancel());
    widget.runtime.dispose();
    _rawText.dispose();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleSessionChanged() {
    final messages = widget.runtime.session.messages;
    if (messages.length > _knownMessageCount && messages.isNotEmpty) {
      final latest = messages.last;
      final surfaceId = latest.surfaceId;
      if (surfaceId != null) {
        _surfaceKeys.putIfAbsent(surfaceId, GlobalKey.new);
        _scheduleScrollToSurface(surfaceId);
      } else {
        _scheduleScrollToEnd();
      }
    }
    _knownMessageCount = messages.length;
  }

  void _scheduleScrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      unawaited(
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  void _scheduleScrollToSurface(String surfaceId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final surfaceContext = _surfaceKeys[surfaceId]?.currentContext;
      if (surfaceContext == null) {
        _scheduleScrollToEnd();
        return;
      }
      unawaited(
        Scrollable.ensureVisible(
          surfaceContext,
          alignment: 0.04,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  Future<void> _send(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty) return;
    _controller.clear();
    await widget.runtime.session.sendText(prompt);
  }

  void _clearRun() {
    if (widget.runtime.session.isProcessing) return;
    widget.runtime.session.clear();
    setState(() {
      _surfaceKeys.clear();
      _knownMessageCount = 0;
      _rawText.clear();
      _lastError = null;
    });
  }

  void _showRawInspector() {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return FractionallySizedBox(
            heightFactor: 0.82,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ValueListenableBuilder<String>(
                valueListenable: _rawText,
                builder: (context, rawText, _) {
                  return RawOutputPanel(
                    rawText: rawText,
                    initiallyExpanded: true,
                    maxHeight: 520,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCatalogInspector() {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return FractionallySizedBox(
            heightFactor: 0.62,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SingleChildScrollView(
                child: _CapabilityCard(runtime: widget.runtime),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomPaint(
        painter: _WorkbenchBackgroundPainter(colorScheme),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: widget.runtime.session,
            builder: (context, _) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1380),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final showSidePanel = constraints.maxWidth >= 1280;
                        final content = _MainContent(
                          runtime: widget.runtime,
                          lastError: _lastError,
                          onDismissError: () =>
                              setState(() => _lastError = null),
                          onClear: _clearRun,
                          onShowRaw: _showRawInspector,
                          onShowCatalog: _showCatalogInspector,
                          onSend: _send,
                          controller: _controller,
                          scrollController: _scrollController,
                          surfaceKeys: _surfaceKeys,
                        );

                        if (!showSidePanel) return content;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 10, child: content),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 3,
                              child: _SidePanel(
                                runtime: widget.runtime,
                                rawText: _rawText.value,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

final class _RawTextBuffer extends ChangeNotifier
    implements ValueListenable<String> {
  final _buffer = StringBuffer();

  @override
  String get value => _buffer.toString();

  void append(String chunk) {
    if (chunk.isEmpty) return;
    _buffer.write(chunk);
    notifyListeners();
  }

  void clear() {
    if (_buffer.isEmpty) return;
    _buffer.clear();
    notifyListeners();
  }
}

class _MainContent extends StatelessWidget {
  const _MainContent({
    required this.runtime,
    required this.lastError,
    required this.onDismissError,
    required this.onClear,
    required this.onShowRaw,
    required this.onShowCatalog,
    required this.onSend,
    required this.controller,
    required this.scrollController,
    required this.surfaceKeys,
  });

  final AppRuntime runtime;
  final Object? lastError;
  final VoidCallback onDismissError;
  final VoidCallback onClear;
  final VoidCallback onShowRaw;
  final VoidCallback onShowCatalog;
  final ValueChanged<String> onSend;
  final TextEditingController controller;
  final ScrollController scrollController;
  final Map<String, GlobalKey> surfaceKeys;

  @override
  Widget build(BuildContext context) {
    final session = runtime.session;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroHeader(
          isProcessing: session.isProcessing,
          onClear: onClear,
          onShowRaw: onShowRaw,
          onShowCatalog: onShowCatalog,
        ),
        const SizedBox(height: 8),
        RuntimeStatusCard(runtime: runtime, isProcessing: session.isProcessing),
        const SizedBox(height: 8),
        PromptSuggestionBar(
          isProcessing: session.isProcessing,
          onPromptSelected: onSend,
        ),
        if (lastError != null) ...[
          const SizedBox(height: 8),
          _ErrorBanner(error: lastError!, onDismiss: onDismissError),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: ConversationPane(
            controller: scrollController,
            messages: session.messages,
            surfaceController: session.surfaceController,
            isProcessing: session.isProcessing,
            surfaceKeys: surfaceKeys,
          ),
        ),
        const SizedBox(height: 8),
        PromptComposer(
          controller: controller,
          isProcessing: session.isProcessing,
          onSubmit: onSend,
        ),
      ],
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.runtime, required this.rawText});

  final AppRuntime runtime;
  final String rawText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CapabilityCard(runtime: runtime),
        const SizedBox(height: 12),
        Expanded(child: RawOutputPanel(rawText: rawText)),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.isProcessing,
    required this.onClear,
    required this.onShowRaw,
    required this.onShowCatalog,
  });

  final bool isProcessing;
  final VoidCallback onClear;
  final VoidCallback onShowRaw;
  final VoidCallback onShowCatalog;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.view_quilt_outlined,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hybrid GenUI Workbench',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Route each turn to llamadart, Gemini, or a Genkit backend.',
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _HeaderToolButton(
          tooltip: 'Catalog',
          icon: Icons.widgets_outlined,
          onPressed: onShowCatalog,
        ),
        const SizedBox(width: 6),
        _HeaderToolButton(
          tooltip: 'Raw stream',
          icon: Icons.data_object,
          onPressed: onShowRaw,
        ),
        const SizedBox(width: 6),
        _HeaderToolButton(
          tooltip: 'New run',
          icon: Icons.add_circle_outline,
          onPressed: isProcessing ? null : onClear,
        ),
      ],
    );
  }
}

class _HeaderToolButton extends StatelessWidget {
  const _HeaderToolButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 38,
      child: IconButton.outlined(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.runtime});

  final AppRuntime runtime;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current catalog',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            const _CapabilityRow(
              icon: Icons.route_outlined,
              label: 'ItineraryPlan',
            ),
            const _CapabilityRow(icon: Icons.event_note, label: 'ActivityCard'),
            const _CapabilityRow(icon: Icons.rule, label: 'Checklist'),
            const _CapabilityRow(icon: Icons.tune, label: 'ChoicePicker'),
            const _CapabilityRow(icon: Icons.view_agenda, label: 'Column'),
            Divider(height: 24, color: colorScheme.outlineVariant),
            Text(
              'Local catalog widgets only; streamed A2UI cannot execute arbitrary Flutter code.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.onDismiss});

  final Object error;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.38)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error.toString(),
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
              color: colorScheme.onErrorContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkbenchBackgroundPainter extends CustomPainter {
  const _WorkbenchBackgroundPainter(this.colorScheme);

  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    const spacing = 44.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), basePaint);
    }
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), basePaint);
    }

    final accentPaint = Paint()
      ..color = colorScheme.tertiary.withValues(alpha: 0.12)
      ..strokeWidth = 2;
    for (var y = -size.width; y < size.height; y += 180) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + size.width),
        accentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WorkbenchBackgroundPainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme;
  }
}
