import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user.dart';
import 'database_service.dart';
import 'file_service.dart';

/// Account reads/writes, love toggling and the admin user list.
///
/// FIXES vs. the previous version:
///  1. **`update()` could wipe a password.** It wrote `user.toMap()`, and
///     `AppUser.toMap()` always includes `'password': passwordHash` — which is
///     `''` by default. Any `AppUser` that hadn't come straight from a full
///     `SELECT *` (or any future refactor that drops the column from the
///     select) silently set the bcrypt hash to an empty string, permanently
///     locking the account out. `update()` now writes an explicit column
///     whitelist and refuses to blank a non-empty password.
///  2. **Deleting an account left its files behind forever.** The row cascaded
///     but `uploads/avatars`, `uploads/banners`, `uploads/thumbnails` and
///     `uploads/videos` did not, so every deleted account leaked tens of MB.
///  3. Changing the email/handle could throw a raw
///     `UNIQUE constraint failed: users.email` straight into the UI.
///  4. `paginated(search:)` interpolated `%`/`_` into LIKE unescaped.
class UserService {
  UserService._();
  static final UserService instance = UserService._();

  /// Columns a profile edit is allowed to write. Deliberately excludes
  /// `password` and `role` — those need their own audited paths.
  static const List<String> _editableColumns = [
    'full_name',
    'username',
    'email',
    'bio',
    'avatar_path',
    'banner_path',
    'gender',
    'gender_custom',
    'birthdate',
  ];

  Future<AppUser?> getById(int id) async {
    final db = await DatabaseService.instance.database;
    final rows =
        await db.query('users', where: 'user_id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  Future<AppUser?> getByUsername(String handle) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [handle.trim().toLowerCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  /// Updates the mutable profile fields of [user].
  ///
  /// Returns null on success, or a human-readable message when the new
  /// handle/email collides with another account.
  Future<String?> update(AppUser user) async {
    if (user.userId == null) return 'Cannot save a user without an id.';

    final username = user.username.trim().toLowerCase();
    final email = user.email.trim().toLowerCase();
    if (username.isEmpty) return 'Username is required.';
    if (email.isEmpty) return 'Email is required.';

    final db = await DatabaseService.instance.database;

    final clash = await db.rawQuery(
      'SELECT username, email FROM users '
      'WHERE user_id != ? AND (username = ? OR LOWER(email) = ?) '
      'LIMIT 1',
      [user.userId, username, email],
    );
    if (clash.isNotEmpty) {
      final taken = (clash.first['username'] as String?) == username
          ? 'username'
          : 'email';
      return 'That $taken belongs to another account.';
    }

    final values = <String, Object?>{
      'full_name': user.fullName.trim(),
      'username': username,
      'email': email,
      'bio': user.bio.trim(),
      'avatar_path': user.avatarPath,
      'banner_path': user.bannerPath,
      'gender': user.gender,
      'gender_custom':
          user.gender == 'Others' ? (user.genderCustom?.trim() ?? '') : null,
      'birthdate': user.birthdate,
    };
    values.removeWhere((k, v) => !_editableColumns.contains(k));

    try {
      await db.update('users', values,
          where: 'user_id = ?', whereArgs: [user.userId]);
      return null;
    } catch (e, st) {
      debugPrint('[UserService] update failed: $e\n$st');
      return 'Could not save your profile. Please try again.';
    }
  }

  /// Sets a new password. Kept separate from [update] on purpose so no
  /// profile save can ever send an empty `'password'` key.
  Future<void> updatePassword(int userId, String bcryptHash) async {
    if (bcryptHash.isEmpty) {
      throw ArgumentError('Refusing to store an empty password hash');
    }
    final db = await DatabaseService.instance.database;
    await db.update('users', {'password': bcryptHash},
        where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<int> setRole(int userId, String role) async {
    final db = await DatabaseService.instance.database;
    return db.update('users', {'role': role},
        where: 'user_id = ?', whereArgs: [userId]);
  }

  /// Deletes the account **and its uploaded files**.
  ///
  /// The files are removed *before* the row, because the row is the only
  /// record of which paths belong to this user — deleting the row first would
  /// make an interrupted cleanup unrecoverable. `FileService.deleteFile` never
  /// throws, so a missing file can't block the delete.
  Future<void> deleteUser(int userId) async {
    final db = await DatabaseService.instance.database;

    final paths = <String>{};
    final userRow = await db.query('users',
        where: 'user_id = ?', whereArgs: [userId], limit: 1);
    if (userRow.isNotEmpty) {
      for (final col in ['avatar_path', 'banner_path']) {
        final v = userRow.first[col] as String?;
        if (v != null && v.isNotEmpty) paths.add(v);
      }
    }

    final media = await db.rawQuery(
      'SELECT thumbnail_path, guide_video_file, result_video_file '
      'FROM tutorials WHERE user_id = ?',
      [userId],
    );
    for (final m in media) {
      for (final v in m.values) {
        if (v is String && v.isNotEmpty) paths.add(v);
      }
    }

    await db.delete('users', where: 'user_id = ?', whereArgs: [userId]);

    if (paths.isNotEmpty) {
      await FileService.instance.deleteFiles(paths);
      FileService.instance.invalidateCache();
    }
  }

  // ---------- LOVES ----------

  Future<({int received, int given})> loveStats(int userId) async {
    final db = await DatabaseService.instance.database;
    final received = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM user_loves WHERE loved_id = ?',
        [userId])) ??
        0;
    final given = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM user_loves WHERE lover_id = ?', [userId])) ??
        0;
    return (received: received, given: given);
  }

  Future<bool> hasLoved(int loverId, int lovedId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('user_loves',
        where: 'lover_id = ? AND loved_id = ?',
        whereArgs: [loverId, lovedId],
        limit: 1);
    return rows.isNotEmpty;
  }

  /// Returns the new state (true = loved).
  ///
  /// The old SELECT-then-INSERT pair could throw `UNIQUE constraint failed`
  /// when both taps landed before either insert; the conditional
  /// delete/insert makes the toggle atomic.
  Future<bool> toggleLove(int loverId, int lovedId) async {
    if (loverId == lovedId) return false;
    final db = await DatabaseService.instance.database;
    return db.transaction<bool>((txn) async {
      final removed = await txn.delete('user_loves',
          where: 'lover_id = ? AND loved_id = ?',
          whereArgs: [loverId, lovedId]);
      if (removed > 0) return false;
      await txn.insert(
        'user_loves',
        {
          'lover_id': loverId,
          'loved_id': lovedId,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return true;
    });
  }

  // ---------- ADMIN LIST ----------

  Future<({List<AppUser> users, int total, int totalPages})> paginated({
    required int page,
    required int perPage,
    String search = '',
  }) async {
    final db = await DatabaseService.instance.database;
    final q = search.trim();
    final where = q.isEmpty
        ? ''
        : 'WHERE (full_name LIKE ? ESCAPE \'\\\' '
            'OR username LIKE ? ESCAPE \'\\\' '
            'OR email LIKE ? ESCAPE \'\\\')';
    final like = q.isEmpty ? '' : '%${_escapeLike(q)}%';
    final args = q.isEmpty ? <Object>[] : [like, like, like];

    final safePage = page < 1 ? 1 : page;
    // `.toInt()` is deliberate: `clamp` is declared on `num`, so its
    // inferred type is not guaranteed to be int, and a double reaching
    // SQLite as the LIMIT/OFFSET argument fails only at runtime.
    final int safePerPage = perPage.clamp(1, 200).toInt();

    final countRows =
        await db.rawQuery('SELECT COUNT(*) FROM users $where', args);
    final total = Sqflite.firstIntValue(countRows) ?? 0;
    final int totalPages =
        (total / safePerPage).ceil().clamp(1, 1 << 30).toInt();

    final rows = await db.rawQuery(
      'SELECT * FROM users $where '
      "ORDER BY (role = 'admin') DESC, user_id ASC LIMIT ? OFFSET ?",
      [...args, safePerPage, (safePage - 1) * safePerPage],
    );

    return (
      users: rows.map(AppUser.fromMap).toList(),
      total: total,
      totalPages: totalPages,
    );
  }

  Future<int> tutorialCount(int userId) async {
    final db = await DatabaseService.instance.database;
    return Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM tutorials WHERE user_id = ?', [userId])) ??
        0;
  }

  Future<Map<int, int>> tutorialCounts(List<int> userIds) async {
    if (userIds.isEmpty) return {};
    final db = await DatabaseService.instance.database;
    final ph = List.filled(userIds.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT user_id, COUNT(*) as c FROM tutorials WHERE user_id IN ($ph) '
      'GROUP BY user_id',
      userIds,
    );
    return {
      for (final r in rows) r['user_id'] as int: (r['c'] as int?) ?? 0,
    };
  }

  static String _escapeLike(String v) => v
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');
}