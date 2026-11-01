import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/app_state.dart';

const _voices = ['Kore', 'Aoede', 'Leda', 'Zephyr', 'Puck', 'Charon', 'Fenrir'];

/// Ρυθμίσεις εφαρμογής.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final AppSettings _draft =
      AppSettings.fromJson(widget.state.data.settings.toJson());
  late final TextEditingController _key =
      TextEditingController(text: widget.state.data.settings.geminiKey);
  late final TextEditingController _interests =
      TextEditingController(text: widget.state.data.settings.interests);

  @override
  void dispose() {
    _key.dispose();
    _interests.dispose();
    super.dispose();
  }

  /// Αλλάζει μια ρύθμιση, την ξαναζωγραφίζει και τη σώζει.
  void _change(VoidCallback update) {
    setState(update);
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _save() {
    widget.state.data.settings = _draft;
    widget.state.saveSettings();
    _snack('Οι ρυθμίσεις αποθηκεύτηκαν');
  }

  @override
  Widget build(BuildContext context) {
    final s = _draft;
    return Scaffold(
      appBar: AppBar(title: const Text('Ρυθμίσεις')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Σκούρο θέμα'),
            subtitle: const Text('Ενεργοποίηση dark mode'),
            value: s.darkMode,
            onChanged: (value) => _change(() => s.darkMode = value),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _key,
            decoration: const InputDecoration(
              labelText: 'Κλειδί Gemini',
              helperText: 'Από aistudio.google.com/apikey',
            ),
            onChanged: (value) => _change(() => s.geminiKey = value.trim()),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: s.level,
            decoration: const InputDecoration(labelText: 'Επίπεδο'),
            items: const ['A2', 'B1', 'B2', 'C1']
                .map((level) => DropdownMenuItem(value: level, child: Text(level)))
                .toList(),
            onChanged: (value) {
              if (value != null) _change(() => s.level = value);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: s.liveVoice,
            decoration: const InputDecoration(labelText: 'Φωνή του AI'),
            items: _voices.map((voice) => DropdownMenuItem(value: voice, child: Text(voice))).toList(),
            onChanged: (value) {
              if (value != null) _change(() => s.liveVoice = value);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: s.explain,
            decoration: const InputDecoration(labelText: 'Εξηγήσεις διορθώσεων'),
            items: const [
              DropdownMenuItem(value: 'el', child: Text('Στα ελληνικά')),
              DropdownMenuItem(value: 'en', child: Text('Στα αγγλικά')),
            ],
            onChanged: (value) {
              if (value != null) _change(() => s.explain = value);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: s.difficulty,
            decoration: const InputDecoration(labelText: 'Δυσκολία'),
            items: const [
              DropdownMenuItem(value: 'easy', child: Text('Εύκολη')),
              DropdownMenuItem(value: 'normal', child: Text('Κανονική')),
              DropdownMenuItem(value: 'hard', child: Text('Δύσκολη')),
            ],
            onChanged: (value) {
              if (value != null) _change(() => s.difficulty = value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _interests,
            decoration: const InputDecoration(
              labelText: 'Ενδιαφέροντα',
              helperText: 'π.χ. DevOps, ταξίδια, μουσική',
            ),
            onChanged: (value) => _change(() => s.interests = value.trim()),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Κρύψε τις απαντήσεις του AI'),
            value: s.hideAi,
            onChanged: (value) => _change(() => s.hideAi = value),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Στόχος: ${s.goal} φράσεις την ημέρα'),
            subtitle: Slider(
              min: 5,
              max: 50,
              divisions: 45,
              value: s.goal.toDouble(),
              label: '${s.goal}',
              onChanged: (value) => _change(() => s.goal = value.round()),
            ),
          ),
          const Divider(),
          const Text('Τι να διορθώνει'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Γραμματική'),
            value: s.focusGrammar,
            onChanged: (value) => _change(() => s.focusGrammar = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Επιλογή λέξεων'),
            value: s.focusVocabulary,
            onChanged: (value) => _change(() => s.focusVocabulary = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Φυσική διατύπωση'),
            value: s.focusNatural,
            onChanged: (value) => _change(() => s.focusNatural = value),
          ),
          const Divider(),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Αποθήκευση'),
            ),
          ),
        ],
      ),
    );
  }
}
