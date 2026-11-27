import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'theme.dart';

/// The app's loading state: a full-screen study scene (graduation cap, books, flask).
///
/// While it is on screen it covers the WHOLE screen (app bar and bottom bar included) with white in Light mode
/// and black in Dark mode, so nothing else shows through while data loads. It is drawn in the root overlay, so a
/// screen only has to put an `AppLoader()` where its content would be.
///
/// It only covers the screen while the widget is actually in view: not while its route is under another screen,
/// and not on a tab that is kept alive off-screen. It stands still when the phone has animations turned off, and
/// falls back to a plain spinner if the animation file cannot be read, so a loading screen is never blank.
class AppLoader extends StatefulWidget {
  const AppLoader({super.key, this.label});

  /// Optional line under the animation ("Loading your modules...").
  final String? label;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  final _portal = OverlayPortalController();
  bool _active = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inView = TickerMode.valuesOf(context).enabled && (ModalRoute.of(context)?.isCurrent ?? true);
    _active = inView;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_active && !_portal.isShowing) {
        _portal.show();
      } else if (!_active && _portal.isShowing) {
        _portal.hide();
      }
    });
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayLocation: OverlayChildLocation.rootOverlay,
    overlayChildBuilder: (overlayContext) => Positioned.fill(child: _LoaderScreen(label: widget.label, owner: context)),
    child: const SizedBox.shrink(),
  );
}

class _LoaderScreen extends StatelessWidget {
  const _LoaderScreen({required this.owner, this.label});
  final BuildContext owner;
  final String? label;

  static const _asset = 'assets/animations/education_loader.json';

  @override
  Widget build(BuildContext context) {
    final dark = Brand.dark;
    final media = MediaQuery.of(context);
    final side = media.size.shortestSide;
    // The scene fills about three quarters of its canvas, so a canvas a little wider than the screen puts the scene at
    // about 80% of the width: clearly larger than before, and nowhere near the edges.
    final canvas = side * 1.06;
    final canBack = owner.mounted && Navigator.canPop(owner);

    return Semantics(
      label: label ?? 'Loading',
      liveRegion: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: media.disableAnimations ? Duration.zero : const Duration(milliseconds: 180),
        builder: (_, v, child) => Opacity(opacity: v, child: child),
        child: Material(
          color: dark ? Colors.black : Colors.white,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: side * 0.92,
                      height: side * 0.92,
                      decoration: BoxDecoration(
                        // The illustration is drawn for a light ground, so it sits on a light plate in Dark mode.
                        color: dark ? const Color(0xFFF4F6FF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: OverflowBox(
                        maxWidth: canvas,
                        maxHeight: canvas,
                        child: Lottie.asset(
                          _asset,
                          width: canvas,
                          height: canvas,
                          fit: BoxFit.contain,
                          animate: !media.disableAnimations,
                          repeat: true,
                          errorBuilder: (context, error, stack) => const Center(
                            child: SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3)),
                          ),
                        ),
                      ),
                    ),
                    if (label != null) ...[
                      const SizedBox(height: 16),
                      Text(label!, style: TextStyle(fontSize: 14, height: 1.3, color: dark ? Colors.white70 : Brand.ink3)),
                    ],
                  ],
                ),
              ),
              if (canBack)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: IconButton(
                      tooltip: 'Back',
                      icon: Icon(Icons.arrow_back_rounded, color: dark ? Colors.white : Brand.ink),
                      onPressed: () => Navigator.maybePop(owner),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
