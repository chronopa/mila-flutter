import 'chat_message.dart';
import 'json_helpers.dart';

class SessionRecord {
  SessionRecord({required this.id, required this.title, required this.messages});

  final String id; // ο χρόνος έναρξης σε millis, ως κείμενο
  final String title;
  final List<ChatMessage> messages;

  factory SessionRecord.fromJson(Map<String, dynamic> j) {
    final raw = j['messages'];
    final items = raw is List ? raw : const [];
    return SessionRecord(
      id: jsonString(j['id']),
      title: jsonString(j['title']),
      messages: items.whereType<Map<String, dynamic>>().map(ChatMessage.fromJson).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
      };
}
