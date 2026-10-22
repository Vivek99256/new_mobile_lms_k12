import 'package:flutter/material.dart';

import '../core/config.dart';
import 'design.dart';
import 'theme.dart';

/// Shown while the stored session is restored: the app mark on navy.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  /// Keeps the splash from flashing past when the session restores instantly.
  static const minimum = Duration(milliseconds: 900);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Brand.navy,
    body: Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 700),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(scale: .8 + .2 * v, child: child),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LogoTile(size: 72),
            const SizedBox(height: 16),
            const Text(
              AppConfig.appName,
              style: TextStyle(
                fontSize: 26,
                height: 1.31,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -.2,
              ),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Brand.champagne,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
