import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/auth_controller.dart';
import 'core/config.dart';
import 'core/feed.dart';
import 'core/menu_controller.dart';
import 'core/mobile_auth.dart';
import 'core/theme_controller.dart';
import 'core/updater.dart';
import 'ui/home_shell.dart';
import 'ui/mobile_login_page.dart';
import 'ui/splash_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthController(ApiClient())..restore();
  // The saved Light / Dark / System choice is read first, so the first frame already looks right.
  final themeController = ThemeController();
  await themeController.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: themeController),
        Provider(create: (_) => MobileAuthService(auth.api)),
        ChangeNotifierProvider(create: (_) => AppMenuController(auth)),
        ChangeNotifierProvider(create: (_) => UpdateService()),
      ],
      child: const LmsApp(),
    ),
  );
}

bool? _lastDark;

void _rebuildEverything() {
  void mark(Element e) {
    e.markNeedsBuild();
    e.visitChildren(mark);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(mark);
}

class LmsApp extends StatefulWidget {
  const LmsApp({super.key});

  @override
  State<LmsApp> createState() => _LmsAppState();
}

class _LmsAppState extends State<LmsApp> {
  /// The splash stays up at least this long so its animation can play out.
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(SplashPage.minimum, () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthController, AuthStatus>((a) => a.status);
    final student = context.select<AuthController, bool>(
        (a) => FeedRepository.isStudentProfile(a.session?.userProfileName ?? ''));
    final mode = context.select<ThemeController, ThemeMode>((c) => c.mode);
    // Switching to another profile on the same number must start the home again, or the tabs of the last profile stay.
    final who = context.select<AuthController, String>((a) => '${a.session?.userProfileId}:${a.session?.userId}');
    final ready = _splashDone && status != AuthStatus.unknown;
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(student: student),
      darkTheme: buildTheme(student: student, dark: true),
      themeMode: mode,
      // The Brand colours follow the brightness that is actually showing (Light, Dark, or the phone's setting).
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        Brand.dark = isDark;
        // A const widget is not rebuilt when its parent is, so one that reads a Brand colour in build() would keep the
        // old look. When the brightness really changes, mark every element dirty once (what a hot reload does).
        if (_lastDark != null && _lastDark != isDark) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildEverything());
        }
        _lastDark = isDark;
        return child ?? const SizedBox.shrink();
      },
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOut,
        child: !ready
            ? const SplashPage(key: ValueKey('splash'))
            : (status == AuthStatus.signedIn
                ? HomeShell(key: ValueKey('home:$who'))
                : const MobileLoginPage(key: ValueKey('login'))),
      ),
    );
  }
}
