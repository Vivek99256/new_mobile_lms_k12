import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/auth_controller.dart';
import 'core/config.dart';
import 'core/feed.dart';
import 'core/menu_controller.dart';
import 'core/updater.dart';
import 'ui/home_shell.dart';
import 'ui/login_page.dart';
import 'ui/splash_page.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthController(ApiClient())..restore();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => AppMenuController(auth)),
        ChangeNotifierProvider(create: (_) => UpdateService()),
      ],
      child: const LmsApp(),
    ),
  );
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
    final ready = _splashDone && status != AuthStatus.unknown;
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(student: student),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOut,
        child: !ready
            ? const SplashPage(key: ValueKey('splash'))
            : (status == AuthStatus.signedIn
                ? const HomeShell(key: ValueKey('home'))
                : const LoginPage(key: ValueKey('login'))),
      ),
    );
  }
}
