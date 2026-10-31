import 'analysis.dart';
import 'json_helpers.dart';
import 'word_suggestion.dart';

class ChatMessage {
  ChatMessage({required this.role, required this.text});

  final String role; // 'user' ή 'assistant'
  String text;
  Analysis? analysis;
  List<WordSuggestion> words = [];

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {'role': role, 'text': text};

  factory ChatMessage.fromJson(Map<String, dynamic> j) =>
      ChatMessage(role: jsonString(j['role']), text: jsonString(j['text']));
}
