/// Μορφοποιεί ημερομηνία ως "31/10/2026 20:15".
String formatDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.day}/${date.month}/${date.year} ${two(date.hour)}:${two(date.minute)}';
}

/// Κλειδί ημέρας για το ημερολόγιο προόδου, π.χ. "2026-10-31".
String dayKey(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}
