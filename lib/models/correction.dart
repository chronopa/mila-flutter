import 'json_helpers.dart';

class Correction {
  Correction({required this.said, required this.better, this.type = '', this.why = ''});

  final String said;
  final String better;
  final String type;
  final String why;

  factory Correction.fromJson(Map<String, dynamic> j) => Correction(
        said: jsonString(j['said']),
        better: jsonString(j['better']),
        type: jsonString(j['type']),
        why: jsonString(j['why']),
      );

  Map<String, dynamic> toJson() => {'said': said, 'better': better, 'type': type, 'why': why};
}
