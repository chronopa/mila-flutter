import 'package:flutter/material.dart';


import '../scenarios.dart';
import '../services/app_state.dart';
import '../widgets/correction_card.dart';
import '../widgets/message_bubble.dart';

/// Η κύρια οθόνη: η συνομιλία, το μικρόφωνο και το γραπτό πεδίο.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.state});

  final AppState state;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    if (widget.state.talkState != TalkState.listening || _input.text.trim().isEmpty) return;
    widget.state.sendTyped(_input.text);
    _input.clear();
  }

  Future<void> _chooseScenario(Scenario chosen) async {
    if (chosen.id != 'custom') {
      await widget.state.startSession(chosen: chosen);
      return;
    }
    final controller = TextEditingController();
    final topic = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Δικό σου σενάριο'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'π.χ. συνέντευξη για barista'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Άκυρο')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Ξεκίνα'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (topic == null) return;
    await widget.state.startSession(chosen: chosen, custom: topic);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final ended = state.talkState == TalkState.idle;
    return Column(
      children: [
        if (!ended) _StatusBar(state: state, onChoose: _chooseScenario),
        if (state.notice.isNotEmpty) _NoticeBar(text: state.notice, onClose: state.clearNotice),
        Expanded(
          child: ended
              ? _ScenarioHome(state: state, onChoose: _chooseScenario)
              : _MessageList(state: state),
        ),
        if (!ended)
          _InputBar(
            controller: _input,
            state: state,
            onSend: _send,
          ),
      ],
    );
  }
}

class _ScenarioHome extends StatelessWidget {
  const _ScenarioHome({required this.state, required this.onChoose});

  final AppState state;
  final Future<void> Function(Scenario) onChoose;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 24),
        Text('Τι θέλεις να εξασκήσουμε;', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Επίλεξε θέμα και η Mila θα ανοίξει τη συζήτηση με μια σχετική ερώτηση. Μετά θα σε ακούει συνεχώς και θα απαντά φυσικά στις παύσεις σου. Πάτησε «Παύση ακρόασης» για προσωρινή παύση του μικροφώνου. Για άλλο θέμα, κλείσε τη συνομιλία από το εικονίδιο εξόδου.',
        ),
        const SizedBox(height: 20),
        for (final scenario in scenarios)
          Card(
            child: ListTile(
              leading: Text(scenario.icon, style: const TextStyle(fontSize: 24)),
              title: Text(scenario.title),
              subtitle: Text(scenario.id == 'custom' ? 'Φτιάξε δικό σου θέμα' : scenario.prompt),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onChoose(scenario),
            ),
          ),
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.state, required this.onChoose});

  final AppState state;
  final Future<void> Function(Scenario) onChoose;

  @override
  Widget build(BuildContext context) {
    final goal = state.data.settings.goal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Row(
        children: [
          Chip(label: Text('🔥 ${state.streak}')),
          const SizedBox(width: 8),
          Chip(label: Text('${state.todayCount}/$goal σήμερα')),
          const Spacer(),
          PopupMenuButton<Scenario>(
            tooltip: 'Επίλεξε θέμα συνομιλίας',
            onSelected: onChoose,
            itemBuilder: (context) => [
              for (final s in scenarios)
                PopupMenuItem(value: s, child: Text('${s.icon} ${s.title}')),
            ],
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Chip(
                avatar: const Icon(Icons.theater_comedy, size: 18),
                label: Text(state.scenario.title, overflow: TextOverflow.ellipsis),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          if (state.talkState != TalkState.idle)
            IconButton(
              tooltip: 'Τέλος συνομιλίας',
              icon: const Icon(Icons.exit_to_app),
              onPressed: state.stopSession,
            ),
        ],
      ),
    );
  }
}

class _NoticeBar extends StatelessWidget {
  const _NoticeBar({required this.text, required this.onClose});

  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        dense: true,
        title: Text(text),
        trailing: IconButton(icon: const Icon(Icons.close), onPressed: onClose),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final messages = state.messages;
    if (messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Η Mila ξεκινά με ερώτηση σχετική με το θέμα. Απάντησε φυσικά· σε ακούει συνεχώς και συνεχίζει τη συζήτηση στις παύσεις σου. Πάτησε «Παύση ακρόασης» για προσωρινή παύση του μικροφώνου. Για άλλο θέμα, πάτησε το εικονίδιο εξόδου πάνω δεξιά.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final hideAi = state.data.settings.hideAi;
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        return Column(
          crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            MessageBubble(message: message, hideAi: hideAi, onSpeak: state.speak),
            if (message.analysis != null)
              CorrectionCard(analysis: message.analysis!, onSpeak: state.speak),
            if (message.words.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final word in message.words)
                      ActionChip(
                        label: Text(word.saved ? '✓ ${word.phrase}' : '＋ ${word.phrase} — ${word.meaning}'),
                        onPressed: word.saved ? null : () => state.addVocab(word),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.state, required this.onSend});

  final TextEditingController controller;
  final AppState state;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final talking = state.talkState == TalkState.talking;
    final canType = state.talkState == TalkState.listening;
    final connecting = state.talkState == TalkState.connecting;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: talking
                      ? const SizedBox(height: 48)
                      : TextField(
                          controller: controller,
                          enabled: canType,
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: canType
                                ? 'Πληκτρολόγησε μήνυμα…'
                                : 'Πληκτρολόγησε μήνυμα όταν συνδεθείς',
                            isDense: true,
                          ),
                          onSubmitted: (_) {
                            if (canType) onSend();
                          },
                        ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => IconButton.filledTonal(
                    tooltip: connecting
                        ? 'Σύνδεση…'
                        : talking
                            ? 'Παύση ακρόασης'
                            : 'Συνέχισε τη συνομιλία με το μικρόφωνο',
                    onPressed: connecting || (!talking && value.text.trim().isNotEmpty)
                        ? null
                        : state.toggleTalk,
                    style: talking
                        ? IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.errorContainer,
                            foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                          )
                        : null,
                    icon: connecting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(talking ? Icons.mic_off : Icons.mic),
                  ),
                ),
                if (!talking)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) => IconButton(
                      icon: const Icon(Icons.send),
                      tooltip: 'Αποστολή γραπτού μηνύματος',
                      onPressed: canType && value.text.trim().isNotEmpty ? onSend : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              talking
                  ? 'Το μικρόφωνο ακούει. Πάτησε το εικονίδιο μικροφώνου για προσωρινή παύση.'
                  : canType
                      ? 'Πάτησε το μικρόφωνο για να απαντήσεις και να συνεχιστεί η συζήτηση.'
                      : 'Το πεδίο μηνύματος θα είναι διαθέσιμο μόλις συνδεθείς.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
