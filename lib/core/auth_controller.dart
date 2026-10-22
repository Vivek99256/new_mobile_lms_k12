import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'config.dart';
import 'session.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Login, persistence and the same session rules lms_k12 enforces: a session
/// ends after 30 minutes of inactivity and at the turn of the day.
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

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> restore() async {
    try {
      final raw = await _storage.read(key: _kSession);
      final date = await _storage.read(key: _kSessionDate);
      final last = int.tryParse(await _storage.read(key: _kLastActive) ?? '');
      final idle = last == null
          ? false
          : DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) >
              AppConfig.inactivityTimeout;

      if (raw != null && date == _today() && !idle) {
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
      session = s;
      status = AuthStatus.signedIn;
      await _storage.write(key: _kSession, value: jsonEncode(s.toJson()));
      await _storage.write(key: _kSessionDate, value: _today());
      await touch();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
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
      // Re-applies the idle and new-day rules after the app was in the background.
      restore();
    } else if (state == AppLifecycleState.paused) {
      touch();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
