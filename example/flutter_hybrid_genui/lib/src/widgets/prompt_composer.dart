import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PromptComposer extends StatelessWidget {
  const PromptComposer({
    super.key,
    required this.controller,
    required this.isProcessing,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isProcessing;
  final ValueChanged<String> onSubmit;

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
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.enter): () {
                    if (!isProcessing) onSubmit(controller.text);
                  },
                },
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.chat_bubble_outline),
                    hintText: 'Ask for an itinerary, options, or prep list...',
                  ),
                  onSubmitted: isProcessing ? null : onSubmit,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox.square(
              dimension: 48,
              child: IconButton.filled(
                tooltip: 'Send',
                onPressed: isProcessing
                    ? null
                    : () => onSubmit(controller.text),
                icon: isProcessing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
