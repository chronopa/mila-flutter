import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/analysis.dart';
import '../models/app_data.dart';
import '../models/chat_message.dart';
import '../models/mistake.dart';
import '../models/vocab_item.dart';
import '../models/word_suggestion.dart';
import '../scenarios.dart';
import '../utils.dart';
import 'gemini_text.dart';
import 'live_session.dart';
import 'pcm_player.dart';
import 'prompts.dart';
import 'storage_service.dart';

enum TalkState { idle, connecting, listening, talking }

/// Η κατάσταση της εφαρμογής: δεδομένα, τρέχουσα συνομιλία και ζωντανή κλήση.
class AppState extends ChangeNotifier {
  AppState(this._storage);

  final StorageService _storage;
  final PcmPlayer _player = PcmPlayer();

  AppData data = AppData.empty();
  final List<ChatMessage> messages = [];
  TalkState talkState = TalkState.idle;
  String notice = '';
  Scenario scenario = scenarios.first;
  String customScenario = '';

  LiveSession? _live;
  ChatMessage? _userMsg; // η φράση σου που γράφεται τώρα
  ChatMessage? _aiMsg; // η απάντηση του AI που γράφεται τώρα
  bool _aiHadAudio = false;
  DateTime _lastHeard = DateTime.now();

  int get todayCount => data.daily[dayKey(DateTime.now())] ?? 0;

  /// Πόσες μέρες στη σειρά έχεις εξασκηθεί, μέχρι σήμερα.
  int get streak {
    var day = DateTime.now();
    var count = 0;
    while ((data.daily[dayKey(day)] ?? 0) > 0) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  Future<void> load() async {
    try {
      data = await _storage.load();
    } catch (error) {
      notice = 'Δεν διαβάστηκαν τα αποθηκευμένα δεδομένα: $error';
    }
    notifyListeners();
  }

  void clearNotice() {
    notice = '';
    notifyListeners();
  }

  void _setNotice(String text) {
    notice = text;
    notifyListeners();
  }

  void _save() {
    _storage.save(data).catchError((Object error) => _setNotice('Δεν αποθηκεύτηκε: $error'));
  }

  void saveSettings() {
    _save();
    notifyListeners();
  }

  // ---------- συνεδρία ----------

  Future<void> startSession({Scenario? chosen, String custom = ''}) async {
    if (data.settings.geminiKey.trim().isEmpty) {
      _setNotice('Βάλε πρώτα το κλειδί Gemini στις Ρυθμίσεις');
      return;
    }
    stopSession();
    scenario = chosen ?? scenario;
    customScenario = custom;
    messages.clear();
    talkState = TalkState.connecting;
    notice = '';
    notifyListeners();

    final live = LiveSession(
      apiKey: data.settings.geminiKey.trim(),
      voice: data.settings.liveVoice,
      systemPrompt: liveSystemPrompt(data.settings, _scenarioPrompt()),
      events: LiveEvents(
        onReady: _onReady,
        onUserText: _onUserText,
        onAiText: _onAiText,
        onAiAudio: _onAiAudio,
        onInterrupted: () => unawaited(_player.stop()),
        onTurnComplete: () => unawaited(_finishAiTurn()),
        onError: (message) => _setNotice('Σφάλμα: $message'),
        onClosed: _onClosed,
      ),
    );
    _live = live;
    try {
      await live.connect();
    } catch (error) {
      _setNotice('Δεν έγινε σύνδεση: $error');
      stopSession();
    }
  }

  /// Τελειώνει την τρέχουσα συνεδρία.
  void stopSession() {
    final live = _live;
    _live = null;
    if (live != null) unawaited(live.close());
    unawaited(_player.stop());
    _userMsg = null;
    _aiMsg = null;
    _aiHadAudio = false;
    talkState = TalkState.idle;
    notifyListeners();
  }

  String _scenarioPrompt() {
    if (scenario.id != 'custom') return scenario.prompt;
    final topic = customScenario.isEmpty ? 'free conversation' : customScenario;
    return 'ROLE-PLAY / SCENARIO defined by the learner: $topic';
  }

  void _onReady() {
    talkState = TalkState.listening;
    _live?.sendText('[START]');
    notifyListeners();
  }

  void _onClosed(String details) {
    if (_live == null) return; // έκλεισε από εμάς
    _live = null;
    talkState = TalkState.idle;
    final reason = details.isEmpty ? '' : ' ($details)';
    _setNotice('Η σύνδεση έκλεισε$reason. Πάτα το μικρόφωνο για νέα συνεδρία.');
  }

  // ---------- μιλάς ----------

  /// Το κουμπί μικροφώνου: ξεκινά να μιλάς, ή στέλνει όσα είπες.
  void toggleTalk() {
    final live = _live;
    if (live == null) {
      unawaited(startSession());
      return;
    }
    if (talkState == TalkState.connecting) return;
    if (talkState == TalkState.talking) {
      _sendTalk(live);
    } else {
      _beginTalk(live);
    }
  }

  void _beginTalk(LiveSession live) {
    unawaited(_finishAiTurn());
    unawaited(_player.stop());
    _userMsg = null;
    live.startTalking();
    talkState = TalkState.talking;
    notifyListeners();
  }

  void _sendTalk(LiveSession live) {
    live.stopTalking();
    talkState = TalkState.listening;
    _lastHeard = DateTime.now();
    notifyListeners();
    unawaited(_reviewUserMessage(_userMsg));
  }

  /// Περιμένει να ολοκληρωθεί η μεταγραφή της φράσης και μετά τη διορθώνει.
  Future<void> _reviewUserMessage(ChatMessage? msg) async {
    final started = DateTime.now();
    while (true) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final hasText = msg != null && msg.text.trim().isNotEmpty;
      final quiet = DateTime.now().difference(_lastHeard) > const Duration(milliseconds: 700);
      final timedOut = DateTime.now().difference(started) > const Duration(seconds: 4);
      if ((hasText && quiet) || timedOut) break;
    }
    if (_userMsg == msg) _userMsg = null;

    if (msg == null || msg.text.trim().isEmpty) {
      if (msg != null) {
        messages.remove(msg);
        notifyListeners();
      }
      return;
    }
    _countPhrase();
    try {
      final analysis = await _analyze(msg.text.trim());
      msg.analysis = analysis;
      if (analysis == null) {
        _setNotice('Δεν βγήκε ανάλυση, δοκίμασε ξανά.');
      } else {
        _addMistakes(analysis);
      }
    } catch (error) {
      _setNotice('Οι διορθώσεις απέτυχαν: $error');
    }
    notifyListeners();
  }

  /// Γραπτό μήνυμα μέσα στη συνεδρία.
  void sendTyped(String text) {
    final live = _live;
    final trimmed = text.trim();
    if (live == null || talkState == TalkState.connecting || trimmed.isEmpty) return;
    unawaited(_finishAiTurn());
    unawaited(_player.stop());
    final msg = ChatMessage(role: 'user', text: trimmed);
    messages.add(msg);
    live.sendText(trimmed);
    _countPhrase();
    notifyListeners();
    _analyze(trimmed).then((analysis) {
      msg.analysis = analysis;
      if (analysis != null) _addMistakes(analysis);
      notifyListeners();
    }).catchError((Object error) {
      _setNotice('Οι διορθώσεις απέτυχαν: $error');
    });
  }

  // ---------- ήχος και μεταγραφή από το Gemini ----------

  void _onUserText(String text) {
    var msg = _userMsg;
    if (msg == null) {
      msg = ChatMessage(role: 'user', text: '');
      _userMsg = msg;
      messages.add(msg);
    }
    msg.text += text;
    _lastHeard = DateTime.now();
    notifyListeners();
  }

  void _onAiText(String text) {
    var msg = _aiMsg;
    if (msg == null) {
      msg = ChatMessage(role: 'assistant', text: '');
      _aiMsg = msg;
      messages.add(msg);
    }
    msg.text += text;
    notifyListeners();
  }

  void _onAiAudio(Uint8List audio) {
    _aiHadAudio = true;
    _player.play(audio).catchError((Object error) => _setNotice('Ο ήχος δεν παίζει: $error'));
  }

  /// Κλείνει την απάντηση του AI: αν δεν ήρθε ήχος, τη διαβάζει το Gemini TTS και βρίσκει λέξεις.
  Future<void> _finishAiTurn() async {
    final msg = _aiMsg;
    final hadAudio = _aiHadAudio;
    _aiMsg = null;
    _aiHadAudio = false;
    if (msg == null || msg.text.trim().isEmpty) return;
    msg.text = msg.text.trim();
    notifyListeners();
    if (!hadAudio) unawaited(speak(msg.text));
    await _suggestWords(msg);
  }

  /// Διαβάζει ένα κείμενο με τη φωνή του Gemini.
  Future<void> speak(String text) async {
    try {
      final audio = await _gemini().speech(text, data.settings.liveVoice);
      await _player.play(audio);
    } catch (error) {
      _setNotice('Η φωνή δεν παίχτηκε: $error');
    }
  }

  Future<void> _suggestWords(ChatMessage msg) async {
    try {
      final raw = await _gemini().ask(
        system: wordsPrompt(data.settings.level),
        user: msg.text,
        maxTokens: 400,
      );
      final json = extractJson(raw);
      final list = json?['new_words'];
      if (list is! List) return;
      msg.words = list
          .whereType<Map<String, dynamic>>()
          .map(WordSuggestion.fromJson)
          .where((w) => w.phrase.isNotEmpty && w.meaning.isNotEmpty)
          .take(2)
          .toList();
      notifyListeners();
    } catch (error) {
      _setNotice('Οι λέξεις δεν βγήκαν: $error');
    }
  }

  // ---------- διορθώσεις, λάθη, λεξιλόγιο ----------

  GeminiText _gemini() => GeminiText(data.settings.geminiKey.trim());

  Future<Analysis?> _analyze(String text) async {
    final raw = await _gemini().ask(
      system: analysisPrompt(data.settings),
      user: 'Learner\'s message: "$text"',
    );
    final json = extractJson(raw);
    return json == null ? null : Analysis.fromJson(json);
  }

  void _countPhrase() {
    final key = dayKey(DateTime.now());
    data.daily[key] = (data.daily[key] ?? 0) + 1;
    _save();
  }

  void _addMistakes(Analysis analysis) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final c in analysis.corrections) {
      data.mistakes.add(Mistake(said: c.said, better: c.better, type: c.type, why: c.why, ts: now));
    }
    if (data.mistakes.length > 400) {
      data.mistakes = data.mistakes.sublist(data.mistakes.length - 400);
    }
    _save();
  }

  void addVocab(WordSuggestion word) {
    if (word.saved) return;
    word.saved = true;
    data.vocab.add(VocabItem(
      phrase: word.phrase,
      meaning: word.meaning,
      example: word.example,
      ts: DateTime.now().millisecondsSinceEpoch,
    ));
    _save();
    notifyListeners();
  }

  void deleteVocab(int index) {
    data.vocab.removeAt(index);
    _save();
    notifyListeners();
  }

  void deleteMistake(int index) {
    data.mistakes.removeAt(index);
    _save();
    notifyListeners();
  }

}
