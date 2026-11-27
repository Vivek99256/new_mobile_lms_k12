import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/auth_controller.dart';
import '../core/feed.dart';
import '../core/menu_controller.dart';
import '../core/updater.dart';
import '../presentation/ai_chat/ai_chat_screen.dart';
import '../screens/screen_registry.dart';
import 'design.dart';
import 'home_page.dart';
import 'menu_sheet.dart';
import 'theme.dart';

/// The frame after sign-in: Home and All modules as tabs under the bottom nav, with two
/// pinned shortcuts per role (found in the school's menu; a slot with no right is skipped).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );

  /// 0 = Home, 1 = Modules, 2.. = the pinned shortcuts (each keeps its own navigator, so the bottom bar stays
  /// visible on the shortcut's pages and on anything it opens).
  int _tab = 0;
  int _prev = 0; // the tab that is fading out
  final Map<String, GlobalKey<NavigatorState>> _navKeys = {};
  final Set<String> _visited = {};
  List<FeedItem> _shortcuts = const [];
  int _dir = 1; // which way the incoming tab slides from

  /// An admin's change in Roles & Access reaches an open app when it comes back to the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AppMenuController>().refreshQuietly();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppMenuController>().load();
      context.read<UpdateService>().checkAndDownload();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fade.dispose();
    super.dispose();
  }

  void _goShortcut(int slot) {
    final it = _shortcuts[slot];
    if (!hasScreen(context, it)) {
      openFeedItem(context, it); // explains that it is not available yet
      return;
    }
    final tab = slot + 2;
    if (_tab == tab) {
      _navKeys[it.label]?.currentState?.popUntil(
        (r) => r.isFirst,
      ); // tapping the active tab returns to its first page
      return;
    }
    _visited.add(it.label);
    _goTab(tab);
  }

  /// Android back: close a page inside the shortcut tab, else go Home, else leave the app.
  void _onBack() {
    if (_tab >= 2 && _tab - 2 < _shortcuts.length) {
      final nav = _navKeys[_shortcuts[_tab - 2].label]?.currentState;
      if (nav != null && nav.canPop()) {
        nav.pop();
        return;
      }
    }
    if (_tab != 0) {
      _goTab(0);
    } else {
      SystemNavigator.pop();
    }
  }

  Widget _shortcutTab(FeedItem it) {
    final key = _navKeys.putIfAbsent(
      it.label,
      () => GlobalKey<NavigatorState>(),
    );
    return Navigator(
      key: key,
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (ctx) => resolveScreen(ctx, it) ?? const SizedBox.shrink(),
      ),
    );
  }

  /// Switches tab: the old tab fades/slides out while the new one fades/slides in. The new tab is built first
  /// (invisible), and the animation starts on the next frame, so a heavy first build cannot make it stutter.
  void _goTab(int i, {VoidCallback? also}) {
    if (_tab == i) {
      setState(() => also?.call());
      return;
    }
    final reduce = MediaQuery.disableAnimationsOf(context);
    _dir = i > _tab ? 1 : -1;
    _prev = _tab;
    _fade.value = reduce ? 1 : 0;
    setState(() {
      _tab = i;
      also?.call();
    });
    if (!reduce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tab == i) _fade.forward(from: 0);
      });
    }
  }

  /// The menu is a bottom sheet over whichever tab is showing.
  void _openModules([String? section]) => showMenuSheet(context, section: section);

  /// One tab page, wrapped so it can fade and slide. Tabs that are not showing stay alive but are not drawn.
  Widget _tabPage(int index, Widget child) {
    return AnimatedBuilder(
      animation: _fade,
      child: RepaintBoundary(child: child),
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_fade.value);
        final animating = _fade.value < 1;
        if (index == _tab) {
          return TickerMode(
            enabled: true,
            child: Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset((1 - v) * 28 * _dir, 0),
                child: child,
              ),
            ),
          );
        }
        if (index == _prev && animating) {
          final out = (1 - v * 1.6).clamp(0.0, 1.0);
          return IgnorePointer(
            child: Opacity(
              opacity: out,
              child: Transform.translate(
                offset: Offset(-v * 20 * _dir, 0),
                child: child,
              ),
            ),
          );
        }
        return Offstage(child: TickerMode(enabled: false, child: child!));
      },
    );
  }

  /// First tile whose name contains one of [keys] and that has a screen to open.
  FeedItem? _find(AppMenuController menu, List<String> keys) {
    for (final k in keys) {
      for (final e in menu.index) {
        if (e.item.label.toLowerCase().contains(k) &&
            hasScreen(context, e.item)) {
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

    _shortcuts = shortcuts;
    if (_tab >= 2 + shortcuts.length) _tab = 0;
    final navSelected = _tab == 0
        ? 0
        : (_tab == 1 ? shortcuts.length + 1 : _tab - 1);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          extendBody: true,
          // The AI assistant, one tap away from Home and Modules (shortcut tabs keep their own Save bars clear).
          floatingActionButton: _tab <= 1
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: FloatingActionButton.extended(
                    heroTag: 'ai-chat',
                    backgroundColor: Brand.primary,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                    label: const Text('Ask AI', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                )
              : null,
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
                  child: Row(
                    children: [
                      Icon(
                        Icons.system_update_alt,
                        size: 16,
                        color: Brand.info,
                      ),
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _tabPage(0, HomePage(onOpenModules: _openModules)),
                      _tabPage(
                        1,
                        const SizedBox.shrink(),
                      ),
                      for (var i = 0; i < shortcuts.length; i++)
                        _tabPage(
                          i + 2,
                          _visited.contains(shortcuts[i].label)
                              ? _shortcutTab(shortcuts[i])
                              : const SizedBox.shrink(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomNav(
            selected: navSelected,
            items: [
              NavItem(Icons.home_outlined, 'Home', () => _goTab(0)),
              for (var i = 0; i < shortcuts.length; i++)
                NavItem(
                  menuIcon(shortcuts[i].label, 2),
                  shortcuts[i].label,
                  () => _goShortcut(i),
                ),
              NavItem(Icons.apps_rounded, 'Menu', () => _openModules()),
            ],
          ),
        ),
      ),
    );
  }
}
