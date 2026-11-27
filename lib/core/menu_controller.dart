import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'auth_controller.dart';
import 'feed.dart';

/// Holds the signed-in user's home feed (sections of tiles) for the whole app.
class AppMenuController extends ChangeNotifier {
  AppMenuController(this._auth) : _repo = FeedRepository(_auth.api);

  final AuthController _auth;
  final FeedRepository _repo;

  List<FeedSection> sections = const [];
  List<FeedSearchEntry> index = const [];
  bool loading = false;
  String? error;

  Future<void> load() async {
    final s = _auth.session;
    if (s == null || loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      sections = await _repo.load(s);
      index = buildFeedIndex(sections);
    } on ApiException catch (e) {
      error = e.message;
      sections = const [];
      index = const [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// The rights fingerprint of what is on screen now.
  String get version => _repo.version;

  /// Reloads the menu without a spinner; used when the app comes back to the foreground so an
  /// admin's change in Roles & Access shows up without signing out.
  Future<void> refreshQuietly() async {
    final s = _auth.session;
    if (s == null || loading) return;
    final before = _repo.version;
    try {
      final fresh = await _repo.load(s);
      if (_repo.version != before || sections.isEmpty) {
        sections = fresh;
        index = buildFeedIndex(fresh);
        error = null;
        notifyListeners();
      }
    } on ApiException {
      // Keep the menu the user already has; a failed refresh must not blank it.
    }
  }

  void clear() {
    sections = const [];
    index = const [];
    error = null;
    notifyListeners();
  }
}
