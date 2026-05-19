// lib/services/auth_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'api_service.dart';

class AuthService {
  static const _keyToken    = 'auth_token';
  static const _keyUserId   = 'user_id';
  static const _keyUsername = 'username';
  static const _keyEmail    = 'user_email';
  static const _keyRole     = 'user_role';

  final ApiService _api;
  AuthUser? _currentUser;

  void Function()? onSessionExpired;

  AuthService(this._api);

  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final token    = prefs.getString(_keyToken);
    final id       = prefs.getString(_keyUserId);
    final username = prefs.getString(_keyUsername);
    final email    = prefs.getString(_keyEmail);
    final role     = prefs.getString(_keyRole);

    if (token != null && token.isNotEmpty && id != null &&
        username != null && email != null && role != null) {
      _currentUser = AuthUser(
        id: id, username: username, email: email, role: role, token: token,
      );
      _api.setToken(token);
    } else {
      await _clearPrefs(prefs);
    }
  }

  Future<AuthUser> login(String email, String password) async {
    final user = await _api.login(email, password);
    await _persist(user);
    _currentUser = user;
    return user;
  }

  Future<AuthUser> register(String username, String email, String password) async {
    final user = await _api.register(username, email, password);
    await _persist(user);
    _currentUser = user;
    return user;
  }

  Future<void> logout() async {
    _currentUser = null;
    _api.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await _clearPrefs(prefs);
  }

  Future<void> handleUnauthorized() async {
    await logout();
    onSessionExpired?.call();
  }

  Future<AuthUser> updateProfile(String username, String email) async {
    final updated = await _api.updateProfile(username, email);
    _currentUser = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, updated.username);
    await prefs.setString(_keyEmail, updated.email);
    return updated;
  }

  Future<void> changePassword(String currentPassword, String newPassword) =>
      _api.changePassword(currentPassword, newPassword);

  Future<void> deleteAccount() async {
    await _api.deleteAccount();
    await logout();
  }

  Future<void> _clearPrefs(SharedPreferences prefs) async {
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyRole);
  }

  Future<void> _persist(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken,    user.token);
    await prefs.setString(_keyUserId,   user.id);
    await prefs.setString(_keyUsername, user.username);
    await prefs.setString(_keyEmail,    user.email);
    await prefs.setString(_keyRole,     user.role);
  }
}
