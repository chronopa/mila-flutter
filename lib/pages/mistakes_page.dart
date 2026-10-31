import 'package:flutter/material.dart';

import '../services/app_state.dart';

/// Λίστα με τα λάθη που έχεις κάνει, το πιο πρόσφατο πρώτο.
class MistakesPage extends StatelessWidget {
  const MistakesPage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final mistakes = state.data.mistakes;
    if (mistakes.isEmpty) {
      return const Center(child: Text('Ακόμα κανένα λάθος καταγεγραμμένο.'));
    }
    return ListView.separated(
      itemCount: mistakes.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final position = mistakes.length - 1 - index;
        final mistake = mistakes[position];
        return ListTile(
          title: Text('${mistake.said} → ${mistake.better}'),
          subtitle: mistake.why.isEmpty ? null : Text(mistake.why),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => state.deleteMistake(position),
          ),
        );
      },
    );
  }
}
