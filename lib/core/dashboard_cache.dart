import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Last dashboard payload per user and role, so the screen can paint instantly on open
/// and refresh in the background (stale-while-revalidate).
class DashboardCache {
  DashboardCache._();

  static String _key(int userId, String role) => 'dashboard_${userId}_${role.toLowerCase()}';

  static Future<({Map<String, dynamic> data, DateTime savedAt})?> read(int userId, String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId, role));
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return (
        data: Map<String, dynamic>.from(j['data'] as Map),
        savedAt: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
      );
    } catch (_) {
      return null; // a corrupt cache entry is just a cache miss
    }
  }

  static Future<void> write(int userId, String role, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(userId, role),
        jsonEncode({'ts': DateTime.now().millisecondsSinceEpoch, 'data': data}),
      );
    } catch (_) {
      // caching is best-effort
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().where((k) => k.startsWith('dashboard_'))) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
