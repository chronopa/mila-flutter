import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

/// Παίζει ήχο PCM 16-bit, 24 kHz, όπως τον στέλνει το Gemini.
class PcmPlayer {
  bool _ready = false;
  Future<void> _queue = Future<void>.value();

  Future<void> play(Uint8List pcm) {
    // Each Live API message contains the next piece of the same PCM stream.
    // Queue feeds in order so slower platform-channel calls cannot reorder or
    // overlap chunks (which sounds like static at the end of a response).
    final next = _queue.then((_) => _play(pcm));
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _play(Uint8List pcm) async {
    if (!_ready) {
      await FlutterPcmSound.setup(
        sampleRate: 24000,
        channelCount: 1,
        iosAudioCategory: IosAudioCategory.playAndRecord,
      );
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
      _ready = true;
    }
    await FlutterPcmSound.feed(PcmArrayInt16.fromList(_toSamples(pcm)));
  }

  /// Σταματά τον ήχο, π.χ. όταν μιλάς εσύ.
  Future<void> stop() async {
    await _queue;
    if (!_ready) return;
    _ready = false;
    await FlutterPcmSound.release();
  }

  List<int> _toSamples(Uint8List bytes) {
    final view = ByteData.sublistView(bytes);
    return List<int>.generate(
        bytes.length ~/ 2, (i) => view.getInt16(i * 2, Endian.little));
  }
}
