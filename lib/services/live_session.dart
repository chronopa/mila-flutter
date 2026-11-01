import 'dart:async';
import 'dart:convert';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/chat_message.dart';

const liveModel = 'models/gemini-3.8-live';
const liveUrl =
    'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';

/// Τα γεγονότα που στέλνει η σύνδεση προς την εφαρμογή.
class LiveEvents {
  const LiveEvents({
    required this.onReady,
    required this.onUserText,
    required this.onAiText,
    required this.onAiAudio,
    required this.onInterrupted,
    required this.onTurnComplete,
    required this.onError,
    required this.onClosed,
  });

  final void Function() onReady;
  final void Function(String text) onUserText;
  final void Function(String text) onAiText;
  final void Function(Uint8List audio) onAiAudio;
  final void Function() onInterrupted;
  final void Function() onTurnComplete;
  final void Function(String message) onError;
  final void Function(String details) onClosed;
}

/// Ζωντανή σύνδεση με το Gemini Live: στέλνει τον ήχο του μικροφώνου και παίρνει πίσω φωνή και μεταγραφές.
class LiveSession {
  LiveSession({
    required this.apiKey,
    required this.voice,
    required this.systemPrompt,
    this.restoreHistory = false,
    required this.events,
  });

  final String apiKey;
  final String voice;
  final String systemPrompt;
  final bool restoreHistory;
  final LiveEvents events;

  final AudioRecorder _recorder = AudioRecorder();
  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _micSub;
  bool _talking = false;
  bool _closed = false;
  bool _micStarted = false;

  Future<void> connect() async {
    final channel = WebSocketChannel.connect(
      Uri.parse('$liveUrl?key=${Uri.encodeQueryComponent(apiKey)}'),
    );
    _channel = channel;
    await channel.ready;
    channel.stream.listen(
      _onMessage,
      onError: (Object error) => events.onError('$error'),
      onDone: () {
        if (!_closed) {
          final code = channel.closeCode;
          final reason = channel.closeReason?.trim();
          final details = [
            if (code != null) 'κωδικός $code',
            if (reason != null && reason.isNotEmpty) reason,
          ].join(' — ');
          events.onClosed(details);
        }
      },
    );
    _send({
      'setup': {
        'model': liveModel,
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': voice},
            },
          },
        },
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt}
          ],
        },
        'inputAudioTranscription': {},
        'outputAudioTranscription': {},
        if (restoreHistory)
          'historyConfig': {'initialHistoryInClientContent': true},
        // Keep the mic stream open; let the Live API detect individual speech
        // turns during natural pauses instead of batching the whole recording.
        'realtimeInputConfig': {
          'automaticActivityDetection': {
            'disabled': false,
            'silenceDurationMs': 600,
          },
        },
      },
    });
  }

  void startTalking() {
    if (_closed) return;
    _talking = true;
  }

  void stopTalking() {
    _talking = false;
    _send({
      'realtimeInput': {'audioStreamEnd': true},
    });
  }

  /// Στέλνει γραπτό μήνυμα ως σειρά του χρήστη.
  void sendText(String text) {
    _send({
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {'text': text}
            ],
          },
        ],
        'turnComplete': true,
      },
    });
  }

  /// Restores transcript context without asking the model to answer yet.
  void sendHistory(List<ChatMessage> messages) {
    if (messages.isEmpty) return;
    _send({
      'clientContent': {
        'turns': [
          for (final message in messages)
            if (message.text.trim().isNotEmpty)
              {
                'role': message.role == 'assistant' ? 'model' : 'user',
                'parts': [
                  {'text': message.text.trim()}
                ],
              }
        ],
        'turnComplete': false,
      },
    });
  }

  Future<void> close() async {
    _closed = true;
    _talking = false;
    await _micSub?.cancel();
    try {
      await _recorder.stop();
      await _recorder.dispose();
    } catch (_) {
      // Ο ηχογράφος μπορεί να μην έχει ξεκινήσει ακόμα.
    }
    await _channel?.sink.close();
  }

  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  Future<void> _startMic() async {
    if (_micStarted || _closed) return;
    try {
      if (!await _recorder.hasPermission()) {
        events.onError(
            'Δεν υπάρχει άδεια μικροφώνου. Ενεργοποίησέ την από Ρυθμίσεις iPhone > Απόρρητο και ασφάλεια > Μικρόφωνο και ξεκίνα ξανά τη συνομιλία.');
        return;
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final audioSession = await AudioSession.instance;
        await audioSession.configure(
          AudioSessionConfiguration(
            avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
            avAudioSessionCategoryOptions:
                AVAudioSessionCategoryOptions.defaultToSpeaker |
                    AVAudioSessionCategoryOptions.allowBluetooth,
            avAudioSessionMode: AVAudioSessionMode.voiceChat,
          ),
        );
        await audioSession.setActive(true);
      }
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          iosConfig: IosRecordConfig(
            categoryOptions: [
              IosAudioCategoryOption.defaultToSpeaker,
              IosAudioCategoryOption.allowBluetooth,
            ],
          ),
        ),
      );
      _micStarted = true;
      _micSub = stream.listen(
        _onMic,
        onError: (Object error) =>
            events.onError('Το μικρόφωνο παρουσίασε σφάλμα: $error'),
        onDone: () {
          if (!_closed && _micStarted) {
            events.onError(
                'Η ροή του μικροφώνου σταμάτησε. Κλείσε και ξαναξεκίνα τη συνομιλία.');
          }
        },
      );
    } catch (error) {
      events.onError('Το μικρόφωνο δεν ξεκίνησε: $error');
    }
  }

  void _onMic(Uint8List chunk) {
    if (!_talking || _closed) return;
    _send({
      'realtimeInput': {
        'audio': {
          'data': base64Encode(chunk),
          'mimeType': 'audio/pcm;rate=16000'
        },
      },
    });
  }

  Future<void> _onMessage(dynamic raw) async {
    if (_closed) return;
    final text = raw is String ? raw : utf8.decode(raw as List<int>);
    final message = jsonDecode(text) as Map<String, dynamic>;

    if (message.containsKey('setupComplete')) {
      await _startMic();
      events.onReady();
      return;
    }
    final error = message['error'];
    if (error is Map) {
      events.onError('${error['message'] ?? 'άγνωστο σφάλμα'}');
      return;
    }
    final server = message['serverContent'];
    if (server is! Map) return;

    if (server['interrupted'] == true) events.onInterrupted();

    final input = server['inputTranscription'];
    if (input is Map && input['text'] is String) {
      events.onUserText(input['text'] as String);
    }

    final output = server['outputTranscription'];
    if (output is Map && output['text'] is String) {
      events.onAiText(output['text'] as String);
    }

    final turn = server['modelTurn'];
    if (turn is Map && turn['parts'] is List) {
      for (final part in turn['parts'] as List) {
        if (part is! Map) continue;
        final inline = part['inlineData'];
        if (inline is Map && inline['data'] is String) {
          events.onAiAudio(base64Decode(inline['data'] as String));
        }
      }
    }

    if (server['turnComplete'] == true) events.onTurnComplete();
  }
}
