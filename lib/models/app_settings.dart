import 'json_helpers.dart';

class AppSettings {
  AppSettings({
    this.geminiKey = '',
    this.level = 'B2',
    this.interests = '',
    this.explain = 'el',
    this.difficulty = 'normal',
    this.liveVoice = 'Kore',
    this.hideAi = false,
    this.darkMode = false,
    this.goal = 15,
    this.focusGrammar = true,
    this.focusVocabulary = true,
    this.focusNatural = true,
  });

  String geminiKey;
  String level;
  String interests;
  String explain; // 'el' ή 'en'
  String difficulty; // 'easy', 'normal' ή 'hard'
  String liveVoice;
  bool hideAi;
  bool darkMode;
  int goal;
  bool focusGrammar;
  bool focusVocabulary;
  bool focusNatural;

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        geminiKey: pick(j['geminiKey'], ''),
        level: pick(j['level'], 'B2'),
        interests: pick(j['interests'], ''),
        explain: pick(j['explain'], 'el'),
        difficulty: pick(j['difficulty'], 'normal'),
        liveVoice: pick(j['liveVoice'], 'Kore'),
        hideAi: pick(j['hideAi'], false),
        darkMode: pick(j['darkMode'], false),
        goal: pick(j['goal'], 15),
        focusGrammar: pick(j['focusGrammar'], true),
        focusVocabulary: pick(j['focusVocabulary'], true),
        focusNatural: pick(j['focusNatural'], true),
      );

  Map<String, dynamic> toJson() => {
        'geminiKey': geminiKey,
        'level': level,
        'interests': interests,
        'explain': explain,
        'difficulty': difficulty,
        'liveVoice': liveVoice,
        'hideAi': hideAi,
        'darkMode': darkMode,
        'goal': goal,
        'focusGrammar': focusGrammar,
        'focusVocabulary': focusVocabulary,
        'focusNatural': focusNatural,
      };
}
