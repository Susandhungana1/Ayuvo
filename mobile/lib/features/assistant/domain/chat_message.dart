/// One turn of the assistant conversation.
///
/// Not a freezed model and not a server model: `/api/chatbot` persists nothing,
/// so this shape exists only between the app and one request. The transcript
/// lives in a Riverpod provider for as long as the app is running and is never
/// written to disk — a conversation about symptoms is the most sensitive text
/// in the product, and there is no feature here that needs it to survive a
/// restart.
library;

import 'package:flutter/foundation.dart';

enum ChatRole {
  user,
  assistant;

  /// What the API calls it. `system` is added server-side and never sent.
  String get wire => name;
}

@immutable
class ChatMessage {
  const ChatMessage({required this.role, required this.content, this.failed = false});

  const ChatMessage.user(this.content)
      : role = ChatRole.user,
        failed = false;

  const ChatMessage.assistant(this.content, {this.failed = false})
      : role = ChatRole.assistant;

  final ChatRole role;
  final String content;

  /// An assistant turn that is really an error report. Rendered differently,
  /// and — importantly — left out of what gets sent back next time: feeding
  /// "Network error" to the model as though it had said it is nonsense.
  final bool failed;

  Map<String, String> toWire() => {'role': role.wire, 'content': content};

  @override
  bool operator ==(Object other) =>
      other is ChatMessage &&
      other.role == role &&
      other.content == content &&
      other.failed == failed;

  @override
  int get hashCode => Object.hash(role, content, failed);
}

/// How much history goes back to the server each turn.
///
/// The whole conversation is resent every time — there is no thread id — so an
/// unbounded transcript grows the request until Groq refuses it on token count
/// and the assistant simply stops working mid-conversation. Twelve turns is
/// enough context to follow a thread and small enough never to hit that.
const chatHistoryLimit = 12;

/// The tail of [messages] worth sending, with failed turns removed.
List<ChatMessage> historyToSend(List<ChatMessage> messages) {
  final real = [for (final message in messages) if (!message.failed) message];
  return real.length <= chatHistoryLimit
      ? real
      : real.sublist(real.length - chatHistoryLimit);
}
