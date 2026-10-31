import 'json_helpers.dart';

class Mistake {
  Mistake({required this.said, required this.better, required this.type, required this.why, required this.ts});

  final String said;
  final String better;
  final String type;
  final String why;
  final int ts;

  factory Mistake.fromJson(Map<String, dynamic> j) => Mistake(
        said: jsonString(j['said']),
        better: jsonString(j['better']),
        type: jsonString(j['type']),
        why: jsonString(j['why']),
        ts: pick(j['ts'], 0),
      );

  Map<String, dynamic> toJson() => {'said': said, 'better': better, 'type': type, 'why': why, 'ts': ts};
}
