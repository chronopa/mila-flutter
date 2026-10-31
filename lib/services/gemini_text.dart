import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

const geminiBase = 'https://generativelanguage.googleapis.com/v1beta';
const textModel = 'gemini-3.5-flash-lite';
const speechModel = 'gemini-3.8-flash-tts';

class GeminiException implements Exception {
  GeminiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Κλήσεις REST προς το Gemini: κείμενο (ανάλυση, λέξεις) και φωνή (TTS).
class GeminiText {
  GeminiText(this.apiKey);

  final String apiKey;

  /// Στέλνει ένα αίτημα κειμένου και επιστρέφει την απάντηση ως κείμενο.
  Future<String> ask({required String system, required String user, int maxTokens = 600}) async {
    final data = await _post('$geminiBase/models/$textModel:generateContent', {
      'systemInstruction': {
        'parts': [
          {'text': system}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': user}
          ]
        }
      ],
      'generationConfig': {'maxOutputTokens': maxTokens, 'responseMimeType': 'application/json'},
    });
    return _firstPart(data, (part) => part['text'] as String?) ?? '';
  }

  /// Μετατρέπει κείμενο σε ήχο PCM 16-bit, 24 kHz.
  Future<Uint8List> speech(String text, String voice) async {
    final data = await _post('$geminiBase/models/$speechModel:generateContent', {
      'contents': [
        {
          'parts': [
            {'text': text}
          ]
        }
      ],
      'generationConfig': {
        'responseModalities': ['AUDIO'],
        'speechConfig': {
          'voiceConfig': {
            'prebuiltVoiceConfig': {'voiceName': voice}
          }
        }
      },
    });
    final encoded = _firstPart(data, (part) => (part['inlineData'] as Map?)?['data'] as String?);
    if (encoded == null) throw GeminiException('Δεν ήρθε ήχος από το Gemini');
    return base64Decode(encoded);
  }

  Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 40));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final error = data['error'];
      final message = error is Map<String, dynamic> ? error['message'] : null;
      throw GeminiException(message is String ? message : 'HTTP ${response.statusCode}');
    }
    return data;
  }

  /// Βρίσκει το πρώτο τμήμα της απάντησης για το οποίο το [pick] επιστρέφει τιμή.
  String? _firstPart(Map<String, dynamic> data, String? Function(Map<String, dynamic> part) pick) {
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final content = (candidates.first as Map<String, dynamic>)['content'];
    if (content is! Map<String, dynamic>) return null;
    final parts = content['parts'];
    if (parts is! List) return null;
    for (final part in parts.whereType<Map<String, dynamic>>()) {
      final value = pick(part);
      if (value != null) return value;
    }
    return null;
  }
}

/// Βρίσκει το JSON μέσα σε κείμενο (αν το μοντέλο έβαλε κείμενο γύρω του).
Map<String, dynamic>? extractJson(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    final decoded = jsonDecode(raw.substring(start, end + 1));
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}
