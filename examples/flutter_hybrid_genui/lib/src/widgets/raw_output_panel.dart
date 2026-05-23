import 'package:flutter/material.dart';

class RawOutputPanel extends StatefulWidget {
  const RawOutputPanel({
    super.key,
    required this.rawText,
    this.initiallyExpanded = false,
    this.maxHeight = 260,
  });

  final String rawText;
  final bool initiallyExpanded;
  final double maxHeight;

  @override
  State<RawOutputPanel> createState() => _RawOutputPanelState();
}

class _RawOutputPanelState extends State<RawOutputPanel> {
  late var _expanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(covariant RawOutputPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _expanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final hasFiniteHeight = constraints.maxHeight.isFinite;
            final hasRoomForBody =
                !hasFiniteHeight || constraints.maxHeight > 128;
            final body = AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: _expanded
                  ? _RawCodeBox(
                      key: const ValueKey('raw-expanded'),
                      rawText: widget.rawText,
                    )
                  : _RawPreview(
                      key: const ValueKey('raw-preview'),
                      rawText: widget.rawText,
                    ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RawHeader(
                  rawText: widget.rawText,
                  expanded: _expanded,
                  onToggle: () => setState(() => _expanded = !_expanded),
                ),
                if (hasRoomForBody)
                  if (hasFiniteHeight)
                    Expanded(child: body)
                  else
                    SizedBox(height: widget.maxHeight, child: body),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RawHeader extends StatelessWidget {
  const _RawHeader({
    required this.rawText,
    required this.expanded,
    required this.onToggle,
  });

  final String rawText;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3),
        border: Border(
          bottom: BorderSide(
            color: expanded ? colorScheme.outlineVariant : Colors.transparent,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Icon(
              Icons.data_object,
              size: 18,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Raw stream',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  rawText.isEmpty
                      ? 'Waiting for chunks'
                      : '${rawText.length} characters',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: expanded ? 'Collapse raw stream' : 'Expand raw stream',
            onPressed: onToggle,
            icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
          ),
        ],
      ),
    );
  }
}

class _RawPreview extends StatelessWidget {
  const _RawPreview({super.key, required this.rawText});

  final String rawText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final preview = _previewText(rawText);
    return Container(
      alignment: rawText.isEmpty ? Alignment.center : Alignment.topLeft,
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFFFFBF3),
      child: rawText.isEmpty
          ? Text(
              'Stream chunks appear here.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : Text(
              preview,
              maxLines: 8,
              overflow: TextOverflow.fade,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
                height: 1.35,
              ),
            ),
    );
  }
}

class _RawCodeBox extends StatelessWidget {
  const _RawCodeBox({super.key, required this.rawText});

  final String rawText;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF25231F),
      child: rawText.isEmpty
          ? Center(
              child: Text(
                'Send a prompt to inspect stream chunks.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFFEAE0CF)),
              ),
            )
          : Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: SelectableText(
                  rawText.trimRight(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFF2E9D8),
                    fontFamily: 'monospace',
                    height: 1.35,
                  ),
                ),
              ),
            ),
    );
  }
}

String _previewText(String rawText) {
  return rawText
      .trimRight()
      .split('\n')
      .take(10)
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');
}
