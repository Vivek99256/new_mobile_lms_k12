import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:new_mobile_lms_k12/ui/app_loader.dart';
import 'package:new_mobile_lms_k12/ui/theme.dart';

void main() {
  testWidgets('the loading animation is bundled and plays (no fallback spinner)', (t) async {
    await t.pumpWidget(MaterialApp(theme: buildTheme(), home: const Scaffold(body: AppLoader(label: 'Loading'))));
    // Let the bundled JSON load and decode.
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(LottieBuilder), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'the asset failed to load, so the fallback spinner showed');
    expect(find.text('Loading'), findsOneWidget);
  });

  testWidgets('the loading animation also builds on the dark palette', (t) async {
    await t.pumpWidget(MaterialApp(theme: buildTheme(dark: true), themeMode: ThemeMode.dark, home: const Scaffold(body: AppLoader())));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
