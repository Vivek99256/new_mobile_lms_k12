import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'api_client.dart';

/// One person a mobile number can open: a staff account or a student (a parent signs in as the child).
class MobileProfile {
  const MobileProfile({
    required this.key,
    required this.type,
    required this.name,
    required this.subtitle,
    required this.school,
    this.current = false,
    this.needsAuth = false,
  });

  /// `staff:<id>` or `student:<id>`; what the server's select call takes.
  final String key;
  final String type;
  final String name;
  final String subtitle;
  final String school;

  /// Set when switching from a signed-in profile: this is the one in use now.
  final bool current;

  /// Opening this profile asks for the mPIN or biometrics again (a child's profile moving up to a staff one).
  final bool needsAuth;

  bool get isStudent => type == 'student';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  factory MobileProfile.fromJson(Map<String, dynamic> j) => MobileProfile(
        key: '${j['key'] ?? ''}',
        type: '${j['type'] ?? ''}',
        name: '${j['name'] ?? ''}'.trim(),
        subtitle: '${j['subtitle'] ?? ''}'.trim(),
        school: '${j['school'] ?? ''}'.trim(),
        current: j['current'] == true,
        needsAuth: j['needs_auth'] == true,
      );
}

/// A proven mobile number: a short-lived ticket and the profiles on that number.
class MobileSignIn {
  const MobileSignIn({required this.ticket, required this.profiles});
  final String ticket;
  final List<MobileProfile> profiles;
}

/// What kind of biometric this phone offers, for the words on screen.
enum BiometricKind { face, fingerprint, generic }

extension BiometricKindText on BiometricKind {
  /// "Face ID" on an iPhone that has it; otherwise the fingerprint wording.
  String get label => switch (this) {
        BiometricKind.face => 'Face ID',
        BiometricKind.fingerprint => 'Fingerprint',
        BiometricKind.generic => 'Biometrics',
      };
}

/// Calls api/mobile-auth/* and keeps the per-phone bits: the last number used and the biometric device
/// token. The mPIN itself is never stored on the phone; only the server holds (a hash of) it.
class MobileAuthService {
  MobileAuthService(this._api, {FlutterSecureStorage? storage, LocalAuthentication? localAuth})
      : _storage = storage ?? const FlutterSecureStorage(),
        _local = localAuth ?? LocalAuthentication();

  final ApiClient _api;
  final FlutterSecureStorage _storage;
  final LocalAuthentication _local;

  static const pinLength = 4;
  static const _kLastMobile = 'mauth_last_mobile';
  static String _kDevice(String mobile) => 'mauth_device_$mobile';
  static String _kDeclined(String mobile) => 'mauth_bio_declined_$mobile';

  // ------------------------------------------------------------------ server

  Map<String, dynamic> _data(Map<String, dynamic> res) => res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : {};

  /// `pin` when the number already has an mPIN, `activate` when it needs a code first.
  Future<String> status(String mobile) async {
    final d = _data(await _api.post('/api/mobile-auth/status', body: {'mobile': mobile}));
    return '${d['state']}' == 'pin' ? 'pin' : 'activate';
  }

  /// Asks for a code. It goes to the person's WhatsApp first (and falls back to SMS on the server when
  /// WhatsApp is not available for the school or the number); [sms] asks for SMS directly.
  Future<void> sendOtp(String mobile, {bool sms = false}) =>
      _api.post('/api/mobile-auth/otp/send', body: {'mobile': mobile, if (sms) 'channel': 'sms'});

  /// Returns the one-time setup token that allows choosing an mPIN.
  Future<String> verifyOtp(String mobile, String otp) async {
    final d = _data(await _api.post('/api/mobile-auth/otp/verify', body: {'mobile': mobile, 'otp': otp}));
    return '${d['setup_token'] ?? ''}';
  }

  Future<MobileSignIn> setPin(String mobile, String pin, String setupToken) async =>
      _signIn(await _api.post('/api/mobile-auth/pin/set', body: {'mobile': mobile, 'pin': pin, 'setup_token': setupToken}));

  Future<MobileSignIn> pinLogin(String mobile, String pin) async =>
      _signIn(await _api.post('/api/mobile-auth/pin/login', body: {'mobile': mobile, 'pin': pin}));

  Future<MobileSignIn> deviceLogin(String mobile, String deviceToken) async =>
      _signIn(await _api.post('/api/mobile-auth/device/login', body: {'mobile': mobile, 'device_token': deviceToken}));

  Future<String> registerDevice(String ticket, {String label = 'Phone'}) async {
    final d = _data(await _api.post('/api/mobile-auth/device/register', body: {'ticket': ticket, 'label': label}));
    return '${d['device_token'] ?? ''}';
  }

  Future<void> revokeDevice(String mobile, String deviceToken) async {
    try {
      await _api.post('/api/mobile-auth/device/revoke', body: {'mobile': mobile, 'device_token': deviceToken});
    } on ApiException {
      // Turning it off locally is what matters; the token is useless without the phone.
    }
  }

  MobileSignIn _signIn(Map<String, dynamic> res) {
    final d = _data(res);
    final list = d['profiles'];
    return MobileSignIn(
      ticket: '${d['ticket'] ?? ''}',
      profiles: [
        if (list is List)
          for (final p in list)
            if (p is Map) MobileProfile.fromJson(Map<String, dynamic>.from(p)),
      ],
    );
  }

  /// The profiles on [mobile], for the profile that is signed in now (its [token] proves who is asking).
  Future<List<MobileProfile>> profilesOnNumber(String mobile, String token) async {
    final d = _data(await _api.post('/api/mobile-auth/profiles', body: {'mobile': mobile}, token: token));
    final list = d['profiles'];
    return [
      if (list is List)
        for (final p in list)
          if (p is Map) MobileProfile.fromJson(Map<String, dynamic>.from(p)),
    ];
  }

  // ------------------------------------------------------------------- phone

  Future<String?> lastMobile() => _safeRead(_kLastMobile);

  Future<void> saveLastMobile(String mobile) => _safeWrite(_kLastMobile, mobile);

  Future<void> forgetLastMobile() => _safeDelete(_kLastMobile);

  Future<String?> deviceToken(String mobile) => _safeRead(_kDevice(mobile));

  Future<void> saveDeviceToken(String mobile, String token) async {
    await _safeWrite(_kDevice(mobile), token);
    await _safeDelete(_kDeclined(mobile));
  }

  Future<void> clearDeviceToken(String mobile) => _safeDelete(_kDevice(mobile));

  /// The user said "not now": do not offer biometrics again for this number on this phone.
  Future<bool> biometricDeclined(String mobile) async => await _safeRead(_kDeclined(mobile)) == '1';

  Future<void> declineBiometric(String mobile) => _safeWrite(_kDeclined(mobile), '1');

  /// The biometric this phone can use right now, or null when there is none enrolled / supported.
  Future<BiometricKind?> availableBiometric() async {
    try {
      if (!await _local.isDeviceSupported()) return null;
      final types = await _local.getAvailableBiometrics();
      if (types.isEmpty) return null;
      if (types.contains(BiometricType.face)) return BiometricKind.face;
      if (types.contains(BiometricType.fingerprint)) return BiometricKind.fingerprint;
      return BiometricKind.generic;
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// The phone has biometric hardware / a screen lock, even if no fingerprint or face is enrolled yet.
  Future<bool> biometricSupported() async {
    try {
      return await _local.isDeviceSupported() || await _local.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Asks the phone to check the person (Face ID / fingerprint). False if cancelled or failed.
  Future<bool> authenticate(String reason) async {
    try {
      return await _local.authenticate(localizedReason: reason, biometricOnly: true);
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _safeRead(String k) async {
    try {
      return await _storage.read(key: k);
    } catch (_) {
      return null;
    }
  }

  Future<void> _safeWrite(String k, String v) async {
    try {
      await _storage.write(key: k, value: v);
    } catch (_) {}
  }

  Future<void> _safeDelete(String k) async {
    try {
      await _storage.delete(key: k);
    } catch (_) {}
  }
}
