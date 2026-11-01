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
            'Άδειο ακόμα.\nΠάτα το ＋ κάτω από μια απάντηση του AI για να αποθηκεύσεις αγγλική λέξη, ελληνική μετάφραση και παράδειγμα.',
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
        // Older AI suggestions may have returned the English and Greek fields
        // in reverse order. Detect Greek script and display those entries correctly.
        final swapped = _containsGreek(item.phrase) && !_containsGreek(item.meaning);
        final englishPhrase = swapped ? item.meaning : item.phrase;
        final greekMeaning = swapped ? item.phrase : item.meaning;
        return ListTile(
          title: Text(englishPhrase),
          subtitle: Text(
            [
              if (greekMeaning.isNotEmpty) 'Μετάφραση: $greekMeaning',
              if (item.example.isNotEmpty) 'Παράδειγμα: ${item.example}',
            ].join('\n'),
          ),
          isThreeLine: item.example.isNotEmpty,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.volume_up),
                tooltip: 'Άκουσε την αγγλική λέξη ή φράση',
                onPressed: () => state.speak(englishPhrase),
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

bool _containsGreek(String text) => RegExp(r'[\u0370-\u03FF\u1F00-\u1FFF]').hasMatch(text);
