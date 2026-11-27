import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/auth_controller.dart';
import '../core/config.dart';
import '../core/dashboard_cache.dart';
import '../core/feed.dart';
import '../core/menu_controller.dart';
import '../core/mobile_auth.dart';
import '../core/native_target.dart';
import '../core/session.dart';
import '../core/updater.dart';
import '../core/theme_controller.dart';
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
                  : Border(bottom: BorderSide(color: Brand.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
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
              : Border(bottom: BorderSide(color: Brand.line)),
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
            Icon(Icons.chevron_right_rounded, color: Brand.ink3),
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
                          style: TextStyle(
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
                  _YearRow(session: s),
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
          const _SwitchProfileSection(),
          const GroupLabel('Appearance'),
          const SoftCard(clip: true, child: _ThemeChoice()),
          const SizedBox(height: 20),
          const GroupLabel('About'),
          SoftCard(
            clip: true,
            child: Column(
              children: [
                FutureBuilder<PackageInfo>(
                  future: _packageInfo,
                  builder: (_, snap) => row(
                    'App version',
                    snap.hasData ? '${snap.data!.version} (build ${snap.data!.buildNumber})' : '',
                  ),
                ),
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
                  'Stays until you log out',
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Brand.err,
              backgroundColor: Brand.card,
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

/// The installed app's version and build number, read once.
final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

/// Light, Dark or System default. The choice is saved and applies at once.
class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();

    Widget option(ThemeMode mode, IconData icon, String title, String hint, {bool last = false}) {
      final on = controller.mode == mode;
      return InkWell(
        onTap: () => controller.setMode(mode),
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: Brand.line))),
          child: Row(children: [
            Icon(icon, size: 22, color: on ? Brand.primary : Brand.ink3),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(hint, style: TextStyle(fontSize: 12, height: 1.33, color: Brand.ink3)),
              ]),
            ),
            Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: on ? Brand.primary : Brand.border),
          ]),
        ),
      );
    }

    return Semantics(
      label: 'Appearance',
      child: Column(children: [
        option(ThemeMode.system, Icons.brightness_auto_rounded, 'System default', "Follows your phone's setting"),
        option(ThemeMode.light, Icons.light_mode_rounded, 'Light', 'Always light'),
        option(ThemeMode.dark, Icons.dark_mode_rounded, 'Dark', 'Always dark', last: true),
      ]),
    );
  }
}

/// Academic year with a picker, like the web's year dropdown. Changing it reloads the app for that year.
class _YearRow extends StatelessWidget {
  const _YearRow({required this.session});
  final Session session;

  Future<void> _pick(BuildContext context) async {
    final years = session.academicYears;
    final current = session.mobileSyear ?? '';
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Academic year', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          for (final y in years)
            ListTile(
              title: Text(y, style: TextStyle(fontWeight: y == current ? FontWeight.w700 : FontWeight.w500, color: y == current ? Brand.primary : null)),
              trailing: y == current ? Icon(Icons.check_rounded, color: Brand.primary) : null,
              onTap: () => Navigator.pop(ctx, y),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked == null || picked == current || !context.mounted) return;
    final auth = context.read<AuthController>();
    final menu = context.read<AppMenuController>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    auth.setAcademicYear(picked);
    menu.clear();
    await DashboardCache.clear();
    nav.popUntil((r) => r.isFirst);
    menu.load();
    messenger.showSnackBar(SnackBar(content: Text('Showing academic year $picked. It goes back to the current year when you reopen the app.')));
  }

  @override
  Widget build(BuildContext context) {
    final current = session.mobileSyear ?? '';
    if (current.isEmpty) return const SizedBox.shrink();
    final canPick = session.academicYears.length > 1;
    return InkWell(
      onTap: canPick ? () => _pick(context) : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Academic year', style: TextStyle(fontSize: 12, height: 1.33, fontWeight: FontWeight.w500, color: Brand.ink3)),
              if (!canPick) Text(current, style: const TextStyle(fontWeight: FontWeight.w500)),
            ]),
          ),
          if (canPick)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: Brand.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.school_outlined, size: 18, color: Brand.ink2),
                const SizedBox(width: 8),
                Text(current, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Brand.ink2),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// Every profile on the phone number (the parent and each child): shows who is open and switches to another.
/// Only appears when the person signed in with a mobile number and that number has more than one profile.
class _SwitchProfileSection extends StatefulWidget {
  const _SwitchProfileSection();

  @override
  State<_SwitchProfileSection> createState() => _SwitchProfileSectionState();
}

class _SwitchProfileSectionState extends State<_SwitchProfileSection> {
  String? _mobile;
  List<MobileProfile> _profiles = const [];
  String? _busyKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = context.read<MobileAuthService>();
    final session = context.read<AuthController>().session;
    final mobile = await svc.lastMobile();
    if (mobile == null || session == null) return;
    try {
      final list = await svc.profilesOnNumber(mobile, session.token);
      if (mounted) {
        setState(() {
          _mobile = mobile;
          _profiles = list;
        });
      }
    } catch (_) {
      // Signed in by email, or this profile is not on the saved number: no switcher.
    }
  }

  Future<String?> _askPin() => showDialog<String>(
    context: context,
    builder: (ctx) {
      final ctl = TextEditingController();
      return AlertDialog(
        title: const Text('Enter your mPIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctl,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: MobileAuthService.pinLength,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(counterText: ''),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(ctx, ctl.text),
            child: const Text('Open'),
          ),
        ],
      );
    },
  );

  Future<void> _switch(MobileProfile p) async {
    final mobile = _mobile;
    if (mobile == null || _busyKey != null) return;
    final svc = context.read<MobileAuthService>();
    final auth = context.read<AuthController>();
    final menu = context.read<AppMenuController>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    String? pin;
    String? deviceToken;
    if (p.needsAuth) {
      // A child's profile moving up to a staff one: biometrics if they are on, else the mPIN.
      final token = await svc.deviceToken(mobile);
      if (token != null && token.isNotEmpty && await svc.availableBiometric() != null && await svc.authenticate('Confirm to open ${p.name}')) {
        deviceToken = token;
      } else {
        pin = await _askPin();
        if (pin == null || pin.isEmpty) return;
      }
    }

    setState(() => _busyKey = p.key);
    final err = await auth.switchProfile(mobile: mobile, profileKey: p.key, pin: pin, deviceToken: deviceToken);
    if (!mounted) return;
    setState(() => _busyKey = null);
    if (err != null) {
      messenger.showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    menu.clear();
    await DashboardCache.clear();
    nav.popUntil((r) => r.isFirst);
    menu.load();
  }

  @override
  Widget build(BuildContext context) {
    if (_profiles.length < 2) return const SizedBox.shrink();
    final ordered = [..._profiles.where((p) => !p.isStudent), ..._profiles.where((p) => p.isStudent)];

    Widget tile(MobileProfile p, {required bool last}) {
      final accent = p.isStudent ? const Color(0xFF0EA5E9) : Brand.primary;
      final busy = _busyKey == p.key;
      return InkWell(
        onTap: p.current || _busyKey != null ? null : () => _switch(p),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: Brand.line))),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
              child: Text(p.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (p.subtitle.isNotEmpty) Text(p.subtitle, style: TextStyle(fontSize: 12.5, height: 1.3, fontWeight: FontWeight.w600, color: accent)),
              ]),
            ),
            if (busy)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else if (p.current)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Brand.ok0, borderRadius: BorderRadius.circular(99)),
                child: Text('Current', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Brand.ok)),
              )
            else ...[
              if (p.needsAuth) Icon(Icons.lock_outline_rounded, size: 18, color: Brand.ink3),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: Brand.ink3),
            ],
          ]),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const GroupLabel('Switch profile'),
      SoftCard(
        clip: true,
        child: Column(children: [
          for (var i = 0; i < ordered.length; i++) tile(ordered[i], last: i == ordered.length - 1),
        ]),
      ),
      const SizedBox(height: 20),
    ]);
  }
}
