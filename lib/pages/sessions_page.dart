import 'package:flutter/material.dart';

import '../models/session_record.dart';
import '../services/app_state.dart';
import '../utils.dart';

/// Οι αποθηκευμένες συνομιλίες, με τα μηνύματά τους.
class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final sessions = state.data.sessions.reversed.toList();
    if (sessions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Καμία συνομιλία ακόμα.\nΟι συνομιλίες αποθηκεύονται καθώς μιλάς.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) => _SessionTile(
        session: sessions[index],
        isCurrent: sessions[index].id == state.sessionId,
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.isCurrent});

  final SessionRecord session;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final started = DateTime.fromMillisecondsSinceEpoch(int.tryParse(session.id) ?? 0);
    return ExpansionTile(
      title: Text(session.title),
      subtitle: Text(
        '${formatDate(started)} · ${session.messages.length} μηνύματα${isCurrent ? ' · τρέχουσα' : ''}',
      ),
      children: [
        for (final message in session.messages)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: message.isUser ? 'Εσύ: ' : 'AI: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: message.text),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
