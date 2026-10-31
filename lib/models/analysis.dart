import 'correction.dart';
import 'json_helpers.dart';

/// Η ανάλυση της φράσης σου: έως 3 διορθώσεις και η φυσική εκδοχή.
class Analysis {
  Analysis({required this.corrections, required this.natural});

  final List<Correction> corrections;
  final String natural;

  factory Analysis.fromJson(Map<String, dynamic> j) {
    final raw = j['corrections'];
    final items = raw is List ? raw : const [];
    final corrections = items
        .whereType<Map<String, dynamic>>()
        .map(Correction.fromJson)
        .where((c) => c.said.isNotEmpty && c.better.isNotEmpty)
        .take(3)
        .toList();
    return Analysis(corrections: corrections, natural: jsonString(j['natural_version']).trim());
  }
}
