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

  void clear() {
    sections = const [];
    index = const [];
    error = null;
    notifyListeners();
  }
}
