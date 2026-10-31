import 'package:flutter/material.dart';

import '../models/analysis.dart';

/// Οι διορθώσεις της φράσης σου, κάτω από τη φυσαλίδα σου.
class CorrectionCard extends StatelessWidget {
  const CorrectionCard({super.key, required this.analysis});

  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (analysis.corrections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text(
          '✓ Ακούστηκε σωστά και φυσικά',
          style: TextStyle(color: Colors.green.shade700),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in analysis.corrections)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${c.type}  ', style: theme.textTheme.labelSmall),
                          TextSpan(
                            text: c.said,
                            style: const TextStyle(decoration: TextDecoration.lineThrough),
                          ),
                          const TextSpan(text: ' → '),
                          TextSpan(
                            text: c.better,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    if (c.why.isNotEmpty) Text(c.why, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            if (analysis.natural.isNotEmpty)
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Φυσικά: '),
                    TextSpan(
                      text: analysis.natural,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
