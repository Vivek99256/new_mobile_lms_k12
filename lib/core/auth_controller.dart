import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'config.dart';
import 'session.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Login and persistence. A sign-in stays until the user logs out or the server's token expires
/// (no idle timeout and no end-of-day logout on the phone).
class AuthController extends ChangeNotifier with WidgetsBindingObserver {
  AuthController(this._api, {FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage() {
    WidgetsBinding.instance.addObserver(this);
  }

  final ApiClient _api;
  final FlutterSecureStorage _storage;

  static const _kSession = 'session';
  static const _kSessionDate = 'sessionDate';
  static const _kLastActive = 'lastActive';

  AuthStatus status = AuthStatus.unknown;
  Session? session;

  ApiClient get api => _api;

  Future<void> restore() async {
    try {
      final raw = await _storage.read(key: _kSession);
      if (raw != null) {
        final s = Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (s.token.isNotEmpty && s.userId > 0) {
          session = s;
          status = AuthStatus.signedIn;
          await touch();
          notifyListeners();
          return;
        }
      }
    } catch (_) {
      // Unreadable storage is treated as signed out.
    }
    await _clear();
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  /// Returns null on success, otherwise a message fit to show the user.
  Future<String?> login(String email, String password) async {
    try {
      final res = await _api.post('/api/api-login', body: {
        'email': email.trim(),
        'password': password,
        'type': 'API',
      });
      final s = Session.fromLogin(res, email.trim(), AppConfig.apiBase);
      if (s.token.isEmpty || s.userId == 0) {
        return (res['message'] ?? 'Your email or password is incorrect. Check them and try again.')
            .toString();
      }
      await _establish(s);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Opens one profile (a staff account or a student) on a number that was just proven with an mPIN or
  /// biometrics. The server returns the same session api-login does. Returns an error message or null.
  Future<String?> signInWithProfile(String ticket, String profileKey) async {
    try {
      final res = await _api.post('/api/mobile-auth/select', body: {'ticket': ticket, 'profile': profileKey});
      final s = Session.fromLogin(res, '', AppConfig.apiBase);
      if (s.token.isEmpty || s.userId == 0) {
        return (res['message'] ?? 'Could not open this profile. Try again.').toString();
      }
      await _establish(s);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Opens another profile on the same number (a sibling, or the parent's staff account). Moving up to a staff
  /// profile needs the mPIN or the biometric device token. Returns an error message or null.
  Future<String?> switchProfile({required String mobile, required String profileKey, String? pin, String? deviceToken}) async {
    final current = session;
    if (current == null) return 'Sign in again.';
    try {
      final res = await _api.post(
        '/api/mobile-auth/switch',
        body: {'mobile': mobile, 'profile': profileKey, 'pin': ?pin, 'device_token': ?deviceToken},
        token: current.token,
      );
      final s = Session.fromLogin(res, '', AppConfig.apiBase);
      if (s.token.isEmpty || s.userId == 0) return (res['message'] ?? 'Could not open this profile.').toString();
      await _establish(s);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Views another academic year: the year goes with every call from now on, until the app is closed.
  ///
  /// It is deliberately NOT saved. The saved session keeps the school's current year, so closing the app and opening
  /// it again always comes back to the latest year, and a past year never stays selected by accident.
  void setAcademicYear(String year) {
    final s = session;
    if (s == null || s.mobileSyear == year) return;
    session = s.copyWith(mobileSyear: year);
    notifyListeners();
  }

  Future<void> _establish(Session s) async {
    session = s;
    status = AuthStatus.signedIn;
    await _storage.write(key: _kSession, value: jsonEncode(s.toJson()));
    await _storage.write(key: _kSessionDate, value: DateTime.now().toIso8601String().substring(0, 10));
    await touch();
    notifyListeners();
  }

  /// POST /forget-password (a root route, not under /api). Returns an error or null.
  Future<String?> sendPasswordReset(String email) async {
    try {
      final res = await _api.post('/forget-password', body: {'user_email': email.trim()});
      if (res['success'] == false) {
        return (res['message'] ?? 'We could not send a reset link. Try again.').toString();
      }
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> touch() =>
      _storage.write(key: _kLastActive, value: '${DateTime.now().millisecondsSinceEpoch}');

  Future<void> logout() async {
    await _clear();
    session = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> _clear() async {
    for (final k in [_kSession, _kSessionDate, _kLastActive]) {
      try {
        await _storage.delete(key: k);
      } catch (_) {}
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (status != AuthStatus.signedIn) return;
    if (state == AppLifecycleState.resumed) {
      touch();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
