import '../utils/password_util.dart';
import 'database_service.dart';

class PasswordResetService {
  PasswordResetService._();
  static final PasswordResetService instance = PasswordResetService._();

  /// Returns the plaintext token, or null if the email isn't registered.
  Future<String?> createTokenForEmail(String email) async {
    final db = await DatabaseService.instance.database;
    final users = await db.query('users',
        where: 'email = ?', whereArgs: [email.toLowerCase()], limit: 1);
    if (users.isEmpty) return null;

    final userId = users.first['user_id'] as int;

    // Invalidate prior unused tokens.
    await db.delete('password_resets',
        where: 'user_id = ? AND used_at IS NULL', whereArgs: [userId]);

    final token = PasswordUtil.randomHex(32); // 64 chars
    final hash = PasswordUtil.sha256Hex(token);
    final expires =
        DateTime.now().add(const Duration(minutes: 15)).toIso8601String();

    await db.insert('password_resets', {
      'user_id': userId,
      'token_hash': hash,
      'expires_at': expires,
      'used_at': null,
      'created_at': DateTime.now().toIso8601String(),
    });

    return token;
  }

  /// Returns {resetId, userId} if the token is valid, else null.
  Future<({int resetId, int userId})?> findValid(String token) async {
    if (token.length != 64) return null;
    final hash = PasswordUtil.sha256Hex(token);
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
  }

  Future<void> consume({
    required int resetId,
    required int userId,
    required String newPassword,
  }) async {
    final db = await DatabaseService.instance.database;
    await db.transaction((txn) async {
      final salt = PasswordUtil.randomHex(16);
      final hash = PasswordUtil.hash(newPassword, salt);
      await txn.update('users', {'password': hash},
          where: 'user_id = ?', whereArgs: [userId]);
      await txn.update('password_resets',
          {'used_at': DateTime.now().toIso8601String()},
          where: 'reset_id = ? AND used_at IS NULL',
          whereArgs: [resetId]);
    });
  }
}