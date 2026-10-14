import 'package:sqflite/sqflite.dart';

import '../models/contact_message.dart';
import 'database_service.dart';

class ContactService {
  ContactService._();
  static final ContactService instance = ContactService._();

  Future<void> insert({
    required String name,
    required String email,
    required String message,
  }) async {
    final db = await DatabaseService.instance.database;
    await db.insert('contact_messages', {
      'name': name,
      'email': email,
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<ContactMessage>> list() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('contact_messages', orderBy: 'created_at DESC');
    return rows.map(ContactMessage.fromMap).toList();
  }

  Future<void> delete(int messageId) async {
    final db = await DatabaseService.instance.database;
    await db.delete('contact_messages',
        where: 'message_id = ?', whereArgs: [messageId]);
  }

  Future<void> clearAll() async {
    final db = await DatabaseService.instance.database;
    await db.delete('contact_messages');
  }

  Future<({int total, int today, int lastWeek})> stats() async {
    final db = await DatabaseService.instance.database;
    final total = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM contact_messages')) ?? 0;

    final todayStart = DateTime.now();
    final todayStr = DateTime(todayStart.year, todayStart.month, todayStart.day)
        .toIso8601String();
    final today = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM contact_messages WHERE created_at >= ?',
        [todayStr])) ?? 0;

    final weekStart =
        DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final lastWeek = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM contact_messages WHERE created_at >= ?',
        [weekStart])) ?? 0;

    return (total: total, today: today, lastWeek: lastWeek);
  }
}