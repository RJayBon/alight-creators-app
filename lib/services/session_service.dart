import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const _kUserId = 'session_user_id';
  static const _kJustRegistered = 'session_just_registered';

  SharedPreferences? _prefs;
  int? currentUserId;
  bool justRegistered = false;

  String? _pendingFlash;
  bool _pendingFlashIsError = false;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    currentUserId = _prefs!.getInt(_kUserId);
    justRegistered = _prefs!.getBool(_kJustRegistered) ?? false;
  }

  Future<void> setUserId(int? id) async {
    currentUserId = id;
    _prefs ??= await SharedPreferences.getInstance();
    if (id == null) {
      await _prefs!.remove(_kUserId);
    } else {
      await _prefs!.setInt(_kUserId, id);
    }
  }

  Future<void> setJustRegistered(bool v) async {
    justRegistered = v;
    _prefs ??= await SharedPreferences.getInstance();
    if (v) {
      await _prefs!.setBool(_kJustRegistered, true);
    } else {
      await _prefs!.remove(_kJustRegistered);
    }
  }

  void setFlash(String message, {bool isError = false}) {
    _pendingFlash = message;
    _pendingFlashIsError = isError;
  }

  /// Returns `(message, isError)` when a flash is pending, otherwise null.
  (String, bool)? consumeFlash() {
    final message = _pendingFlash;
    if (message == null) return null;
    final err = _pendingFlashIsError;
    _pendingFlash = null;
    _pendingFlashIsError = false;
    return (message, err);
  }

  /// Clears only the keys this service owns. Other app preferences
  /// (settings, feature flags, etc.) are left untouched.
  Future<void> clear() async {
    currentUserId = null;
    justRegistered = false;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_kUserId);
    await _prefs!.remove(_kJustRegistered);
  }
}