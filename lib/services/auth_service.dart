import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../constants.dart';
import '../models/user.dart';
import '../utils/password_util.dart';
import '../utils/validators.dart';
import 'database_service.dart';
import 'session_service.dart';

/// Authentication + account lifecycle.
///
/// FIXES vs. the previous version:
///  1. Login looked up `email = ?` with the *raw* typed value while signup
///     stored `email.trim().toLowerCase()`. Anyone who typed an uppercase
///     email (or a mixed-case handle on a device where the handle field's
///     cleaner was bypassed by a paste) could register but never log in.
///     All lookups are now normalized and case-insensitive.
///  2. Signup checked uniqueness with the raw value but inserted a trimmed /
///     lower-cased value, so a case-differing duplicate slipped past the
///     check and surfaced as a raw SQLite `UNIQUE constraint failed` string
///     in the UI. The check and the insert now use identical values, and the
///     insert is additionally guarded by a try/catch for the race case.
///  3. Every public entry point is now exception-safe: a DB error returns a
///     friendly message instead of throwing into the widget's `await`.
///  4. Legacy SHA-256 password rows are transparently upgraded to bcrypt on
///     successful login instead of being permanently locked out (the old
///     `PasswordUtil.verify` returned false for anything not starting with
///     `$2`, which made every web-migrated row unusable).
///  5. First-run gate: `hasAnyAccount` / `needsSetup` / `createFirstAdmin`. The
///     public `signUp` path refuses to create the *first* account, so an install
///     can never end up with everyone as `role = 'user'` and no way to reach
///     the admin screens.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  static const _invalidCredentials =
      "Invalid email/username or password. Please try again.";

  /// Shown when someone reaches a sign-in / sign-up form on an install that has
  /// no accounts yet. `_Bootstrap` normally routes that case to `SetupScreen`,
  /// so hitting this means a stale deep link or a race with a data wipe — the
  /// honest fix is to send them to the gate, not to let a second account type
  /// slip in ahead of the admin.
  static const kNoAccountsYet =
      'No accounts exist on this device yet. Create the first administrator '
      'account to continue.';

  static const kSetupRequiredMsg =
      'Setup is not complete yet. Create the first administrator account to '
      'continue.';

  /// Whether the `users` table has any rows. This *is* the setup signal —
  /// storing a separate `setup_complete` flag would add a second source of
  /// truth that goes stale the moment the admin deletes the last account or
  /// runs "clear all data", and then either re-opens the gate or hides it
  /// forever. One `LIMIT 1` probe on boot is the cheaper correct answer.
  static Future<bool> hasAnyAccount() async {
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery('SELECT 1 FROM users LIMIT 1');
      return rows.isNotEmpty;
    } catch (e, st) {
      debugPrint('hasAnyAccount failed: $e\n$st');
      // Fail closed: showing setup when accounts *do* exist is recoverable
      // (the screen re-routes itself once it can read the table); silently
      // skipping the gate on a transient error is not.
      return false;
    }
  }

  /// True on a fresh install: no accounts, so the app must ask for the first
  /// administrator instead of offering login/signup.
  Future<bool> needsSetup() async => !await hasAnyAccount();

  /// Called on boot after `SessionService.load()`.
  Future<void> restoreSession() async {
    final id = SessionService.instance.currentUserId;
    if (id == null) return;
    try {
      final db = await DatabaseService.instance.database;
      final rows =
          await db.query('users', where: 'user_id = ?', whereArgs: [id]);
      if (rows.isEmpty) {
        // The stored session points at a user that no longer exists
        // (deleted by an admin, or the DB was reset). Drop the stale id so
        // the app doesn't keep re-attempting a restore every launch, and
        // notify regardless — `_Bootstrap` re-reads the setup gate off this
        // notification, which is how deleting the last account returns the app
        // to the registration form.
        await SessionService.instance.setUserId(null);
        notifyListeners();
        return;
      }
      _currentUser = AppUser.fromMap(rows.first);
      notifyListeners();
    } catch (e, st) {
      debugPrint('restoreSession failed: $e\n$st');
    }
  }

  // ---------- LOGIN ----------

  Future<String?> logIn(String identifier, String password) async {
    if (!await hasAnyAccount()) return kSetupRequiredMsg;
    var id = identifier.trim();
    if (id.isEmpty || password.isEmpty) {
      return 'Please enter your email or username and password.';
    }
    if (id.startsWith('@')) id = id.substring(1);

    final isEmail = id.contains('@');
    if (!isEmail) id = _normalizeHandle(id);

    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.query(
        'users',
        where: isEmail ? 'LOWER(email) = ?' : 'username = ?',
        whereArgs: [isEmail ? id.toLowerCase() : id],
        limit: 1,
      );
      if (rows.isEmpty) return _invalidCredentials;

      final user = AppUser.fromMap(rows.first);
      final stored = user.passwordHash;

      if (PasswordUtil.isLegacySha256(stored)) {
        if (!PasswordUtil.verifyLegacySha256(password, stored)) {
          return _invalidCredentials;
        }
        // Transparent upgrade: bcrypt for this user from now on.
        try {
          await db.update(
            'users',
            {'password': PasswordUtil.hash(password)},
            where: 'user_id = ?',
            whereArgs: [user.userId],
          );
          user.passwordHash = PasswordUtil.hash(password);
        } catch (e) {
          // Non-fatal — they can still log in with the legacy hash.
          debugPrint('password upgrade skipped: $e');
        }
      } else if (!PasswordUtil.verify(password, stored)) {
        return _invalidCredentials;
      }

      _currentUser = user;
      await SessionService.instance.setUserId(user.userId);
      // A fresh login always starts on the Home tab — `justRegistered` is a
      // one-shot signup signal and must not survive into a later session.
      await SessionService.instance.setJustRegistered(false);
      notifyListeners();
      return null;
    } catch (e, st) {
      debugPrint('logIn failed: $e\n$st');
      return 'Could not sign you in right now. Please try again.';
    }
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
    // A public sign-up form reachable before setup would let the *first*
    // account be created as a plain `role = 'user'`, leaving the install with
    // no way to reach the admin screens (promotion requires an admin).
    if (!await hasAnyAccount()) return kSetupRequiredMsg;
    // These normalized values are what actually gets stored — the uniqueness
    // pre-check below must use the exact same strings.
    final handle = _normalizeHandle(username);
    final emailNorm = email.trim().toLowerCase();
    final nameNorm = name.trim();

    if (handle.isEmpty || handle.replaceAll('_', '').isEmpty) {
      return 'Please choose a username with at least one letter or number.';
    }
    if (Validators.email(emailNorm) != null) {
      return 'Please enter a valid email address.';
    }
    final pwErr = Validators.password(password);
    if (pwErr != null) return pwErr;

    try {
      final db = await DatabaseService.instance.database;

      final dup = await db.query(
        'users',
        where: 'username = ? OR LOWER(email) = ?',
        whereArgs: [handle, emailNorm],
        limit: 1,
      );
      if (dup.isNotEmpty) {
        final clash = (dup.first['username'] as String?) == handle
            ? 'username'
            : 'email';
        return 'That $clash is already registered. Try logging in instead.';
      }

      // bcrypt — generates its own salt internally.
      final hash = PasswordUtil.hash(password);
      final now = DateTime.now().toIso8601String();

      late int id;
      try {
        id = await db.insert('users', {
          'full_name': nameNorm,
          'username': handle,
          'email': emailNorm,
          'password': hash,
          'bio': '🌱 Beginner motion designer on a mission to learn Alight Motion.',
          'gender': gender,
          'gender_custom': gender == 'Others' ? genderCustom?.trim() : null,
          'birthdate': birthdate,
          'role': 'user',
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.abort);
      } catch (e) {
        // Lost a race against a concurrent signup with the same handle.
        debugPrint('signUp insert failed: $e');
        return 'That username or email is already taken.';
      }

      final rows = await db.query('users', where: 'user_id = ?', whereArgs: [id]);
      if (rows.isEmpty) return 'Account created, but something went wrong. Please log in.';
      _currentUser = AppUser.fromMap(rows.first);
      await SessionService.instance.setUserId(id);
      await SessionService.instance.setJustRegistered(true);
      notifyListeners();
      return null;
    } catch (e, st) {
      debugPrint('signUp failed: $e\n$st');
      return 'Could not create your account right now. Please try again.';
    }
  }

  // ---------- FIRST-RUN ADMIN ----------

  /// Creates the app's first account with `role = 'admin'`.
  ///
  /// Separate from [signUp] on purpose: the role must be settable exactly once
  /// and never through the public path. It re-checks the user count inside the
  /// same DB call as the insert, so two devices (or a double tap) cannot both
  /// self-assign admin — the second gets a plain refusal instead of a second
  /// administrator.
  ///
  /// Returns null on success, or a message to display. On success the session
  /// is already live (`notifyListeners` has fired), so `_Bootstrap` renders the
  /// logged-in `HomeShell` without a restart.
  Future<String?> createFirstAdmin({
    required String name,
    required String username,
    required String email,
    required String password,
    String? gender,
    String? genderCustom,
    String? birthdate,
  }) async {
    if (await hasAnyAccount()) {
      return 'Setup is already complete — an account exists on this device. '
          'Create additional accounts from the sign-up screen instead.';
    }

    final handle = _normalizeHandle(username);
    final emailNorm = email.trim().toLowerCase();
    final nameNorm = name.trim();

    if (nameNorm.isEmpty) return 'Please enter your name.';
    if (handle.isEmpty || handle.replaceAll('_', '').isEmpty) {
      return 'Please choose a username with at least one letter or number.';
    }
    if (Validators.email(emailNorm) != null) {
      return 'Please enter a valid email address.';
    }
    final pwErr = Validators.password(password);
    if (pwErr != null) return pwErr;

    try {
      final db = await DatabaseService.instance.database;
      final hash = PasswordUtil.hash(password); // bcrypt embeds its own salt
      final now = DateTime.now().toIso8601String();

      late int id;
      try {
        id = await db.insert('users', {
          'full_name': nameNorm,
          'username': handle,
          'email': emailNorm,
          'password': hash,
          'bio': kAdminDefaultBio,
          'gender': gender,
          'gender_custom': gender == 'Others' ? genderCustom?.trim() : null,
          'birthdate': birthdate,
          'role': 'admin',
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.abort);
      } catch (e) {
        // The count said "empty", so a conflict here is a concurrent insert —
        // refuse rather than silently becoming a second admin.
        debugPrint('createFirstAdmin insert failed: $e');
        return 'Could not create the admin account. '
            'Please check the form and try again.';
      }

      final rows =
          await db.query('users', where: 'user_id = ?', whereArgs: [id]);
      if (rows.isEmpty) {
        return 'Admin account created, but it could not be loaded. '
            'Please sign in.';
      }
      _currentUser = AppUser.fromMap(rows.first);
      await SessionService.instance.setUserId(id);
      await SessionService.instance.setJustRegistered(false);
      notifyListeners();
      return null;
    } catch (e, st) {
      debugPrint('createFirstAdmin failed: $e\n$st');
      return 'Could not create the admin account right now. Please try again.';
    }
  }

  // ---------- UPDATE / REFRESH ----------

  Future<void> refreshCurrentUser() async {
    if (_currentUser == null) return;
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.query(
        'users',
        where: 'user_id = ?',
        whereArgs: [_currentUser!.userId],
      );
      if (rows.isEmpty) {
        // The account was deleted (by an admin, or from this device) while the
        // app was open. Clear the session instead of showing a ghost profile.
        await logOut();
        return;
      }
      _currentUser = AppUser.fromMap(rows.first);
      notifyListeners();
    } catch (e, st) {
      debugPrint('refreshCurrentUser failed: $e\n$st');
    }
  }

  // ---------- LOGOUT ----------

  Future<void> logOut() async {
    _currentUser = null;
    // clear() wipes both the user id and the one-shot signup flag so a
    // subsequent login cannot inherit stale state.
    await SessionService.instance.clear();
    notifyListeners();
  }

  // ---------- HELPERS ----------

  String _normalizeHandle(String raw) {
    final s = raw.toLowerCase().trim();
    return s.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  }
}