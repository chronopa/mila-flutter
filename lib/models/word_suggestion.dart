import 'json_helpers.dart';

/// Λέξη ή έκφραση από την απάντηση του AI που μπορείς να αποθηκεύσεις.
class WordSuggestion {
  WordSuggestion({required this.phrase, required this.meaning, this.example = ''});

  final String phrase;
  final String meaning;
  final String example;
  bool saved = false;

  factory WordSuggestion.fromJson(Map<String, dynamic> j) => WordSuggestion(
        phrase: jsonString(j['phrase']),
        meaning: jsonString(j['el']),
        example: jsonString(j['example']),
      );
}
