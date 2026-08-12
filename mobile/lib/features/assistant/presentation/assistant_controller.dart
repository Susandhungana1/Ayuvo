/// The conversation, held in memory for as long as the app is running.
///
/// Nothing is persisted, on either side: `chatbot.py` keeps no thread and this
/// keeps no file. The transcript survives switching tabs — a plain
/// `NotifierProvider` outlives the widget — and dies with the process, which is
/// the right lifetime for a list of somebody's symptoms.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/chat_repository.dart';
import '../domain/chat_message.dart';

@immutable
class AssistantState {
  const AssistantState({
    this.messages = const [],
    this.sending = false,
    this.unavailable,
  });

  final List<ChatMessage> messages;
  final bool sending;

  /// Set when the assistant cannot work at all on this server — no key
  /// configured. The composer is hidden rather than left there to fail again.
  final AssistantUnavailable? unavailable;

  bool get isEmpty => messages.isEmpty;

  bool get canSend => !sending && unavailable?.permanent != true;
}

final assistantProvider =
    NotifierProvider<AssistantController, AssistantState>(
  AssistantController.new,
);

class AssistantController extends Notifier<AssistantState> {
  @override
  AssistantState build() => const AssistantState();

  Future<void> send(String text) async {
    final question = text.trim();
    if (question.isEmpty || !state.canSend) return;

    final asked = [...state.messages, ChatMessage.user(question)];
    state = AssistantState(messages: asked, sending: true);

    try {
      final reply = await ref
          .read(chatRepositoryProvider)
          .reply(historyToSend(asked));
      state = AssistantState(messages: [...asked, ChatMessage.assistant(reply)]);
    } on AssistantUnavailable catch (failure) {
      state = AssistantState(
        messages: [
          ...asked,
          ChatMessage.assistant(failure.message, failed: true),
        ],
        unavailable: failure,
      );
    } catch (error) {
      // The question stays in the transcript so it can be re-sent by tapping
      // Retry — retyping a paragraph because the network blinked is the worst
      // part of every chat UI.
      state = AssistantState(
        messages: [
          ...asked,
          ChatMessage.assistant(ApiException.from(error).message, failed: true),
        ],
      );
    }
  }

  /// Drops the failed reply and asks the same question again.
  Future<void> retryLast() async {
    final messages = state.messages;
    if (messages.isEmpty || !messages.last.failed) return;

    final withoutFailure = messages.sublist(0, messages.length - 1);
    final lastQuestion = withoutFailure.lastWhere(
      (message) => message.role == ChatRole.user,
      orElse: () => const ChatMessage.user(''),
    );
    if (lastQuestion.content.isEmpty) return;

    // Drop the question too — `send` puts it back, so it does not appear twice.
    final index = withoutFailure.lastIndexOf(lastQuestion);
    state = AssistantState(messages: withoutFailure.sublist(0, index));
    await send(lastQuestion.content);
  }

  void clear() => state = const AssistantState();
}
