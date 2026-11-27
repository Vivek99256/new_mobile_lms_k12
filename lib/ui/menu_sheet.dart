import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/feed.dart';
import '../core/menu_controller.dart';
import '../screens/screen_registry.dart';
import 'theme.dart';

/// The app menu: a bottom sheet with search, category chips and a grid of coloured icons.
/// It lists exactly what the signed-in role was granted in Roles & Access (nothing else), so
/// a module an admin removes disappears the next time the menu loads.
Future<void> showMenuSheet(BuildContext context, {String? section}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x80101830),
    builder: (_) => _MenuSheet(initialSection: section, outer: context),
  );
}

const _gradients = <(Color, Color)>[
  (Color(0xFF34D399), Color(0xFF047857)),
  (Color(0xFF60A5FA), Color(0xFF1D4ED8)),
  (Color(0xFFA78BFA), Color(0xFF6D28D9)),
  (Color(0xFFFB923C), Color(0xFFC2410C)),
  (Color(0xFF2DD4BF), Color(0xFF0F766E)),
  (Color(0xFF818CF8), Color(0xFF4338CA)),
  (Color(0xFF38BDF8), Color(0xFF0369A1)),
  (Color(0xFFF472B6), Color(0xFFBE185D)),
  (Color(0xFFFBBF24), Color(0xFFB45309)),
  (Color(0xFF4ADE80), Color(0xFF15803D)),
  (Color(0xFFF87171), Color(0xFFB91C1C)),
  (Color(0xFFFB7185), Color(0xFFBE123C)),
];

/// A stable colour per module name, so a module keeps its colour wherever it appears.
(Color, Color) moduleGradient(String label) {
  var h = 0;
  for (final c in label.toLowerCase().codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _gradients[h % _gradients.length];
}

class _MenuSheet extends StatefulWidget {
  const _MenuSheet({required this.outer, this.initialSection});
  final BuildContext outer;
  final String? initialSection;

  @override
  State<_MenuSheet> createState() => _MenuSheetState();
}

class _MenuSheetState extends State<_MenuSheet> {
  final _search = TextEditingController();
  late String _chip = widget.initialSection ?? 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<AppMenuController>();
    final sections = menu.sections;
    if (_chip != 'All' && !sections.any((s) => s.title == _chip)) _chip = 'All';
    final q = _search.text.trim().toLowerCase();

    final items = <FeedItem>[
      for (final s in sections)
        if (_chip == 'All' || s.title == _chip)
          for (final i in s.items)
            if (q.isEmpty || i.label.toLowerCase().contains(q)) i,
    ];
    final total = sections.fold<int>(0, (n, s) => n + s.items.length);

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: Brand.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [BoxShadow(color: Color(0x59101830), blurRadius: 40, offset: Offset(0, -12))],
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: const Color(0x38101830), borderRadius: BorderRadius.circular(9)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'All modules',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -.4, color: Brand.ink),
                  ),
                  const Spacer(),
                  Text('$total available', style: TextStyle(fontSize: 12, color: Brand.ink3)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search modules',
                  filled: true,
                  fillColor: Brand.field,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF7B86A0)),
                  suffixIcon: q.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => setState(_search.clear),
                        ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Brand.primary, width: 1.4),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: [
                  for (final c in ['All', ...sections.map((s) => s.title)])
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: _chip == c,
                        onSelected: (_) => setState(() => _chip = c),
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _chip == c ? Colors.white : Brand.ink2,
                        ),
                        backgroundColor: Brand.field,
                        selectedColor: Brand.ink,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: items.isEmpty
                  ? ListView(
                      controller: scroll,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
                          child: Text(
                            menu.loading && sections.isEmpty
                                ? 'Loading your modules…'
                                : q.isNotEmpty
                                ? 'Nothing matches "${_search.text.trim()}".'
                                : (menu.error ?? 'No modules are enabled for your account yet. Ask your admin to grant access.'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Brand.ink3, height: 1.4),
                          ),
                        ),
                      ],
                    )
                  : GridView.builder(
                      controller: scroll,
                      padding: EdgeInsets.fromLTRB(10, 10, 10, 24 + MediaQuery.paddingOf(context).bottom),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 2,
                        mainAxisExtent: 98,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _Tile(
                        item: items[i],
                        onTap: () {
                          Navigator.of(context).pop();
                          openFeedItem(widget.outer, items[i]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item, required this.onTap});
  final FeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = moduleGradient(item.label);
    return Semantics(
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [g.$1, g.$2]),
                boxShadow: [BoxShadow(color: g.$2.withValues(alpha: .35), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: Icon(menuIcon(item.label, 2), color: Colors.white, size: 28),
            ),
            const SizedBox(height: 7),
            Text(
              item.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, height: 1.15, fontWeight: FontWeight.w700, color: Brand.ink),
            ),
          ],
        ),
      ),
    );
  }
}
