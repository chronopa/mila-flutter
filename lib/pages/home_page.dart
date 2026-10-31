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
    return Column(
      children: [
        _StatusBar(state: state, onChoose: _chooseScenario),
        if (state.notice.isNotEmpty) _NoticeBar(text: state.notice, onClose: state.clearNotice),
        Expanded(child: _MessageList(state: state)),
        _InputBar(
          controller: _input,
          state: state,
          onSend: _send,
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
            tooltip: 'Σενάρια',
            icon: const Icon(Icons.theater_comedy),
            onSelected: onChoose,
            itemBuilder: (context) => [
              for (final s in scenarios)
                PopupMenuItem(value: s, child: Text('${s.icon} ${s.title}')),
            ],
          ),
          if (state.talkState != TalkState.idle)
            IconButton(
              tooltip: 'Τέλος συνεδρίας',
              icon: const Icon(Icons.stop_circle_outlined),
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
            'Πάτα το μικρόφωνο για να ξεκινήσεις,\nή διάλεξε σενάριο (🎭).',
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
            if (message.analysis != null) CorrectionCard(analysis: message.analysis!),
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

  String get _hint {
    switch (state.talkState) {
      case TalkState.idle:
        return 'Πάτα το μικρόφωνο για να ξεκινήσεις';
      case TalkState.connecting:
        return 'Συνδέομαι…';
      case TalkState.listening:
        return 'Πάτα το μικρόφωνο για να μιλήσεις';
      case TalkState.talking:
        return 'Μιλάς… πάτα ➤ για αποστολή';
    }
  }

  @override
  Widget build(BuildContext context) {
    final talking = state.talkState == TalkState.talking;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_hint, style: Theme.of(context).textTheme.bodySmall),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Γράψε κάτι…', isDense: true),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), tooltip: 'Στείλε', onPressed: onSend),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  iconSize: 36,
                  padding: const EdgeInsets.all(18),
                  tooltip: talking ? 'Αποστολή' : 'Μίλα',
                  icon: Icon(talking ? Icons.graphic_eq : Icons.mic),
                  onPressed: state.toggleTalk,
                ),
                if (talking) ...[
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: state.toggleTalk,
                    icon: const Icon(Icons.arrow_upward),
                    label: const Text('Αποστολή'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
