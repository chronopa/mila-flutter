import 'json_helpers.dart';

class VocabItem {
  VocabItem({required this.phrase, required this.meaning, required this.example, required this.ts});

  final String phrase;
  final String meaning;
  final String example;
  final int ts;

  factory VocabItem.fromJson(Map<String, dynamic> j) => VocabItem(
        phrase: jsonString(j['phrase']),
        meaning: jsonString(j['meaning']),
        example: jsonString(j['example']),
        ts: pick(j['ts'], 0),
      );

  Map<String, dynamic> toJson() => {'phrase': phrase, 'meaning': meaning, 'example': example, 'ts': ts};
}
