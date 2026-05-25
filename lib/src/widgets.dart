import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import 'session.dart';

/// Builds a custom widget for one [GenUiChatEntry].
typedef GenUiMessageWidgetBuilder =
    Widget Function(BuildContext context, GenUiChatEntry message);

/// Renders the chat entries and generated surfaces from a session.
final class GenUiMessageList extends StatelessWidget {
  /// Creates a message list bound to [session].
  const GenUiMessageList({
    super.key,
    required this.session,
    this.controller,
    this.padding = const EdgeInsets.all(12),
    this.messageBuilder,
  });

  /// Session whose messages should be rendered.
  final GenkitGenUiSession session;

  /// Optional scroll controller for the underlying list.
  final ScrollController? controller;

  /// Padding around the list content.
  final EdgeInsetsGeometry padding;

  /// Optional custom message renderer.
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

/// Default renderer for one [GenUiChatEntry].
final class GenUiMessageView extends StatelessWidget {
  /// Creates a default message view.
  const GenUiMessageView({
    super.key,
    required this.session,
    required this.message,
  });

  /// Session that owns rendered GenUI surfaces.
  final GenkitGenUiSession session;

  /// Chat entry to render.
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

/// Text input for submitting prompts to a GenUI session.
final class GenUiPromptComposer extends StatefulWidget {
  /// Creates a prompt composer.
  const GenUiPromptComposer({
    super.key,
    required this.onSubmit,
    this.enabled = true,
    this.hintText = 'Ask the model...',
  });

  /// Called with the trimmed prompt when the user submits.
  final ValueChanged<String> onSubmit;

  /// Whether the input accepts edits and submissions.
  final bool enabled;

  /// Placeholder text for the input.
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

/// Compact busy indicator shown while a backend turn is in progress.
final class GenUiThinkingIndicator extends StatelessWidget {
  /// Creates a thinking indicator.
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
