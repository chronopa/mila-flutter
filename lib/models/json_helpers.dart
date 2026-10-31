/// Επιστρέφει την τιμή αν έχει τον σωστό τύπο, αλλιώς το fallback.
T pick<T>(dynamic value, T fallback) => value is T ? value : fallback;

String jsonString(dynamic value) => value is String ? value : '';
