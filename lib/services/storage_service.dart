import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_data.dart';
import '../models/chat_message.dart';

/// Αποθηκεύει όλα τα δεδομένα της εφαρμογής ως ένα JSON κείμενο.
class StorageService {
  static const _key = 'mila.v1';
  static const _conversationKey = 'mila.lastConversation.v1';

  Future<AppData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return AppData.empty();
    return AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(AppData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toJson()));
  }

  Future<Map<String, dynamic>?> loadConversation() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_conversationKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<void> saveConversation({
    required String scenarioId,
    required String customScenario,
    required List<ChatMessage> messages,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _conversationKey,
      jsonEncode({
        'scenarioId': scenarioId,
        'customScenario': customScenario,
        'messages': messages.map((message) => message.toJson()).toList(),
      }),
    );
  }

  Future<void> clearConversation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_conversationKey);
  }
}
