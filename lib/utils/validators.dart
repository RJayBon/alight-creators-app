class Validators {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required.';
    if (!_emailRe.hasMatch(v.trim())) return 'Please enter a valid email.';
    if (v.length > 100) return 'Email is too long (max 100).';
    return null;
  }

  static String? name(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required.';
    if (v.length > 100) return 'Name is too long (max 100).';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required.';
    if (v.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  static String? handle(String? v) {
    if (v == null || v.trim().isEmpty) return 'Username is required.';
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(v)) {
      return 'Only lowercase letters, numbers, and underscores.';
    }
    return null;
  }

  /// Returns an ISO yyyy-MM-dd string if valid, or null.
  static String? birthdate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final s = value.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return null;
    try {
      final parts = s.split('-').map(int.parse).toList();
      final dt = DateTime(parts[0], parts[1], parts[2]);
      if (dt.year != parts[0] || dt.month != parts[1] || dt.day != parts[2]) {
        return null;
      }
      final now = DateTime.now();
      if (dt.isAfter(now)) return null;
      final age = now.year - dt.year -
          ((now.month < dt.month ||
                  (now.month == dt.month && now.day < dt.day))
              ? 1
              : 0);
      if (age < 13 || age > 120) return null;
      return s;
    } catch (_) {
      return null;
    }
  }
}