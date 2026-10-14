import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../utils/password_util.dart';
import 'database_service.dart';
import 'session_service.dart';

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  /// Called on boot after `SessionService.load()`.
  Future<void> restoreSession() async {
    final id = SessionService.instance.currentUserId;
    if (id == null) return;
    final db = await DatabaseService.instance.database;
    final rows = await db.query('users', where: 'user_id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      _currentUser = AppUser.fromMap(rows.first);
      notifyListeners();
    }
  }

  // ---------- LOGIN ----------

  Future<String?> logIn(String identifier, String password) async {
    var id = identifier.trim();
    if (id.isEmpty || password.isEmpty) {
      return 'Please enter your email or username and password.';
    }
    if (id.startsWith('@')) id = id.substring(1);
    if (!id.contains('@')) id = _normalizeHandle(id);

    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'users',
      where: 'email = ? OR username = ?',
      whereArgs: [id, id],
      limit: 1,
    );
    if (rows.isEmpty) return 'Invalid credentials. Please try again.';
    final user = AppUser.fromMap(rows.first);
    if (!PasswordUtil.verify(password, user.passwordHash)) {
      return 'Invalid credentials. Please try again.';
    }

    _currentUser = user;
    await SessionService.instance.setUserId(user.userId);
    notifyListeners();
    return null;
  }

  // ---------- SIGN UP ----------

  Future<String?> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
    String? gender,
    String? genderCustom,
    String? birthdate,
  }) async {
    final db = await DatabaseService.instance.database;

    final exists = await db.query(
      'users',
      where: 'username = ? OR email = ?',
      whereArgs: [username, email],
      limit: 1,
    );
    if (exists.isNotEmpty) {
      return 'That username or email is already taken.';
    }

    // bcrypt — generates its own salt internally.
    final hash = PasswordUtil.hash(password);
    final now = DateTime.now().toIso8601String();

    final id = await db.insert('users', {
      'full_name': name.trim(),
      'username': username.trim(),
      'email': email.trim().toLowerCase(),
      'password': hash,
      'bio': '🌱 Beginner motion designer on a mission to learn Alight Motion.',
      'gender': gender,
      'gender_custom': gender == 'Others' ? genderCustom : null,
      'birthdate': birthdate,
      'role': 'user',
      'created_at': now,
    });

    final rows = await db.query('users', where: 'user_id = ?', whereArgs: [id]);
    _currentUser = AppUser.fromMap(rows.first);
    await SessionService.instance.setUserId(id);
    await SessionService.instance.setJustRegistered(true);
    notifyListeners();
    return null;
  }

  // ---------- UPDATE / REFRESH ----------

  Future<void> refreshCurrentUser() async {
    if (_currentUser == null) return;
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'users',
      where: 'user_id = ?',
      whereArgs: [_currentUser!.userId],
    );
    if (rows.isNotEmpty) {
      _currentUser = AppUser.fromMap(rows.first);
      notifyListeners();
    }
  }

  // ---------- LOGOUT ----------

  Future<void> logOut() async {
    _currentUser = null;
    await SessionService.instance.setUserId(null);
    await SessionService.instance.setJustRegistered(false);
    notifyListeners();
  }

  // ---------- HELPERS ----------

  String _normalizeHandle(String raw) {
    final s = raw.toLowerCase().trim();
    return s.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  }
}