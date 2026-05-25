import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_genkit/genui_genkit.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.surfaceController,
  });

  final GenUiChatEntry message;
  final SurfaceController surfaceController;

  @override
  Widget build(BuildContext context) {
    if (message.surfaceId != null) {
      final colorScheme = Theme.of(context).colorScheme;
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Surface(
                surfaceContext: surfaceController.contextFor(
                  message.surfaceId!,
                ),
                defaultBuilder: (_) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final alignment = message.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final color = message.isError
        ? colorScheme.errorContainer
        : message.isUser
        ? colorScheme.primary
        : const Color(0xFFE6F0EA);
    final textColor = message.isError
        ? colorScheme.onErrorContainer
        : message.isUser
        ? colorScheme.onPrimary
        : colorScheme.onSecondaryContainer;
    final displayText = _displayText(message.text ?? '');

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(8),
              topRight: const Radius.circular(8),
              bottomLeft: Radius.circular(message.isUser ? 8 : 3),
              bottomRight: Radius.circular(message.isUser ? 3 : 8),
            ),
            border: Border.all(
              color: message.isUser
                  ? colorScheme.primary.withValues(alpha: 0.28)
                  : colorScheme.secondary.withValues(alpha: 0.22),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(
              displayText,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: textColor),
            ),
          ),
        ),
      ),
    );
  }
}

String _displayText(String text) {
  return text.trimRight().replaceAll(RegExp(r'\n{3,}'), '\n\n');
}
