import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_controller.dart';
import '../core/feed.dart';
import '../core/legacy_api.dart';
import '../core/menu_controller.dart';
import '../core/native_target.dart';
import '../screens/kit/kit.dart' show rows, s;
import '../screens/screen_registry.dart';
import 'design.dart';
import 'native_screens.dart';
import 'profile_page.dart';
import 'theme.dart';

enum HomeRole { student, teacher, admin }

HomeRole roleOf(String profileName) {
  final p = profileName.trim().toLowerCase();
  if (p == 'student') return HomeRole.student;
  if (p == 'teacher') return HomeRole.teacher;
  return HomeRole.admin;
}

String _greeting() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
}

/// "Class 8 · Division A" from the student's academic row, when the login response has one.
String _studentClass(Map<String, dynamic> raw) {
  final academic =
      rows(raw['student_academic']).firstOrNull ?? const <String, dynamic>{};
  String pick(List<String> keys) {
    for (final k in keys) {
      final v = s(raw[k]).isNotEmpty ? s(raw[k]) : s(academic[k]);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  final std = pick(['std_name', 'standard_name']);
  final div = pick(['division', 'division_name', 'section_name']);
  final roll = pick(['roll_no']);
  return [
    if (std.isNotEmpty) 'Class $std',
    if (div.isNotEmpty) 'Division $div',
    if (roll.isNotEmpty) 'Roll no. $roll',
  ].join(' · ');
}

/// Home: navy header with the date and greeting, a stats card that overlaps it, then the
/// dashboard link, quick actions and a peek at each menu section.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onOpenModules});

  /// Switches to the Modules tab, optionally focused on one section.
  final void Function([String? section]) onOpenModules;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ({num previous, num current})? _fees;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFees());
  }

  /// Students see what they owe (the old `pending_fees` call).
  Future<void> _loadFees() async {
    final session = context.read<AuthController>().session;
    if (session == null || roleOf(session.userProfileName) != HomeRole.student) {
      return;
    }
    try {
      final res = await LegacyApi(session).get('/pending_fees');
      if ('${res['api_status']}' == '1' && mounted) {
        setState(
          () => _fees = (
            previous: num.tryParse('${res['previous_fees'] ?? 0}') ?? 0,
            current: num.tryParse('${res['current_fees'] ?? 0}') ?? 0,
          ),
        );
      }
    } on ApiException {
      // the fees summary is optional
    }
  }

  Future<void> _refresh() async {
    await Future.wait([context.read<AppMenuController>().load(), _loadFees()]);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthController>().session;
    final menu = context.watch<AppMenuController>();
    if (session == null) return const SizedBox.shrink();
    final role = roleOf(session.userProfileName);
    final top = MediaQuery.paddingOf(context).top;

    final quick = [
      for (final e in menu.index)
        if (hasScreen(context, e.item)) e.item,
    ].take(7).toList();

    final owes = _fees != null && (_fees!.previous > 0 || _fees!.current > 0);
    final dashTitle = switch (role) {
      HomeRole.admin => 'School overview',
      HomeRole.teacher => 'Teaching overview',
      HomeRole.student => 'My learning',
    };

    return RefreshIndicator(
      onRefresh: _refresh,
      edgeOffset: top + 40,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Rise(
            offset: 0,
            child: _Header(role: role, top: top),
          ),
          // The cards ride up over the navy header by 44px.
          Transform.translate(
            offset: const Offset(0, -44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Rise(
                    delay: const Duration(milliseconds: 60),
                    child: _Stats(role: role, menu: menu, fees: _fees),
                  ),
                  const SizedBox(height: 20),
                  if (role == HomeRole.student && owes) ...[
                    Rise(
                      child: _LinkCard(
                        icon: Icons.currency_rupee_rounded,
                        title: 'Fees due ₹${_fees!.current + _fees!.previous}',
                        sub:
                            'Previous ₹${_fees!.previous} · Current ₹${_fees!.current}',
                        warn: true,
                        onTap: () => openFeedItem(
                          context,
                          const FeedItem(
                            label: 'Fees',
                            iconUrl: '',
                            api: '',
                            apiParam: '',
                            screenName: 'fees',
                            renderType: 'native',
                            webUrl: '',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Rise(
                    delay: const Duration(milliseconds: 120),
                    child: _LinkCard(
                      icon: Icons.space_dashboard_outlined,
                      title: dashTitle,
                      sub: 'Open your dashboard',
                      onTap: () => openTarget(
                        context,
                        'Dashboard',
                        const NativeTarget.dashboard(),
                      ),
                    ),
                  ),
                  if (quick.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Rise(
                      delay: const Duration(milliseconds: 180),
                      child: _QuickActions(
                        items: quick,
                        onAll: () => widget.onOpenModules(),
                      ),
                    ),
                  ],
                  if (menu.loading && menu.sections.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (menu.sections.isEmpty)
                    _Empty(
                      message:
                          menu.error ??
                          'No mobile menus are enabled for your role. Ask your administrator to grant access.',
                      onRetry: menu.load,
                    )
                  else
                    for (var i = 0; i < menu.sections.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Rise(
                          delay: Duration(
                            milliseconds: 240 + 70 * i.clamp(0, 4),
                          ),
                          child: _SectionPeek(
                            section: menu.sections[i],
                            onViewAll: () =>
                                widget.onOpenModules(menu.sections[i].title),
                          ),
                        ),
                      ),
                  SizedBox(height: BottomNav.clearance(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.role, required this.top});
  final HomeRole role;
  final double top;

  @override
  Widget build(BuildContext context) {
    final session = context.read<AuthController>().session!;
    final first = session.name.trim().split(RegExp(r'\s+')).first;
    final sub = switch (role) {
      HomeRole.student => _studentClass(session.raw),
      _ =>
        (session.mobileSyear ?? '').isEmpty
            ? ''
            : 'Academic year ${session.mobileSyear}',
    };
    return Container(
      color: Brand.navy,
      padding: EdgeInsets.fromLTRB(20, top + 12, 16, 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEE, d MMM yyyy').format(DateTime.now()),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.33,
                        fontWeight: FontWeight.w500,
                        color: Brand.champagne,
                      ),
                    ),
                    Text(
                      '${_greeting()}, $first',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1.36,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Open profile',
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  ),
                  child: Avatar(
                    name: session.name,
                    imageUrl: session.imageUrl,
                    size: 44,
                  ),
                ),
              ),
            ],
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(sub, style: const TextStyle(color: Brand.champagne)),
          ],
        ],
      ),
    );
  }
}

/// Round indigo avatar: the photo when it loads, otherwise initials.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.imageUrl, this.size = 44});
  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : (parts.length == 1 ? parts.first[0] : parts.first[0] + parts.last[0])
              .toUpperCase();
    final fallback = Center(
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: size * .32,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Brand.primary,
        shape: BoxShape.circle,
      ),
      child: imageUrl == null || imageUrl!.isEmpty
          ? fallback
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

/// Three real figures from the signed-in account: modules, sections, and for a student
/// what is owed.
class _Stats extends StatelessWidget {
  const _Stats({required this.role, required this.menu, required this.fees});
  final HomeRole role;
  final AppMenuController menu;
  final ({num previous, num current})? fees;

  @override
  Widget build(BuildContext context) {
    Widget cell(String value, String label, {Color? color, int? count}) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            children: [
              CountUp(
                value: count ?? 0,
                builder: (v) => Text(
                  count == null ? value : '$v',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.33,
                    fontWeight: FontWeight.w600,
                    color: color ?? Brand.ink,
                  ),
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.33,
                  fontWeight: FontWeight.w500,
                  color: Brand.ink3,
                ),
              ),
            ],
          ),
        );
    final session = context.read<AuthController>().session!;
    final owed = fees == null ? null : fees!.current + fees!.previous;
    return SoftCard(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cell('', 'Modules', count: menu.index.length)),
            const VerticalDivider(width: 1, color: Brand.line),
            Expanded(child: cell('', 'Sections', count: menu.sections.length)),
            const VerticalDivider(width: 1, color: Brand.line),
            Expanded(
              child: role == HomeRole.student
                  ? cell(
                      owed == null ? '—' : '₹$owed',
                      'Fees due',
                      color: (owed ?? 0) > 0 ? Brand.warn : null,
                    )
                  : cell(
                      (session.mobileSyear ?? '—').split(' ').first,
                      'Academic year',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    this.warn = false,
  });
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final bool warn;

  @override
  Widget build(BuildContext context) => SoftCard(
    onTap: onTap,
    color: warn ? const Color(0xFFFFFBEB) : Brand.tint,
    borderColor: warn ? const Color(0xFFF3D9A4) : const Color(0xFFC3C8F3),
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        IconTile(
          icon,
          size: 48,
          radius: 14,
          fg: Colors.white,
          bg: warn ? Brand.warn : Brand.primary,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.33,
                  fontWeight: FontWeight.w500,
                  color: Brand.ink2,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          color: warn ? Brand.warn : Brand.primaryDark,
        ),
      ],
    ),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.items, required this.onAll});
  final List<FeedItem> items;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    Widget tile(
      IconData icon,
      String label,
      VoidCallback onTap, {
      bool neutral = false,
    }) => Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: neutral ? Brand.field : Brand.tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: neutral ? Brand.ink2 : Brand.primaryDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.33,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final cells = <Widget>[
      for (final it in items.take(7))
        tile(menuIcon(it.label, 2), it.label, () => openFeedItem(context, it)),
      tile(Icons.grid_view_rounded, 'All modules', onAll, neutral: true),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading('Quick actions'),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 8,
          mainAxisExtent: 92,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          children: cells,
        ),
      ],
    );
  }
}

/// One section of the menu as a heading and a list card of its first few screens.
class _SectionPeek extends StatelessWidget {
  const _SectionPeek({required this.section, required this.onViewAll});
  final FeedSection section;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final shown = section.items.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(section.title, action: 'View all', onAction: onViewAll),
        SoftCard(
          clip: true,
          child: Column(
            children: [
              for (var i = 0; i < shown.length; i++)
                ModuleRow(item: shown[i], last: i == shown.length - 1),
            ],
          ),
        ),
      ],
    );
  }
}

/// A menu screen as a list row: icon tile, name, chevron.
class ModuleRow extends StatelessWidget {
  const ModuleRow({super.key, required this.item, this.last = false});
  final FeedItem item;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final available = hasScreen(context, item);
    return Opacity(
      opacity: available ? 1 : .5,
      child: InkWell(
        onTap: () => openFeedItem(context, item),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: Brand.line)),
          ),
          child: Row(
            children: [
              IconTile(menuIcon(item.label, 2)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Brand.ink3),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/images/nodatafound.png', height: 120),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Brand.ink2),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
