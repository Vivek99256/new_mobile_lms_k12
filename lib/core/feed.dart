import '../screens/role_menu_screens.dart';
import 'api_client.dart';
import 'session.dart';

/// One tile of the home screen (`contents[]` of a feed section).
class FeedItem {
  const FeedItem({
    required this.label,
    required this.iconUrl,
    required this.api,
    required this.apiParam,
    required this.screenName,
    required this.renderType,
    required this.webUrl,
  });

  final String label;
  final String iconUrl;

  /// `sub_title_api`: the ERP endpoint the screen calls (absolute URL).
  final String api;
  final String apiParam;

  /// Which screen to open (`t_homework`, `home_work`, `fees`, ...).
  final String screenName;

  /// `native` | `webview` | `native_dynamic` - the Mobile Page Builder's routing hints.
  final String renderType;
  final String webUrl;

  factory FeedItem.fromJson(Map<String, dynamic> j) => FeedItem(
        label: _str(j['title'] ?? j['sub_title']),
        iconUrl: _str(j['icon'] ?? j['sub_title_icon']),
        api: _str(j['api'] ?? j['sub_title_api']),
        apiParam: _str(j['api_param'] ?? j['sub_title_api_param']),
        screenName: _str(j['screen_name']),
        renderType: _str(j['render_type'] ?? 'native').toLowerCase(),
        webUrl: _str(j['web_url']),
      );
}

/// A JSON value as trimmed text; null (and the string "null") become empty.
String _str(dynamic v) {
  final s = v == null ? '' : '$v'.trim();
  return s == 'null' ? '' : s;
}

/// A titled card on the home screen holding a grid of [FeedItem]s.
class FeedSection {
  const FeedSection({
    required this.title,
    required this.colorHex,
    required this.backgroundImage,
    required this.menuType,
    required this.items,
  });

  final String title;

  /// `main_itle_color` (the feed's own spelling): the title colour, e.g. `#09518c`.
  final String colorHex;
  final String backgroundImage;
  final String menuType;
  final List<FeedItem> items;

  bool get isBanner => menuType.toLowerCase() == 'banner';

  factory FeedSection.fromJson(Map<String, dynamic> j) {
    final contents = j['contents'];
    final items = <FeedItem>[
      if (contents is List)
        for (final c in contents)
          if (c is Map) FeedItem.fromJson(Map<String, dynamic>.from(c)),
      // A Banner (or single-screen) row carries its own screen instead of contents.
      if (contents is! List && j['screen_name'] != null)
        FeedItem.fromJson({...j, 'title': j['main_title'], 'sub_title': j['main_title']}),
    ];
    return FeedSection(
      title: _str(j['main_title']),
      colorHex: _str(j['color'] ?? j['main_itle_color']),
      backgroundImage: _str(j['background_image'] ?? j['main_title_background_image']),
      menuType: _str(j['menu_type']),
      items: items,
    );
  }
}

/// The home menu for the signed-in role. It comes from `GET /api/mobile/bootstrap`, which
/// reads the role and school from the verified JWT (so a token cannot ask for another
/// role's menu) and returns only the sections and tiles the school granted in Mobile App
/// Menu Rights. Servers that predate that route fall back to the old body-driven calls:
/// students `/api/homescreen`, everyone else `/teacher_homescreen`.
class FeedRepository {
  FeedRepository(this._api);
  final ApiClient _api;

  static bool isStudentProfile(String profileName) => profileName.trim().toLowerCase() == 'student';

  Future<List<FeedSection>> load(Session s) async {
    try {
      final res = await _api.get('/api/mobile/bootstrap', token: s.token);
      if (res['success'] != true && '${res['status']}' != '1') {
        throw ApiException((res['message'] ?? 'Could not load your menu.').toString());
      }
      final data = res['data'];
      // Only the menus granted in web Roles & Access -> Mobile (`role_menu`). The old
      // mobile_homescreen `menu` is deliberately no longer shown.
      return mergeRoleMenu(const [], data is Map ? data['role_menu'] : null);
    } on ApiException catch (e) {
      // Only a missing route means "old server"; auth and server errors must surface.
      if (e.statusCode != 404) rethrow;
      return _loadLegacy(s);
    }
  }

  Future<List<FeedSection>> _loadLegacy(Session s) async {
    final res = await _api.post(
      isStudentProfile(s.userProfileName) ? '/api/homescreen' : '/teacher_homescreen',
      body: {
        'type': 'API',
        'sub_institute_id': s.subInstituteId,
        'user_id': s.userId,
        'user_profile_id': s.userProfileId,
        'user_profile_name': s.userProfileName,
      },
      token: s.token,
    );
    if ('${res['status']}' != '1') {
      throw ApiException((res['message'] ?? 'Could not load your menu.').toString());
    }
    return parse(res['data']);
  }

  /// Adds the Roles & Access "Mobile" menus (`role_menu.tree`) as extra sections: each level-2
  /// module becomes a section of its mobile-enabled screens. A screen already on the home
  /// menu (same label) is not repeated. `screen_name` carries the web link, so a screen the
  /// app has no port for shows as enabled-but-"Soon" instead of silently missing.
  static List<FeedSection> mergeRoleMenu(List<FeedSection> base, dynamic roleMenu) {
    final tree = roleMenu is Map ? roleMenu['tree'] : null;
    if (tree is! List) return base;
    final seen = {for (final s in base) for (final i in s.items) i.label.toLowerCase()};
    final extra = <FeedSection>[];

    void walk(dynamic node, String sectionTitle) {
      if (node is! Map) return;
      final kids = node['children'];
      final enabled = node['mobile_enabled'] == true;
      final hasKids = kids is List && kids.isNotEmpty;
      if (!hasKids) {
        if (!enabled) return;
        final label = _str(node['title']);
        if (label.isEmpty) return;
        // A tile needs either a hand-built native page, or a Laravel path the generic native
        // screen can read. Pages that exist only on the Next.js web have neither, so are skipped.
        if (isWebOnlyMenu(_str(node['link']))) return;
        final path = _str(node['path']);
        if (lookupRoleMenuScreen(_str(node['link'])) == null && path.isEmpty) return;
        if (!seen.add(label.toLowerCase())) return;
        final item = FeedItem(
          label: label,
          iconUrl: _str(node['icon']),
          api: path,
          apiParam: '',
          screenName: _str(node['link']),
          renderType: 'legacy',
          webUrl: '',
        );
        final i = extra.indexWhere((s) => s.title == sectionTitle);
        if (i >= 0) {
          extra[i].items.add(item);
        } else {
          extra.add(FeedSection(title: sectionTitle, colorHex: '', backgroundImage: '', menuType: 'Grid', items: [item]));
        }
        return;
      }
      // A leaf-bearing node names its section; ancestors above it are only containers.
      final hasLeafChild = kids.any((k) => k is Map && (k['children'] is! List || (k['children'] as List).isEmpty));
      final title = hasLeafChild ? _str(node['title']) : sectionTitle;
      for (final k in kids) {
        walk(k, title);
      }
    }

    for (final root in tree) {
      walk(root, 'More');
    }
    return [...base, ...extra];
  }

  static List<FeedSection> parse(dynamic data) {
    if (data is! List) return const [];
    return [
      for (final raw in data)
        if (raw is Map) FeedSection.fromJson(Map<String, dynamic>.from(raw)),
    ].where((s) => s.items.isNotEmpty).toList();
  }
}

/// A tile together with its section, for search.
class FeedSearchEntry {
  const FeedSearchEntry(this.item, this.section);
  final FeedItem item;
  final FeedSection section;
}

List<FeedSearchEntry> buildFeedIndex(List<FeedSection> sections) => [
      for (final s in sections)
        for (final i in s.items) FeedSearchEntry(i, s),
    ];
