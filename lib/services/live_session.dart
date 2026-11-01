import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
    required this.events,
  });

  final String apiKey;
  final String voice;
  final String systemPrompt;
  final LiveEvents events;

  final AudioRecorder _recorder = AudioRecorder();
  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _micSub;
  bool _talking = false;
  bool _closed = false;

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
        // Χωρίς αυτόματη ανίχνευση: πατάς το κουμπί για να μιλήσεις και ξαναπατάς για αποστολή.
        'realtimeInputConfig': {
          'automaticActivityDetection': {'disabled': true},
        },
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt}
          ],
        },
        'inputAudioTranscription': {},
        'outputAudioTranscription': {},
      },
    });
  }

  void startTalking() {
    _talking = true;
    _send({
      'realtimeInput': {'activityStart': {}},
    });
  }

  void stopTalking() {
    _talking = false;
    _send({
      'realtimeInput': {'activityEnd': {}},
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
    try {
      if (!await _recorder.hasPermission()) {
        events.onError('Δεν έχω άδεια μικροφώνου');
        return;
      }
      final stream = await _recorder.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1),
      );
      _micSub = stream.listen(_onMic);
    } catch (error) {
      events.onError('Το μικρόφωνο δεν ξεκίνησε: $error');
    }
  }

  void _onMic(Uint8List chunk) {
    if (!_talking) return;
    _send({
      'realtimeInput': {
        'audio': {'data': base64Encode(chunk), 'mimeType': 'audio/pcm;rate=16000'},
      },
    });
  }

  Future<void> _onMessage(dynamic raw) async {
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
    if (input is Map && input['text'] is String) events.onUserText(input['text'] as String);

    final output = server['outputTranscription'];
    if (output is Map && output['text'] is String) events.onAiText(output['text'] as String);

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
