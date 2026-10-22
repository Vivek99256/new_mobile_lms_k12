import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/auth_controller.dart';
import '../core/feed.dart';
import '../core/menu_controller.dart';
import '../core/updater.dart';
import '../screens/screen_registry.dart';
import 'design.dart';
import 'home_page.dart';
import 'modules_page.dart';
import 'theme.dart';

/// The frame after sign-in: Home and All modules as tabs under the bottom nav, with two
/// pinned shortcuts per role (found in the school's menu; a slot with no right is skipped).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  int _tab = 0;
  int _dir = 1; // which way the incoming tab slides from
  String? _focus;
  int _focusGen = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppMenuController>().load();
      context.read<UpdateService>().checkAndDownload();
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _goTab(int i) {
    if (_tab != i) {
      _dir = i > _tab ? 1 : -1;
      _fade.forward(from: 0);
    }
    setState(() => _tab = i);
  }

  void _openModules([String? section]) => setState(() {
    if (_tab != 1) {
      _dir = 1;
      _fade.forward(from: 0);
    }
    _tab = 1;
    _focus = section;
    _focusGen++;
  });

  /// First tile whose name contains one of [keys] and that has a screen to open.
  FeedItem? _find(AppMenuController menu, List<String> keys) {
    for (final k in keys) {
      for (final e in menu.index) {
        if (e.item.label.toLowerCase().contains(k) && hasScreen(context, e.item)) {
          return e.item;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthController>().session;
    final menu = context.watch<AppMenuController>();
    final restart = context.select<UpdateService, bool>((u) => u.restartNeeded);

    final keys = switch (roleOf(session?.userProfileName ?? '')) {
      HomeRole.student => const [
        ['homework', 'assignment'],
        ['exam', 'result'],
      ],
      HomeRole.teacher => const [
        ['attendance'],
        ['homework'],
      ],
      HomeRole.admin => const [
        ['student'],
        ['fee'],
      ],
    };
    final shortcuts = <FeedItem>[];
    for (final k in keys) {
      final it = _find(menu, k);
      if (it != null && !shortcuts.any((s) => s.label == it.label)) {
        shortcuts.add(it);
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        extendBody: true,
        body: Column(
          children: [
            if (restart)
              Container(
                color: Brand.info0,
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.paddingOf(context).top + 8,
                  20,
                  8,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.system_update_alt, size: 16, color: Brand.info),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'An update is ready. Restart the app to apply it.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Brand.info,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: restart,
                child: AnimatedBuilder(
                  animation: _fade,
                  builder: (context, child) {
                    final v = Curves.easeOutCubic.transform(_fade.value);
                    final move = MediaQuery.disableAnimationsOf(context) ? 0.0 : (1 - v) * 28 * _dir;
                    return Opacity(opacity: v, child: Transform.translate(offset: Offset(move, 0), child: child));
                  },
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      HomePage(onOpenModules: _openModules),
                      ModulesPage(key: ValueKey(_focusGen), focusSection: _focus),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNav(
          selected: _tab == 0 ? 0 : shortcuts.length + 1,
          items: [
            NavItem(Icons.home_outlined, 'Home', () => _goTab(0)),
            for (final it in shortcuts)
              NavItem(
                menuIcon(it.label, 2),
                it.label,
                () => openFeedItem(context, it),
              ),
            NavItem(Icons.grid_view_rounded, 'Modules', () => _openModules()),
          ],
        ),
      ),
    );
  }
}
