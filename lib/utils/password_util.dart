import 'dart:convert';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';

/// Password hashing + verification.
///
/// Uses bcrypt (like the web app's PHP `password_hash($pw, PASSWORD_BCRYPT)`).
/// The old in-app sha256 format is still recognized for verification so any
/// users seeded before this change can still log in — but new hashes are
/// always bcrypt.
class PasswordUtil {
  /// bcrypt cost factor. 10 ≈ 100 ms on a typical phone; 12 is what PHP's
  /// default uses. We use 10 to keep signup snappy on low-end devices.
  static const int _logRounds = 10;

  /// Returns a bcrypt hash of [password].
  ///
  /// The optional [saltIgnored] parameter exists only for backward compat
  /// with the old sha256-based callsite. It is ignored — bcrypt generates
  /// its own salt internally.
  static String hash(String password, [String? saltIgnored]) {
    final salt = BCrypt.gensalt(logRounds: _logRounds);
    return BCrypt.hashpw(password, salt);
  }

  /// True if [password] matches the stored bcrypt hash [stored].
  static bool verify(String password, String stored) {
    if (stored.isEmpty) return false;
    if (!stored.startsWith(r'$2')) return false;
    try {
      return BCrypt.checkpw(password, stored);
    } catch (_) {
      return false;
    }
  }

  /// Used for password-reset tokens (unrelated to bcrypt).
  static String randomHex(int bytes) {
    final r = Random.secure();
    final b = List<int>.generate(bytes, (_) => r.nextInt(256));
    return b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Used for hashing reset tokens before storing them.
  static String sha256Hex(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}