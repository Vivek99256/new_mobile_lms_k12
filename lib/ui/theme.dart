import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens from the "Teach Connect LMS K12" canvas: navy app bar, indigo actions,
/// flat bordered cards (16), 12px controls, Poppins 400/500/600.
class Brand {
  Brand._();

  /// Kept for call sites that still ask; the design looks the same for every role.
  static bool student = false;

  static const navy = Color(0xFF0B1437); // app bar, hero, sign-in ground
  static const navy2 = Color(0xFF16235A); // raised on navy
  static const night = navy;
  static const primary = Color(0xFF4F46E5); // indigo: primary action
  static const primaryDark = Color(0xFF4338CA); // indigo 700: text on tint
  static const tint = Color(0xFFEEF0FF); // selected / icon tile
  static const tint1 = Color(0xFFE0E4FF);
  static const glow = primary;
  static const champagne = Color(0xFFB6BEE0); // muted text on navy

  static const surface = Color(0xFFF5F6FA);
  static const line = Color(0xFFE4E7F0);
  static const border = Color(0xFFC5CCDB); // input border
  static const field = Color(0xFFEEF1F6); // neutral badge / segmented track

  static const ink = Color(0xFF0F172A);
  static const ink2 = Color(0xFF475569);
  static const ink3 = Color(0xFF586579);
  static const text = ink;
  static const muted = ink3;
  static const light = ink3;
  static const secondary = primaryDark;

  static const ok = Color(0xFF047857);
  static const ok0 = Color(0xFFD1FAE5);
  static const warn = Color(0xFF92400E);
  static const warn0 = Color(0xFFFEF3C7);
  static const err = Color(0xFFB91C1C);
  static const err0 = Color(0xFFFEE2E2);
  static const info = Color(0xFF1D4ED8);
  static const info0 = Color(0xFFDBEAFE);
  static const green = ok;
  static const red = err;

  static const barColor = navy;
  static const onBar = Colors.white;

  static const heroGradient = LinearGradient(colors: [primary, primary]);

  static const softShadow = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Accent pairs (colour, tint) for tiles; the design keeps every icon indigo.
  static const accents = <(Color, Color)>[(primaryDark, tint)];

  static (Color, Color) accent(int i) => accents[0];
}

/// Rounded-square icon holder used by tiles and rows.
class IconBubble extends StatelessWidget {
  const IconBubble({
    super.key,
    required this.icon,
    required this.accent,
    this.size = 44,
  });
  final IconData icon;
  final (Color, Color) accent;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: accent.$2,
      borderRadius: BorderRadius.circular(size * 0.3),
    ),
    child: Icon(icon, color: accent.$1, size: size * 0.5),
  );
}

/// Navy band with white content, used for custom headers.
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.child,
    this.bottomRadius = 0,
    this.padding,
  });
  final Widget child;
  final double bottomRadius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Brand.navy,
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(bottomRadius),
      ),
    ),
    padding:
        padding ??
        EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 16, 20, 20),
    child: IconTheme(
      data: const IconThemeData(color: Colors.white),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: child,
      ),
    ),
  );
}

const kFont = 'Poppins';

ThemeData buildTheme({bool student = false}) {
  Brand.student = student;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.primary,
    primary: Brand.primary,
    surface: Colors.white,
  );
  final field = BorderRadius.circular(12);
  OutlineInputBorder outline(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: field,
    borderSide: BorderSide(color: c, width: w),
  );
  const btnText = TextStyle(
    fontFamily: kFont,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: kFont,
    colorScheme: scheme,
    scaffoldBackgroundColor: Brand.surface,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Brand.navy,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        fontFamily: kFont,
        fontSize: 18,
        height: 1.33,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) =>
          const Icon(Icons.chevron_left_rounded, size: 30),
      closeButtonIconBuilder: (_) => const Icon(Icons.close_rounded),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: Color(0xFF64748B)),
      labelStyle: const TextStyle(color: Brand.ink2),
      floatingLabelStyle: const TextStyle(
        color: Brand.primaryDark,
        fontWeight: FontWeight.w500,
      ),
      border: outline(Brand.border),
      enabledBorder: outline(Brand.border),
      focusedBorder: outline(Brand.primary, 2),
      errorBorder: outline(Brand.err, 2),
      focusedErrorBorder: outline(Brand.err, 2),
      errorStyle: const TextStyle(color: Brand.err),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: Brand.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Brand.line,
        disabledForegroundColor: const Color(0xFF64748B),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: field),
        textStyle: btnText,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Brand.line,
        disabledForegroundColor: const Color(0xFF64748B),
        minimumSize: const Size.fromHeight(48),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: field),
        textStyle: btnText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Brand.primaryDark,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: Color(0xFFC3C8F3)),
        shape: RoundedRectangleBorder(borderRadius: field),
        textStyle: btnText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Brand.primaryDark,
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(
          fontFamily: kFont,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Brand.line),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Brand.navy,
      contentTextStyle: const TextStyle(fontFamily: kFont, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: field),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: Brand.primary,
      side: const BorderSide(color: Brand.line),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(
        fontFamily: kFont,
        fontWeight: FontWeight.w500,
        color: Brand.ink2,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: kFont,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Brand.primaryDark,
      unselectedLabelColor: Brand.ink3,
      indicatorColor: Brand.primary,
      dividerColor: Brand.line,
      labelStyle: TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(
        fontFamily: kFont,
        fontWeight: FontWeight.w500,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Brand.line,
      space: 1,
      thickness: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Brand.primary,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Brand.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

/// Maps the menu API's `mdi mdi-*` icon strings onto Material icons.
IconData menuIcon(String? raw, int level) {
  final k = (raw ?? '').toLowerCase();
  const table = <String, IconData>{
    'attendance': Icons.how_to_reg_outlined,
    'homework': Icons.edit_note_outlined,
    'circular': Icons.campaign_outlined,
    'sms': Icons.sms_outlined,
    'notification': Icons.notifications_active_outlined,
    'leave': Icons.event_busy_outlined,
    'gallery': Icons.photo_library_outlined,
    'visitor': Icons.badge_outlined,
    'task': Icons.task_alt_outlined,
    'complain': Icons.report_gmailerrorred_outlined,
    'admission': Icons.person_add_alt_outlined,
    'inward': Icons.move_to_inbox_outlined,
    'outward': Icons.outbox_outlined,
    'fee': Icons.payments_outlined,
    'student': Icons.groups_outlined,
    'teacher': Icons.person_outline,
    'user': Icons.person_outline,
    'health': Icons.health_and_safety_outlined,
    'exam': Icons.quiz_outlined,
    'timetable': Icons.schedule_outlined,
    'proxy': Icons.swap_horiz_outlined,
    'report': Icons.bar_chart_outlined,
    'account': Icons.person_outline,
    'school': Icons.school_outlined,
    'cash': Icons.payments_outlined,
    'currency': Icons.payments_outlined,
    'calendar': Icons.calendar_month_outlined,
    'book': Icons.menu_book_outlined,
    'file': Icons.description_outlined,
    'chart': Icons.bar_chart_outlined,
    'message': Icons.chat_bubble_outline,
    'email': Icons.mail_outline,
    'bus': Icons.directions_bus_outlined,
    'library': Icons.local_library_outlined,
    'settings': Icons.settings_outlined,
    'cog': Icons.settings_outlined,
    'clipboard': Icons.assignment_outlined,
    'check': Icons.fact_check_outlined,
    'home': Icons.home_outlined,
    'hospital': Icons.medical_services_outlined,
    'phone': Icons.phone_outlined,
    'card': Icons.badge_outlined,
    'bank': Icons.account_balance_outlined,
    'dashboard': Icons.dashboard_outlined,
    'brain': Icons.psychology_outlined,
    'video': Icons.ondemand_video_outlined,
    'bell': Icons.notifications_outlined,
    'truck': Icons.local_shipping_outlined,
    'store': Icons.storefront_outlined,
    'bed': Icons.bed_outlined,
    'pencil': Icons.edit_outlined,
  };
  for (final e in table.entries) {
    if (k.contains(e.key)) return e.value;
  }
  return level == 1
      ? Icons.dashboard_customize_outlined
      : level == 2
      ? Icons.folder_open_outlined
      : Icons.article_outlined;
}
