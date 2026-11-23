import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

/// Online Fees Collect: the school's login-free parent payment page (`/pay/<school code>` on the
/// K-12 web app: mobile number -> pick the child -> choose months -> pay -> receipt). Nobody needs an
/// account, so the app just opens that link, and the same link can be sent to parents.
class OnlineFeesCollectController extends ChangeNotifier {
  OnlineFeesCollectController({required this.args});
  final ScreenArgs args;

  /// The K-12 web app that serves the public payment page.
  static const webBase = 'https://k12.scholarclone.com';

  bool busy = false;
  String? error;

  /// The school's own code: its ShortCode when the login gave one, else its numeric id (the page accepts both).
  String get schoolCode {
    final raw = args.session.raw;
    final short = s(raw['short_code'] ?? raw['institute_short_code']);
    return short.isNotEmpty ? short : '${args.session.subInstituteId}';
  }

  /// The link to send to parents; opens with no login.
  String get payLink => '$webBase/pay/${Uri.encodeComponent(schoolCode)}';

  /// Opens the payment page in an in-app browser (system browser as a fallback). Returns true when launched.
  Future<bool> payNow() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final uri = Uri.parse(payLink);
      var ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!ok) ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) error = 'Could not open the browser.';
      return ok;
    } catch (_) {
      error = 'Could not open the payment page. Try again.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Copies the parent payment link, ready to paste into WhatsApp / SMS.
  Future<void> copyLink() => Clipboard.setData(ClipboardData(text: payLink));
}
