import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/auth_controller.dart';
import '../core/config.dart';
import '../core/dashboard_cache.dart';
import '../core/feed.dart';
import '../core/menu_controller.dart';
import '../core/native_target.dart';
import '../core/updater.dart';
import '../screens/screen_registry.dart';
import 'design.dart';
import 'home_page.dart' show Avatar;
import 'native_screens.dart';
import 'theme.dart';

/// Profile and sign out: who is signed in, the academic session, app info, shortcuts, and a
/// confirmed sign-out.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Sign out?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'You will need to sign in again to use the app on this device.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Brand.err,
              minimumSize: const Size(110, 48),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final auth = context.read<AuthController>();
    final nav = Navigator.of(context);
    context.read<AppMenuController>().clear();
    await DashboardCache.clear();
    await auth.logout();
    nav.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AuthController>().session;
    final updates = context.watch<UpdateService>();
    if (s == null) return const Scaffold();

    Widget row(String title, String value, {bool last = false}) => value.isEmpty
        ? const SizedBox.shrink()
        : Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: last
                  ? null
                  : const Border(bottom: BorderSide(color: Brand.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.33,
                          fontWeight: FontWeight.w500,
                          color: Brand.ink3,
                        ),
                      ),
                      Text(
                        value,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

    Widget action(
      IconData icon,
      String label,
      VoidCallback onTap, {
      bool last = false,
    }) => InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Brand.line)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Brand.primaryDark),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Brand.ink3),
          ],
        ),
      ),
    );

    final ownProfile = resolveScreen(
      context,
      const FeedItem(
        label: 'My profile',
        iconUrl: '',
        api: '',
        apiParam: '',
        screenName: 't_own_profile',
        renderType: 'native',
        webUrl: '',
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Rise(
            child: SoftCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Avatar(name: s.name, imageUrl: s.imageUrl, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.44,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          s.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.33,
                            fontWeight: FontWeight.w500,
                            color: Brand.ink3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Tag(s.userProfileName),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if ((s.mobileSyear ?? '').isNotEmpty || s.schoolName.isNotEmpty) ...[
            const SizedBox(height: 20),
            const GroupLabel('Academic session'),
            SoftCard(
              clip: true,
              child: Column(
                children: [
                  row('School', s.schoolName),
                  row('Academic year', s.mobileSyear ?? '', last: true),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          const GroupLabel('Shortcuts'),
          SoftCard(
            clip: true,
            child: Column(
              children: [
                if (ownProfile != null)
                  action(
                    Icons.badge_outlined,
                    'My profile',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ownProfile),
                    ),
                  ),
                action(
                  Icons.space_dashboard_outlined,
                  'Dashboard',
                  () => openTarget(
                    context,
                    'Dashboard',
                    const NativeTarget.dashboard(),
                  ),
                ),
                action(
                  Icons.ios_share_rounded,
                  'Share the app',
                  () => SharePlus.instance.share(
                    ShareParams(
                      text:
                          "Hi, I'm recommending ${AppConfig.appName} for your school.",
                    ),
                  ),
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const GroupLabel('About'),
          SoftCard(
            clip: true,
            child: Column(
              children: [
                row(
                  'App updates',
                  !updates.available
                      ? 'Live updates are off in this build'
                      : updates.restartNeeded
                      ? 'Update downloaded - restart to apply'
                      : 'Patch ${updates.currentPatch ?? 'none'} - up to date',
                ),
                row(
                  'Signed in on this device',
                  'Ends after 30 min idle',
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Brand.err,
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFF1B8B8)),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout_rounded, size: 22),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
