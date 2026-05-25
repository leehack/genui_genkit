import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_genkit/genui_genkit.dart';

import 'message_bubble.dart';

class ConversationPane extends StatelessWidget {
  const ConversationPane({
    super.key,
    required this.controller,
    required this.messages,
    required this.surfaceController,
    required this.isProcessing,
    required this.surfaceKeys,
  });

  final ScrollController controller;
  final List<GenUiChatEntry> messages;
  final SurfaceController surfaceController;
  final bool isProcessing;
  final Map<String, GlobalKey> surfaceKeys;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: messages.isEmpty && !isProcessing
            ? const _EmptyConversationState()
            : ListView.separated(
                controller: controller,
                padding: const EdgeInsets.all(14),
                itemCount: messages.length + (isProcessing ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index >= messages.length) {
                    return const _ThinkingRow();
                  }
                  return MessageBubble(
                    key: messages[index].surfaceId == null
                        ? null
                        : surfaceKeys[messages[index].surfaceId!],
                    message: messages[index],
                    surfaceController: surfaceController,
                  );
                },
              ),
      ),
    );
  }
}

class _ThinkingRow extends StatelessWidget {
  const _ThinkingRow();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                'Streaming response',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyConversationState extends StatelessWidget {
  const _EmptyConversationState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 180) {
          return Center(
            child: Text(
              'Ready to render A2UI.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.dashboard_customize_outlined,
                    size: 48,
                    color: colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ask for a plan',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The model can answer in prose and stream A2UI surfaces for itineraries, cards, choices, and checklists.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
