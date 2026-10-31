import 'package:flutter/material.dart';

import '../services/app_state.dart';

/// Οι λέξεις που έχεις αποθηκεύσει.
class VocabPage extends StatelessWidget {
  const VocabPage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final items = state.data.vocab;
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Άδειο ακόμα.\nΠάτα το ＋ κάτω από μια απάντηση του AI για να αποθηκεύσεις λέξη.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final position = items.length - 1 - index;
        final item = items[position];
        return ListTile(
          title: Text(item.phrase),
          subtitle: Text(
            [item.meaning, item.example].where((t) => t.isNotEmpty).join('\n'),
          ),
          isThreeLine: item.example.isNotEmpty,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.volume_up),
                tooltip: 'Άκουσε',
                onPressed: () => state.speak(item.phrase),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => state.deleteVocab(position),
              ),
            ],
          ),
        );
      },
    );
  }
}
