import 'package:flutter/foundation.dart';

import '../utils/password_util.dart';
import 'database_service.dart';

/// Password-reset tokens.
///
/// FIXES vs. the previous version:
///  1. `createTokenForEmail` matched with `email = ?` while callers pass the
///     raw user input — so `Me@Example.com` (or any row imported from the web
///     app with different casing) found no account. Matching is now
///     case-insensitive on both sides.
///  2. `consume()` generated a `randomHex(16)` "salt" and passed it to
///     `PasswordUtil.hash`, whose salt argument is ignored because bcrypt
///     derives its own salt from the stored hash. The dead salt made the code
///     look like it was doing something security-relevant when it wasn't.
///  3. `consume()` now returns whether the token was actually still unused,
///     so a double-tap can't silently reset the password twice, and the whole
///     call is exception-safe.
class PasswordResetService {
  PasswordResetService._();
  static final PasswordResetService instance = PasswordResetService._();

  static const Duration tokenLifetime = Duration(minutes: 15);

  /// Returns the plaintext token, or null if the email isn't registered.
  Future<String?> createTokenForEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    try {
      final db = await DatabaseService.instance.database;
      final users = await db.query(
        'users',
        where: 'LOWER(email) = ?',
        whereArgs: [normalized],
        limit: 1,
      );
      if (users.isEmpty) return null;

      final userId = users.first['user_id'] as int;

      // Invalidate prior unused tokens.
      await db.delete('password_resets',
          where: 'user_id = ? AND used_at IS NULL', whereArgs: [userId]);

      final token = PasswordUtil.randomHex(32); // 64 chars
      final hash = PasswordUtil.sha256Hex(token);
      final expires =
          DateTime.now().add(tokenLifetime).toIso8601String();

      await db.insert('password_resets', {
        'user_id': userId,
        'token_hash': hash,
        'expires_at': expires,
        'used_at': null,
        'created_at': DateTime.now().toIso8601String(),
      });

      return token;
    } catch (e, st) {
      debugPrint('createTokenForEmail failed: $e\n$st');
      return null;
    }
  }

  /// Returns {resetId, userId} if the token is valid, else null.
  Future<({int resetId, int userId})?> findValid(String token) async {
    if (token.length != 64) return null;
    final hash = PasswordUtil.sha256Hex(token);
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.query(
        'password_resets',
        where: 'token_hash = ? AND used_at IS NULL',
        whereArgs: [hash],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final r = rows.first;
      final exp = DateTime.tryParse(r['expires_at'] as String? ?? '');
      if (exp == null || exp.isBefore(DateTime.now())) return null;
      return (resetId: r['reset_id'] as int, userId: r['user_id'] as int);
    } catch (e, st) {
      debugPrint('findValid failed: $e\n$st');
      return null;
    }
  }

  /// True if the password was changed and the token consumed.
  Future<bool> consume({
    required int resetId,
    required int userId,
    required String newPassword,
  }) async {
    if ((newPassword).length < 6) return false;
    try {
      final db = await DatabaseService.instance.database;
      return await db.transaction((txn) async {
        // Compare-and-swap on used_at: exactly one caller can win the token.
        final claimed = await txn.update(
          'password_resets',
          {'used_at': DateTime.now().toIso8601String()},
          where: 'reset_id = ? AND used_at IS NULL',
          whereArgs: [resetId],
        );
        if (claimed == 0) return false;

        await txn.update(
          'users',
          // bcrypt generates and embeds its own salt — nothing else to pass.
          {'password': PasswordUtil.hash(newPassword)},
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        return true;
      });
    } catch (e, st) {
      debugPrint('reset consume failed: $e\n$st');
      return false;
    }
  }

  /// Housekeeping: expired/used tokens accumulate forever otherwise. Safe to
  /// call on every app start; it is a single indexed-ish DELETE on a small
  /// table.
  Future<void> pruneExpired() async {
    try {
      final db = await DatabaseService.instance.database;
      final cutoff =
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
      await db.delete(
        'password_resets',
        where: 'used_at IS NOT NULL OR expires_at < ?',
        whereArgs: [cutoff],
      );
    } catch (e) {
      debugPrint('pruneExpired failed: $e');
    }
  }
}