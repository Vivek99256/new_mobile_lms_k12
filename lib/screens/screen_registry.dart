import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_controller.dart';
import '../core/feed.dart';
import '../core/legacy_api.dart';
import '../core/native_target.dart';
import '../core/session.dart';
import '../ui/native_screens.dart';
import 'admin/admin_screens.dart';
import 'student/student_screens.dart';
import 'teacher/teacher_screens.dart';

/// What a screen needs to run: the tile that opened it and the signed-in user.
class ScreenArgs {
  ScreenArgs(this.item, this.session, this.api);
  final FeedItem item;
  final Session session;
  final LegacyApi api;
  String get title => item.label;
}

typedef ScreenBuilder = Widget Function(ScreenArgs args);

/// The ported screen for [screenName] as seen by [profile] (the user's profile name).
/// Students use the student screens, teachers the teacher screens; admins (and any other
/// staff profile) look in the admin-only screens first, then the shared teacher screens.
ScreenBuilder? lookupScreen(String profile, String screenName) {
  switch (profile.trim().toLowerCase()) {
    case 'student':
      return studentScreens[screenName];
    case 'teacher':
      return teacherScreens[screenName];
    default:
      return adminScreens[screenName] ?? teacherScreens[screenName];
  }
}

/// The screen for a tile, or null when it has none yet ("Soon").
Widget? resolveScreen(BuildContext context, FeedItem item) {
  final auth = context.read<AuthController>();
  final session = auth.session;
  if (session == null) return null;
  final args = ScreenArgs(item, session, LegacyApi(session));

  final ported = lookupScreen(session.userProfileName, item.screenName);
  if (ported != null) return ported(args);

  // Mobile Page Builder routing hints.
  if (item.renderType == 'webview' && item.webUrl.isNotEmpty) {
    final t = NativeTarget.fromWebUrl(item.webUrl);
    if (t != null) return NativePageScreen(slug: t.value, title: item.label);
  }
  if (item.renderType == 'native_dynamic' && item.webUrl.isNotEmpty) {
    return DynamicPageScreen(pageKey: item.webUrl, title: item.label);
  }

  // Any other tile that carries an ERP endpoint: show what it returns, natively.
  if (item.api.isNotEmpty) {
    return DataScreen(
      title: item.label,
      endpoint: null,
      loader: () async {
        final res = await args.api.post(item.api);
        if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res));
        return res['data'] ?? res;
      },
    );
  }
  return null;
}

/// Opens the tile's screen, or explains that it is not available in the app yet.
void openFeedItem(BuildContext context, FeedItem item) {
  final screen = resolveScreen(context, item);
  if (screen == null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${item.label} is enabled for you but is not available in this app yet.'),
        behavior: SnackBarBehavior.floating,
      ));
    return;
  }
  Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}

/// Whether the tile opens something (a ported screen, a builder/dynamic page, or a generic
/// native list of its API) rather than "Soon".
bool hasScreen(BuildContext context, FeedItem item) {
  final profile = context.read<AuthController>().session?.userProfileName ?? '';
  return lookupScreen(profile, item.screenName) != null ||
      item.api.isNotEmpty ||
      (item.renderType == 'webview' && NativeTarget.fromWebUrl(item.webUrl) != null) ||
      (item.renderType == 'native_dynamic' && item.webUrl.isNotEmpty);
}
