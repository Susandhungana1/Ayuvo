/// `POST /api/chatbot`.
///
/// Auth required, nothing persisted, and the whole history goes up each turn.
/// Two failures are worth telling apart from a generic error, because the
/// answer to them is different: a 500 means this server has no `GROQ_API_KEY`
/// and no amount of retrying will help, while a 502 means Groq itself refused
/// and trying again in a moment might.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../domain/chat_message.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);

/// Distinguishes "this deployment has no key" from "the model is having a bad
/// day", so the screen can stop offering Retry for the one that cannot succeed.
class AssistantUnavailable implements Exception {
  const AssistantUnavailable(this.message, {required this.permanent});

  final String message;

  /// True when retrying is pointless — an operator has to set a key.
  final bool permanent;

  @override
  String toString() => 'AssistantUnavailable($message)';
}

class ChatRepository {
  const ChatRepository(this._client);

  final ApiClient _client;

  Future<String> reply(List<ChatMessage> history) async {
    try {
      final json = await _client.post<Map<String, dynamic>>(
        '/api/chatbot',
        body: {
          'messages': [for (final message in history) message.toWire()],
        },
      );
      final reply = json['reply'];
      // A 200 with no reply would render as an empty bubble, which reads as
      // the assistant ignoring the question.
      if (reply is! String || reply.trim().isEmpty) {
        throw const AssistantUnavailable(
          'The assistant answered with nothing at all. Try asking again.',
          permanent: false,
        );
      }
      return reply.trim();
    } on ApiException catch (error) {
      // `detail` here is written by us, in chatbot.py — never model output and
      // never anything out of the database, so it is safe to show.
      if (error.statusCode == 500 &&
          (error.detail?.contains('Groq API key') ?? false)) {
        throw const AssistantUnavailable(
          'This server has no AI key configured, so the assistant cannot '
          'answer. Everything else in the app works.',
          permanent: true,
        );
      }
      if (error.statusCode == 502) {
        throw const AssistantUnavailable(
          'The AI service refused that one. Try again in a moment.',
          permanent: false,
        );
      }
      rethrow;
    }
  }
}
