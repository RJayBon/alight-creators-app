import 'package:sqflite/sqflite.dart';

import '../models/user.dart';
import 'database_service.dart';

class UserService {
  UserService._();
  static final UserService instance = UserService._();

  Future<AppUser?> getById(int id) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('users', where: 'user_id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  Future<AppUser?> getByUsername(String handle) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [handle.toLowerCase()],
    );
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  Future<void> update(AppUser user) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      'users',
      user.toMap()..remove('user_id'),
      where: 'user_id = ?',
      whereArgs: [user.userId],
    );
  }

  Future<void> deleteUser(int userId) async {
    final db = await DatabaseService.instance.database;
    await db.delete('users', where: 'user_id = ?', whereArgs: [userId]);
  }

  // ---------- LOVES ----------

  Future<({int received, int given})> loveStats(int userId) async {
    final db = await DatabaseService.instance.database;
    final received = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM user_loves WHERE loved_id = ?', [userId])) ?? 0;
    final given = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM user_loves WHERE lover_id = ?', [userId])) ?? 0;
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

  Future<bool> toggleLove(int loverId, int lovedId) async {
    if (loverId == lovedId) return false;
    final db = await DatabaseService.instance.database;
    final existing = await db.query('user_loves',
        where: 'lover_id = ? AND loved_id = ?',
        whereArgs: [loverId, lovedId],
        limit: 1);
    if (existing.isNotEmpty) {
      await db.delete('user_loves',
          where: 'lover_id = ? AND loved_id = ?', whereArgs: [loverId, lovedId]);
      return false;
    }
    await db.insert('user_loves', {
      'lover_id': loverId,
      'loved_id': lovedId,
      'created_at': DateTime.now().toIso8601String(),
    });
    return true;
  }

  // ---------- ADMIN LIST ----------

  Future<({List<AppUser> users, int total, int totalPages})> paginated({
    required int page,
    required int perPage,
    String search = '',
  }) async {
    final db = await DatabaseService.instance.database;
    final where = search.isEmpty
        ? ''
        : 'WHERE (full_name LIKE ? OR username LIKE ? OR email LIKE ?)';
    final like = '%$search%';
    final args = search.isEmpty ? <Object>[] : [like, like, like];

    final countRows =
        await db.rawQuery('SELECT COUNT(*) FROM users $where', args);
    final total = Sqflite.firstIntValue(countRows) ?? 0;
    final totalPages = (total / perPage).ceil().clamp(1, 1 << 30);

    final rows = await db.rawQuery(
      'SELECT * FROM users $where '
      "ORDER BY (role = 'admin') DESC, user_id ASC LIMIT ? OFFSET ?",
      [...args, perPage, (page - 1) * perPage],
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
        'SELECT COUNT(*) FROM tutorials WHERE user_id = ?', [userId])) ?? 0;
  }

  Future<Map<int, int>> tutorialCounts(List<int> userIds) async {
    if (userIds.isEmpty) return {};
    final db = await DatabaseService.instance.database;
    final ph = List.filled(userIds.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT user_id, COUNT(*) as c FROM tutorials WHERE user_id IN ($ph) GROUP BY user_id',
      userIds,
    );
    return {
      for (final r in rows) r['user_id'] as int: (r['c'] as int?) ?? 0,
    };
  }
}