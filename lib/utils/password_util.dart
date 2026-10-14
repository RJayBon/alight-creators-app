import 'dart:convert';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';

/// Password hashing + verification.
///
/// Uses bcrypt (like the web app's PHP `password_hash($pw, PASSWORD_BCRYPT)`).
/// The doc-comment in the previous version promised that "the old in-app
/// sha256 format is still recognized for verification", but `verify()` bailed
/// out on anything that didn't start with `$2` — so every legacy row was
/// permanently locked out. That path is now actually implemented, and
/// `AuthService.logIn` upgrades such rows to bcrypt on next successful login.
class PasswordUtil {
  /// bcrypt cost factor. 10 ≈ 100 ms on a typical phone; 12 is what PHP's
  /// default uses. We use 10 to keep signup snappy on low-end devices.
  static const int _logRounds = 10;

  /// Returns a bcrypt hash of [password].
  static String hash(String password) {
    final salt = BCrypt.gensalt(logRounds: _logRounds);
    return BCrypt.hashpw(password, salt);
  }

  /// True if a stored hash predates the bcrypt migration (raw sha256 hex).
  static bool isLegacySha256(String stored) {
    if (stored.length != 64) return false;
    if (stored.startsWith(r'$2')) return false;
    return RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(stored);
  }

  /// Constant-time-ish comparison for legacy sha256 rows.
  static bool verifyLegacySha256(String password, String stored) {
    if (!isLegacySha256(stored)) return false;
    final candidate = sha256Hex(password);
    if (candidate.length != stored.length) return false;
    var diff = 0;
    for (var i = 0; i < candidate.length; i++) {
      diff |= candidate.codeUnitAt(i) ^ stored.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// True if [password] matches the stored bcrypt hash [stored].
  ///
  /// Any malformed / non-bcrypt value returns false rather than throwing —
  /// `BCrypt.checkpw` throws `InvalidArgumentException` on a corrupt hash,
  /// which previously propagated out of `logIn` as a red screen.
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