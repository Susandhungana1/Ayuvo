/// The health assistant.
///
/// A full screen rather than the web app's floating bubble: a bubble over a
/// medicine list is a desktop pattern, and on a phone it covers the thing you
/// were reading. It is reached from Account, and never from a caretaker
/// context — the assistant answers as *you*, and a caretaker managing somebody
/// else's medicines must not be one tap away from a chat that looks like it
/// knows about them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../domain/chat_message.dart';
import 'assistant_controller.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _field = TextEditingController();
  final _scroll = ScrollController();
  final _speech = SpeechToText();

  bool _speechReady = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _prepareSpeech();
  }

  @override
  void dispose() {
    _field.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Asked for once, on open, so the mic button is either there and working or
  /// not there at all. A button that fails when tapped is worse than no button.
  Future<void> _prepareSpeech() async {
    try {
      final ready = await _speech.initialize(
        onStatus: (status) {
          if (mounted) setState(() => _listening = _speech.isListening);
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
      if (mounted) setState(() => _speechReady = ready);
    } catch (_) {
      // No recogniser, no permission, or a platform without either. The screen
      // works perfectly well by typing.
      if (mounted) setState(() => _speechReady = false);
    }
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        // Only the settled transcription is written into the box; the interim
        // guesses rewrite themselves several times a second and make the field
        // unreadable while someone is still talking.
        if (!result.finalResult) return;
        final spoken = result.recognizedWords.trim();
        if (spoken.isEmpty) return;
        final existing = _field.text.trim();
        _field.text = existing.isEmpty ? spoken : '$existing $spoken';
        _field.selection =
            TextSelection.collapsed(offset: _field.text.length);
      },
    );
  }

  Future<void> _send() async {
    final text = _field.text.trim();
    if (text.isEmpty) return;
    _field.clear();
    if (_listening) await _speech.stop();
    await ref.read(assistantProvider.notifier).send(text);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    // After the frame that added the bubble, or the extent is the old one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppMotion.of(context, AppMotion.base),
        curve: AppMotion.enter,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantProvider);

    // A new assistant turn arrives asynchronously; scroll when it does.
    ref.listen(assistantProvider, (_, _) => _scrollToEnd());

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.assistantTitle),
        actions: [
          if (!state.isEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: context.l10n.assistantClear,
              onPressed: () {
                ref.read(assistantProvider.notifier).clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.assistantCleared)),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: AppSpacing.screen,
                children: [
                  const _Disclaimer(),
                  const SizedBox(height: AppSpacing.lg),
                  if (state.isEmpty) const _Greeting(),
                  for (final (index, message) in state.messages.indexed)
                    _Bubble(
                      key: ValueKey(index),
                      message: message,
                      onRetry: message.failed &&
                              index == state.messages.length - 1 &&
                              state.unavailable?.permanent != true
                          ? () => ref
                              .read(assistantProvider.notifier)
                              .retryLast()
                          : null,
                    ),
                  if (state.sending) const _Thinking(),
                ],
              ),
            ),
            if (state.unavailable?.permanent ?? false)
              _Unavailable(message: state.unavailable!.message)
            else
              _Composer(
                field: _field,
                enabled: state.canSend,
                listening: _listening,
                canSpeak: _speechReady,
                onSend: _send,
                onSpeak: _toggleListening,
              ),
          ],
        ),
      ),
    );
  }
}

/// Above the conversation, not below it, and not dismissible. It is the first
/// thing read and it stays true for every answer underneath.
class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 16,
          color: context.colors.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            context.l10n.assistantDisclaimer,
            style: context.texts.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        children: [
          Icon(
            Icons.forum_outlined,
            size: 40,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.l10n.assistantGreeting,
            style: context.texts.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.message, this.onRetry});

  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final mine = message.role == ChatRole.user;
    final (background, foreground) = switch ((mine, message.failed)) {
      (true, _) => (context.colors.primaryContainer, context.colors.onPrimaryContainer),
      (false, true) => (context.colors.errorContainer, context.colors.onErrorContainer),
      (false, false) => (context.colors.surfaceContainerHigh, context.colors.onSurface),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            // Never the full width: an edge-to-edge bubble on both sides makes
            // it impossible to see at a glance who said what.
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.85,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: AppRadius.md,
              ),
              child: SelectableText(
                message.content,
                style: context.texts.bodyMedium?.copyWith(color: foreground),
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          context.l10n.assistantThinking,
          style: context.texts.bodySmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.field,
    required this.enabled,
    required this.listening,
    required this.canSpeak,
    required this.onSend,
    required this.onSpeak,
  });

  final TextEditingController field;
  final bool enabled;
  final bool listening;
  final bool canSpeak;
  final VoidCallback onSend;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: field,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: listening
                    ? context.l10n.assistantListening
                    : context.l10n.assistantHint,
              ),
            ),
          ),
          if (canSpeak) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton.filledTonal(
              onPressed: enabled ? onSpeak : null,
              tooltip: context.l10n.assistantVoice,
              isSelected: listening,
              icon: Icon(listening ? Icons.mic : Icons.mic_none),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          IconButton.filled(
            onPressed: enabled ? onSend : null,
            tooltip: context.l10n.assistantSend,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

/// No key on this server. The composer is replaced rather than disabled: a
/// greyed-out box invites tapping it to find out why.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.card,
      color: context.colors.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.assistantOffTitle, style: context.texts.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: context.texts.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
