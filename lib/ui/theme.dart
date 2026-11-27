import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens from the "Teach Connect LMS K12" canvas: navy app bar, indigo actions,
/// flat bordered cards (16), 12px controls, Poppins 400/500/600.
class Brand {
  Brand._();

  /// Kept for call sites that still ask; the design looks the same for every role.
  static bool student = false;

  /// True while the dark palette is showing. Set from the effective brightness (see `main.dart`), so the
  /// neutral colours below follow the Light / Dark / System choice. They are getters, not constants, so they
  /// cannot sit inside a `const` widget.
  static bool dark = false;

  static Color _p(int light, int darkValue) => Color(dark ? darkValue : light);

  static const navy = Color(0xFF0B1437); // app bar, hero, sign-in ground
  static const navy2 = Color(0xFF16235A); // raised on navy
  static const night = navy;
  static const primary = Color(0xFF4F46E5); // indigo: primary action
  static Color get primaryDark => _p(0xFF4338CA, 0xFFA5B4FC); // indigo text on a tint
  static Color get tint => _p(0xFFEEF0FF, 0xFF1E2347); // selected / icon tile
  static Color get tint1 => _p(0xFFE0E4FF, 0xFF2A3166);
  static const glow = primary;
  static const champagne = Color(0xFFB6BEE0); // muted text on navy

  static Color get surface => _p(0xFFF5F6FA, 0xFF0A0E1C); // page background
  static Color get card => _p(0xFFFFFFFF, 0xFF151B30); // cards, sheets, fields
  static Color get line => _p(0xFFE4E7F0, 0xFF252C45);
  static Color get border => _p(0xFFC5CCDB, 0xFF3A4363); // input border
  static Color get field => _p(0xFFEEF1F6, 0xFF1B2238); // neutral badge / segmented track

  static Color get ink => _p(0xFF0F172A, 0xFFE8ECF8);
  static Color get ink2 => _p(0xFF475569, 0xFFB4BDD4);
  static Color get ink3 => _p(0xFF586579, 0xFF94A0BC);
  static Color get text => ink;
  static Color get muted => ink3;
  static Color get light => ink3;
  static Color get secondary => primaryDark;

  static Color get ok => _p(0xFF047857, 0xFF34D399);
  static Color get ok0 => _p(0xFFD1FAE5, 0xFF0F3D31);
  static Color get warn => _p(0xFF92400E, 0xFFFBBF24);
  static Color get warn0 => _p(0xFFFEF3C7, 0xFF3F2F0B);
  static Color get err => _p(0xFFB91C1C, 0xFFF87171);
  static Color get err0 => _p(0xFFFEE2E2, 0xFF3F1620);
  static Color get info => _p(0xFF1D4ED8, 0xFF60A5FA);
  static Color get info0 => _p(0xFFDBEAFE, 0xFF12294F);
  static Color get green => ok;
  static Color get red => err;

  static const barColor = navy;
  static const onBar = Colors.white;

  static const heroGradient = LinearGradient(colors: [primary, primary]);

  static const softShadow = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Accent pairs (colour, tint) for tiles; the design keeps every icon indigo.
  static List<(Color, Color)> get accents => [(primaryDark, tint)];

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

/// The app theme for the light or the dark palette. The Brand colours are read while this builds, so the
/// flag is set for the duration and put back afterwards (MaterialApp builds both themes).
ThemeData buildTheme({bool student = false, bool dark = false}) {
  final previous = Brand.dark;
  Brand.dark = dark;
  try {
    return _buildTheme(student: student, dark: dark);
  } finally {
    Brand.dark = previous;
  }
}

ThemeData _buildTheme({required bool student, required bool dark}) {
  Brand.student = student;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.primary,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: Brand.primary,
    surface: Brand.card,
    onSurface: Brand.ink,
    outline: Brand.border,
    outlineVariant: Brand.line,
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
    brightness: dark ? Brightness.dark : Brightness.light,
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
      fillColor: Brand.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: Brand.ink3),
      labelStyle: TextStyle(color: Brand.ink2),
      floatingLabelStyle: TextStyle(
        color: Brand.primaryDark,
        fontWeight: FontWeight.w500,
      ),
      border: outline(Brand.border),
      enabledBorder: outline(Brand.border),
      focusedBorder: outline(Brand.primary, 2),
      errorBorder: outline(Brand.err, 2),
      focusedErrorBorder: outline(Brand.err, 2),
      errorStyle: TextStyle(color: Brand.err),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: Brand.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Brand.line,
        disabledForegroundColor: Brand.ink3,
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
        disabledForegroundColor: Brand.ink3,
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
        side: BorderSide(color: Brand.border),
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
      color: Brand.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Brand.line),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Brand.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Brand.card,
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
      backgroundColor: Brand.card,
      selectedColor: Brand.primary,
      side: BorderSide(color: Brand.line),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
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
    tabBarTheme: TabBarThemeData(
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
    dividerTheme: DividerThemeData(
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
  if (k.trim() == 'teach') return Icons.cast_for_education_outlined;
  const table = <String, IconData>{
    // Specific module names first, so they win over the broad words below.
    'subject': Icons.menu_book_outlined,
    'adaptive': Icons.psychology_alt_outlined,
    'virtual': Icons.video_camera_front_outlined,
    'social': Icons.diversity_3_outlined,
    'leaderboard': Icons.emoji_events_outlined,
    'portfolio': Icons.work_outline,
    'assignment': Icons.assignment_turned_in_outlined,
    'result': Icons.workspace_premium_outlined,
    'progress': Icons.trending_up_outlined,
    'achievement': Icons.military_tech_outlined,
    'holiday': Icons.beach_access_outlined,
    'remark': Icons.rate_review_outlined,
    'certificate': Icons.verified_outlined,
    'height': Icons.straighten_outlined,
    'infirmary': Icons.local_hospital_outlined,
    'vaccination': Icons.vaccines_outlined,
    'transport': Icons.directions_bus_outlined,
    'hostel': Icons.bed_outlined,
    'consent': Icons.how_to_vote_outlined,
    'photo': Icons.photo_library_outlined,
    'about': Icons.info_outline,
    'principal': Icons.school_outlined,
    'timing': Icons.access_time_outlined,
    'rules': Icons.gavel_outlined,
    'facilit': Icons.apartment_outlined,
    'reach': Icons.place_outlined,
    'resource': Icons.folder_copy_outlined,
    'diary': Icons.auto_stories_outlined,
    'marks': Icons.grading_outlined,
    'discipline': Icons.rule_outlined,
    'requisition': Icons.shopping_cart_checkout_outlined,
    'punch': Icons.fingerprint_outlined,
    'communication': Icons.forum_outlined,
    'notify': Icons.notifications_active_outlined,
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
