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

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        if (analysis != null) 'analysis': analysis!.toJson(),
        'words': words.map((word) => word.toJson()).toList(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final message =
        ChatMessage(role: jsonString(j['role']), text: jsonString(j['text']));
    final rawAnalysis = j['analysis'];
    if (rawAnalysis is Map<String, dynamic>) {
      message.analysis = Analysis.fromJson(rawAnalysis);
    }
    final rawWords = j['words'];
    if (rawWords is List) {
      message.words = rawWords
          .whereType<Map<String, dynamic>>()
          .map(WordSuggestion.fromJson)
          .toList();
    }
    return message;
  }
}
