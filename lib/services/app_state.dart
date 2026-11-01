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
  bool _startTalkingWhenReady = false;
  final Map<ChatMessage, Timer> _userTurnTimers = {};
  Timer? _conversationSaveTimer;
  Map<String, dynamic>? _savedConversation;
  bool _resumeConversation = false;

  bool get hasSavedConversation => _savedConversation != null;
  String get savedScenarioTitle {
    final id = _savedConversation?['scenarioId'];
    for (final item in scenarios) {
      if (item.id == id) return item.title;
    }
    return 'Προηγούμενη συζήτηση';
  }

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
      _savedConversation = await _storage.loadConversation();
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
    _storage
        .save(data)
        .catchError((Object error) => _setNotice('Δεν αποθηκεύτηκε: $error'));
  }

  void _scheduleConversationSave() {
    if (talkState == TalkState.idle && _live == null) return;
    _conversationSaveTimer?.cancel();
    _conversationSaveTimer =
        Timer(const Duration(milliseconds: 350), _saveConversationNow);
  }

  void _saveConversationNow() {
    _conversationSaveTimer?.cancel();
    final scenarioId = scenario.id;
    final custom = customScenario;
    final transcript = messages.map((message) => message.toJson()).toList();
    final snapshot = <String, dynamic>{
      'scenarioId': scenarioId,
      'customScenario': custom,
      'messages': transcript,
    };
    _savedConversation = snapshot;
    unawaited(_storage.saveConversation(
      scenarioId: scenarioId,
      customScenario: custom,
      messages: messages,
    ));
  }

  void saveSettings() {
    _save();
    notifyListeners();
  }

  // ---------- συνεδρία ----------

  Future<void> startSession({
    Scenario? chosen,
    String custom = '',
    bool startTalkingWhenReady = false,
    bool resumeSavedConversation = false,
  }) async {
    if (data.settings.geminiKey.trim().isEmpty) {
      _setNotice('Βάλε πρώτα το κλειδί Gemini στις Ρυθμίσεις');
      return;
    }
    final saved = resumeSavedConversation ? _savedConversation : null;
    stopSession(preserveConversation: resumeSavedConversation);
    _startTalkingWhenReady = startTalkingWhenReady;
    if (resumeSavedConversation && saved != null) {
      final savedScenarioId = saved['scenarioId'];
      final matchingScenarios =
          scenarios.where((item) => item.id == savedScenarioId);
      scenario =
          matchingScenarios.isEmpty ? scenarios.first : matchingScenarios.first;
      customScenario = saved['customScenario'] is String
          ? saved['customScenario'] as String
          : '';
      final savedMessages = saved['messages'];
      messages
        ..clear()
        ..addAll(savedMessages is List
            ? savedMessages
                .whereType<Map<String, dynamic>>()
                .map(ChatMessage.fromJson)
            : const <ChatMessage>[]);
      _resumeConversation = true;
    } else {
      scenario = chosen ?? scenario;
      customScenario = custom;
      messages.clear();
      _resumeConversation = false;
      _savedConversation = null;
      unawaited(_storage.clearConversation());
    }
    talkState = TalkState.connecting;
    notice = '';
    notifyListeners();
    _scheduleConversationSave();

    final live = LiveSession(
      apiKey: data.settings.geminiKey.trim(),
      voice: data.settings.liveVoice,
      systemPrompt: liveSystemPrompt(data.settings, _scenarioPrompt()),
      restoreHistory: resumeSavedConversation,
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
      stopSession(preserveConversation: resumeSavedConversation);
    }
  }

  Future<void> resumeLastConversation() async {
    if (_savedConversation == null) return;
    await startSession(resumeSavedConversation: true);
  }

  /// Τελειώνει την τρέχουσα συνεδρία.
  void stopSession({bool preserveConversation = false}) {
    _startTalkingWhenReady = false;
    _conversationSaveTimer?.cancel();
    if (preserveConversation) {
      if (_live != null || _savedConversation != null || messages.isNotEmpty) {
        _saveConversationNow();
      }
    } else {
      _savedConversation = null;
      unawaited(_storage.clearConversation());
    }
    final live = _live;
    _live = null;
    if (live != null) unawaited(live.close());
    unawaited(_player.stop());
    _userMsg = null;
    _aiMsg = null;
    _aiHadAudio = false;
    for (final timer in _userTurnTimers.values) {
      timer.cancel();
    }
    _userTurnTimers.clear();
    messages.clear();
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
    notifyListeners();
    if (_resumeConversation) {
      _live?.sendHistory(messages);
      _live?.sendText(
          'Continue our conversation naturally from where we left off. Ask one short follow-up question.');
      _resumeConversation = false;
    } else {
      _live?.sendText(
        'Start the conversation now. Briefly welcome the learner into this scenario, then ask exactly one short, natural opening question directly related to it: ${_scenarioPrompt()}',
      );
    }
    if (_startTalkingWhenReady && _live != null) {
      _startTalkingWhenReady = false;
      _beginTalk(_live!);
    }
  }

  void _onClosed(String details) {
    if (_live == null) return; // έκλεισε από εμάς
    _live = null;
    talkState = TalkState.idle;
    final reason = details.isEmpty ? '' : ' ($details)';
    _saveConversationNow();
    _setNotice(
        'Η σύνδεση έκλεισε$reason. Μπορείς να συνεχίσεις την τελευταία συζήτηση.');
  }

  // ---------- μιλάς ----------

  /// Το κουμπί μικροφώνου: ξεκινά να μιλάς, ή στέλνει όσα είπες.
  void toggleTalk() {
    final live = _live;
    if (live == null) {
      unawaited(startSession(startTalkingWhenReady: true));
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
    for (final timer in _userTurnTimers.values) {
      timer.cancel();
    }
    _userTurnTimers.clear();
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
    notifyListeners();
    // Finalize any phrase that has not already ended during a natural pause.
    final msg = _userMsg;
    if (msg != null) _finalizeUserTurn(msg);
  }

  void _scheduleUserTurn(ChatMessage msg) {
    _userTurnTimers.remove(msg)?.cancel();
    // inputTranscription arrives at the end of a detected speech segment.
    // Keep the message open briefly in case the learner continues speaking.
    _userTurnTimers[msg] = Timer(const Duration(milliseconds: 900), () {
      _finalizeUserTurn(msg);
    });
  }

  void _finalizeUserTurn(ChatMessage msg) {
    _userTurnTimers.remove(msg)?.cancel();
    if (_userMsg == msg) _userMsg = null;
    final text = msg.text.trim();
    if (text.isEmpty) {
      messages.remove(msg);
      notifyListeners();
      return;
    }
    if (msg.analysis != null) return;
    _countPhrase();
    _analyze(text).then((analysis) {
      msg.analysis = analysis;
      _addMistakes(analysis);
      _scheduleConversationSave();
      notifyListeners();
    }).catchError((Object error) {
      _setNotice('Οι διορθώσεις απέτυχαν: $error');
    });
  }

  /// Γραπτό μήνυμα μέσα στη συνεδρία.
  void sendTyped(String text) {
    final live = _live;
    final trimmed = text.trim();
    if (live == null || talkState == TalkState.connecting || trimmed.isEmpty) {
      return;
    }
    unawaited(_finishAiTurn());
    unawaited(_player.stop());
    final msg = ChatMessage(role: 'user', text: trimmed);
    messages.add(msg);
    live.sendText(trimmed);
    _countPhrase();
    _scheduleConversationSave();
    notifyListeners();
    _analyze(trimmed).then((analysis) {
      msg.analysis = analysis;
      _addMistakes(analysis);
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
    _scheduleUserTurn(msg);
    _scheduleConversationSave();
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
    _scheduleConversationSave();
    notifyListeners();
  }

  void _onAiAudio(Uint8List audio) {
    _aiHadAudio = true;
    _player
        .play(audio)
        .catchError((Object error) => _setNotice('Ο ήχος δεν παίζει: $error'));
  }

  /// Κλείνει την απάντηση του AI: αν δεν ήρθε ήχος, τη διαβάζει το Gemini TTS και βρίσκει λέξεις.
  Future<void> _finishAiTurn() async {
    final msg = _aiMsg;
    final hadAudio = _aiHadAudio;
    _aiMsg = null;
    _aiHadAudio = false;
    if (msg == null || msg.text.trim().isEmpty) return;
    msg.text = msg.text.trim();
    _scheduleConversationSave();
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
      _scheduleConversationSave();
      notifyListeners();
    } catch (error) {
      _setNotice('Οι λέξεις δεν βγήκαν: $error');
    }
  }

  // ---------- διορθώσεις, λάθη, λεξιλόγιο ----------

  GeminiText _gemini() => GeminiText(data.settings.geminiKey.trim());

  Future<Analysis> _analyze(String text) async {
    final raw = await _gemini().ask(
      system: analysisPrompt(data.settings),
      user: 'Learner\'s message: "$text"',
      responseSchema: {
        'type': 'object',
        'properties': {
          'corrections': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'said': {'type': 'string'},
                'better': {'type': 'string'},
                'type': {'type': 'string'},
                'why': {'type': 'string'},
              },
              'required': ['said', 'better', 'type', 'why'],
            },
          },
          'natural_version': {'type': 'string'},
        },
        'required': ['corrections', 'natural_version'],
      },
    );
    final json = extractJson(raw);
    if (json == null) {
      throw GeminiException(
          'Η απάντηση της ανάλυσης δεν ήταν έγκυρη. Δοκίμασε ξανά.');
    }
    return Analysis.fromJson(json);
  }

  void _countPhrase() {
    final key = dayKey(DateTime.now());
    data.daily[key] = (data.daily[key] ?? 0) + 1;
    _save();
  }

  void _addMistakes(Analysis analysis) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final c in analysis.corrections) {
      data.mistakes.add(Mistake(
          said: c.said, better: c.better, type: c.type, why: c.why, ts: now));
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
    _scheduleConversationSave();
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
