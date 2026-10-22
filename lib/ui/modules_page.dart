import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/feed.dart';
import '../core/menu_controller.dart';
import '../screens/screen_registry.dart';
import 'design.dart';
import 'theme.dart';

/// "All modules": everything the account's menu rights allow, searchable, one expandable
/// row per module (level 1) with its screens (level 2) underneath.
class ModulesPage extends StatefulWidget {
  const ModulesPage({super.key, this.focusSection});

  /// Open with this module expanded (set when coming from a "View all" link).
  final String? focusSection;

  @override
  State<ModulesPage> createState() => _ModulesPageState();
}

class _ModulesPageState extends State<ModulesPage> {
  final _search = TextEditingController();
  String _query = '';
  late Set<String> _open = {
    if (widget.focusSection != null) widget.focusSection!,
  };
  bool _seeded = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<AppMenuController>();
    final top = MediaQuery.paddingOf(context).top;
    final q = _query.trim().toLowerCase();

    final visible = <(FeedSection, List<FeedItem>)>[];
    for (final sec in menu.sections) {
      final items = q.isEmpty
          ? sec.items
          : sec.items.where((i) => i.label.toLowerCase().contains(q)).toList();
      if (items.isNotEmpty) visible.add((sec, items));
    }
    if (!_seeded && visible.isNotEmpty) {
      _seeded = true;
      if (_open.isEmpty) _open = {visible.first.$1.title};
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Brand.navy,
          padding: EdgeInsets.fromLTRB(20, top + 12, 16, 14),
          child: const Text(
            'All modules',
            style: TextStyle(
              fontSize: 18,
              height: 1.33,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, BottomNav.clearance(context)),
            children: [
              Rise(
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search menus',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF64748B),
                            ),
                            onPressed: () => setState(() {
                              _search.clear();
                              _query = '';
                            }),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (menu.loading && menu.sections.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Text(
                    q.isEmpty
                        ? (menu.error ??
                              'No modules are enabled for your account.')
                        : 'Nothing matches "$_query".',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Brand.ink3),
                  ),
                )
              else
                Rise(
                  delay: const Duration(milliseconds: 80),
                  child: SoftCard(
                    clip: true,
                    child: Column(
                      children: [
                        for (var i = 0; i < visible.length; i++)
                          _ModuleGroup(
                            title: visible[i].$1.title,
                            items: visible[i].$2,
                            first: i == 0,
                            expanded:
                                q.isNotEmpty ||
                                _open.contains(visible[i].$1.title),
                            onToggle: () => setState(() {
                              final t = visible[i].$1.title;
                              _open = {..._open};
                              _open.contains(t)
                                  ? _open.remove(t)
                                  : _open.add(t);
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                "Menus come from your school's access rights.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.33,
                  fontWeight: FontWeight.w500,
                  color: Brand.ink3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModuleGroup extends StatelessWidget {
  const _ModuleGroup({
    required this.title,
    required this.items,
    required this.first,
    required this.expanded,
    required this.onToggle,
  });
  final String title;
  final List<FeedItem> items;
  final bool first;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!first) const Divider(),
        Semantics(
          expanded: expanded,
          button: true,
          child: InkWell(
            onTap: onToggle,
            child: Container(
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  IconTile(menuIcon(title, 1)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? .5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Brand.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Column(children: [for (final it in items) _ScreenRow(item: it)])
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _ScreenRow extends StatelessWidget {
  const _ScreenRow({required this.item});
  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final available = hasScreen(context, item);
    return Opacity(
      opacity: available ? 1 : .5,
      child: InkWell(
        onTap: () => openFeedItem(context, item),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.fromLTRB(68, 8, 16, 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Brand.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Brand.ink3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
