import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light, Dark, or follow the phone (System default). The choice is kept on the phone.
class ThemeController extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode mode = ThemeMode.system;

  /// Reads the saved choice. Called before the app starts so the first frame already has the right look.
  Future<void> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      mode = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      mode = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode next) async {
    if (next == mode) return;
    mode = next;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(_key, switch (next) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      });
    } catch (_) {
      // The choice still applies for this session.
    }
  }
}
