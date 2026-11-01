import 'app_settings.dart';
import 'mistake.dart';
import 'vocab_item.dart';

/// Όλα τα δεδομένα της εφαρμογής, όπως αποθηκεύονται.
class AppData {
  AppData({
    required this.settings,
    required this.mistakes,
    required this.vocab,
    required this.daily,
  });

  AppSettings settings;
  List<Mistake> mistakes;
  List<VocabItem> vocab;
  Map<String, int> daily; // ημέρα -> πόσες φράσεις είπες

  factory AppData.empty() => AppData(
        settings: AppSettings(),
        mistakes: [],
        vocab: [],
        daily: {},
      );

  factory AppData.fromJson(Map<String, dynamic> j) {
    List<T> readList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
      final raw = j[key];
      if (raw is! List) return [];
      return raw.whereType<Map<String, dynamic>>().map(fromJson).toList();
    }

    final settingsJson = j['settings'];
    final daily = <String, int>{};
    final dailyJson = j['daily'];
    if (dailyJson is Map) {
      dailyJson.forEach((key, value) {
        if (value is int) daily['$key'] = value;
      });
    }
    return AppData(
      settings: settingsJson is Map<String, dynamic> ? AppSettings.fromJson(settingsJson) : AppSettings(),
      mistakes: readList('mistakes', Mistake.fromJson),
      vocab: readList('vocab', VocabItem.fromJson),
      daily: daily,
    );
  }

  Map<String, dynamic> toJson() => {
        'settings': settings.toJson(),
        'mistakes': mistakes.map((m) => m.toJson()).toList(),
        'vocab': vocab.map((v) => v.toJson()).toList(),
        'daily': daily,
      };
}
