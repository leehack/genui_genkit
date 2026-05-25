import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import 'session.dart';

typedef GenUiMessageWidgetBuilder =
    Widget Function(BuildContext context, GenUiChatEntry message);

final class GenUiMessageList extends StatelessWidget {
  const GenUiMessageList({
    super.key,
    required this.session,
    this.controller,
    this.padding = const EdgeInsets.all(12),
    this.messageBuilder,
  });

  final GenkitGenUiSession session;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;
  final GenUiMessageWidgetBuilder? messageBuilder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final messages = session.messages;
        return ListView.separated(
          controller: controller,
          padding: padding,
          itemCount: messages.length + (session.isProcessing ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index >= messages.length) {
              return const GenUiThinkingIndicator();
            }
            final message = messages[index];
            return messageBuilder?.call(context, message) ??
                GenUiMessageView(session: session, message: message);
          },
        );
      },
    );
  }
}

final class GenUiMessageView extends StatelessWidget {
  const GenUiMessageView({
    super.key,
    required this.session,
    required this.message,
  });

  final GenkitGenUiSession session;
  final GenUiChatEntry message;

  @override
  Widget build(BuildContext context) {
    if (message.surfaceId case final surfaceId?) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Surface(
          surfaceContext: session.surfaceController.contextFor(surfaceId),
          defaultBuilder: (_) => const SizedBox.shrink(),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: message.isError
              ? colorScheme.errorContainer
              : isUser
              ? colorScheme.primary
              : colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            (message.text ?? '').trimRight(),
            style: TextStyle(
              color: message.isError
                  ? colorScheme.onErrorContainer
                  : isUser
                  ? colorScheme.onPrimary
                  : colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

final class GenUiPromptComposer extends StatefulWidget {
  const GenUiPromptComposer({
    super.key,
    required this.onSubmit,
    this.enabled = true,
    this.hintText = 'Ask the model...',
  });

  final ValueChanged<String> onSubmit;
  final bool enabled;
  final String hintText;

  @override
  State<GenUiPromptComposer> createState() => _GenUiPromptComposerState();
}

class _GenUiPromptComposerState extends State<GenUiPromptComposer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    _controller.clear();
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      minLines: 1,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: widget.hintText,
        suffixIcon: IconButton(
          tooltip: 'Send',
          onPressed: widget.enabled ? _submit : null,
          icon: const Icon(Icons.send),
        ),
      ),
      onSubmitted: (_) => _submit(),
    );
  }
}

final class GenUiThinkingIndicator extends StatelessWidget {
  const GenUiThinkingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
