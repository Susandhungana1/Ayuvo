/// The assistant, whose whole conversation is resent on every turn.
///
/// That makes two things worth pinning down: what goes back up (bounded, and
/// free of the app's own error messages), and what a failure leaves on screen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medistore/core/network/api_exception.dart';
import 'package:medistore/features/assistant/data/chat_repository.dart';
import 'package:medistore/features/assistant/domain/chat_message.dart';
import 'package:medistore/features/assistant/presentation/assistant_controller.dart';

void main() {
  group('what gets sent', () {
    test('a short conversation goes up whole', () {
      final history = [
        const ChatMessage.user('is paracetamol safe with amlodipine?'),
        const ChatMessage.assistant('Generally yes…'),
      ];

      expect(historyToSend(history), history);
    });

    test('a long one is cut to the most recent turns', () {
      // There is no thread id, so an unbounded transcript grows the request
      // until Groq refuses it on token count and the assistant just stops.
      final history = [
        for (var i = 0; i < 40; i++) ChatMessage.user('question $i'),
      ];

      final sent = historyToSend(history);

      expect(sent, hasLength(chatHistoryLimit));
      expect(sent.last.content, 'question 39');
    });

    test('the app\'s own error bubbles are left out', () {
      // Feeding "Network error" back as though the model had said it is
      // nonsense, and it would shape the next answer.
      final sent = historyToSend([
        const ChatMessage.user('what is a normal blood pressure?'),
        const ChatMessage.assistant('Network error.', failed: true),
        const ChatMessage.user('hello?'),
      ]);

      expect(sent.map((m) => m.content), [
        'what is a normal blood pressure?',
        'hello?',
      ]);
    });

    test('the wire shape is the two keys the API reads', () {
      expect(
        const ChatMessage.user('hi').toWire(),
        {'role': 'user', 'content': 'hi'},
      );
    });
  });

  group('the conversation', () {
    test('a question and its answer both land in the transcript', () async {
      final container = _boot(_ScriptedChat(answer: 'Drink water.'));
      addTearDown(container.dispose);

      await container.read(assistantProvider.notifier).send('  hydration?  ');

      final messages = container.read(assistantProvider).messages;
      expect(messages.map((m) => m.content), ['hydration?', 'Drink water.']);
      expect(messages.every((m) => !m.failed), isTrue);
    });

    test('an empty question is not a turn', () async {
      final container = _boot(_ScriptedChat(answer: 'x'));
      addTearDown(container.dispose);

      await container.read(assistantProvider.notifier).send('   ');

      expect(container.read(assistantProvider).isEmpty, isTrue);
    });

    test('a network failure keeps the question so it can be re-sent', () async {
      final chat = _ScriptedChat(
        error: const ApiException(ApiErrorKind.network, 'No connection.'),
      );
      final container = _boot(chat);
      addTearDown(container.dispose);

      await container.read(assistantProvider.notifier).send('why?');

      final messages = container.read(assistantProvider).messages;
      expect(messages.first.content, 'why?');
      expect(messages.last.failed, isTrue);
      expect(messages.last.content, 'No connection.');
    });

    test('retry re-asks the question without duplicating it', () async {
      final chat = _ScriptedChat(
        error: const ApiException(ApiErrorKind.network, 'No connection.'),
      );
      final container = _boot(chat);
      addTearDown(container.dispose);
      await container.read(assistantProvider.notifier).send('why?');

      chat
        ..error = null
        ..answer = 'Because.';
      await container.read(assistantProvider.notifier).retryLast();

      expect(
        container.read(assistantProvider).messages.map((m) => m.content),
        ['why?', 'Because.'],
      );
    });

    test('a server with no key shuts the composer instead of failing again',
        () async {
      final container = _boot(
        _ScriptedChat(
          error: const AssistantUnavailable('No key.', permanent: true),
        ),
      );
      addTearDown(container.dispose);

      await container.read(assistantProvider.notifier).send('hello');

      final state = container.read(assistantProvider);
      expect(state.unavailable?.permanent, isTrue);
      expect(state.canSend, isFalse);
    });

    test('a bad gateway is retryable — the key is fine, Groq is not', () async {
      final container = _boot(
        _ScriptedChat(
          error: const AssistantUnavailable('Busy.', permanent: false),
        ),
      );
      addTearDown(container.dispose);

      await container.read(assistantProvider.notifier).send('hello');

      expect(container.read(assistantProvider).canSend, isTrue);
    });

    test('clearing leaves nothing behind', () async {
      final container = _boot(_ScriptedChat(answer: 'x'));
      addTearDown(container.dispose);
      await container.read(assistantProvider.notifier).send('hello');

      container.read(assistantProvider.notifier).clear();

      expect(container.read(assistantProvider).isEmpty, isTrue);
    });
  });
}

ProviderContainer _boot(ChatRepository chat) => ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(chat)],
    );

class _ScriptedChat implements ChatRepository {
  _ScriptedChat({this.answer = '', this.error});

  String answer;
  Object? error;

  /// What the last call sent, for asserting on the history cap.
  List<ChatMessage>? sent;

  @override
  Future<String> reply(List<ChatMessage> history) async {
    sent = history;
    final failure = error;
    if (failure != null) throw failure;
    return answer;
  }
}
