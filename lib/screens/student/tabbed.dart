import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'media.dart';
import 'student_common.dart';

/// Card with a date line, optional attachment, a title and a message that expands.
class ExpandCard extends StatefulWidget {
  const ExpandCard({super.key, required this.dateLabel, required this.title, required this.message, this.attachment = ''});
  final String dateLabel;
  final String title;
  final String message;
  final String attachment;

  @override
  State<ExpandCard> createState() => _ExpandCardState();
}

class _ExpandCardState extends State<ExpandCard> {
  bool _open = false;

  void _openAttachment() {
    final u = widget.attachment;
    if (looksLikeImage(u)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ZoomGallery(urls: [u], title: widget.title)));
    } else {
      openUrl(context, u);
    }
  }

  @override
  Widget build(BuildContext context) => KitCard(
        onTap: () => setState(() => _open = !_open),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.schedule, size: 15, color: Brand.muted),
            const SizedBox(width: 6),
            Expanded(child: Text(widget.dateLabel, style: const TextStyle(color: Brand.muted, fontSize: 12.5))),
            if (widget.attachment.isNotEmpty)
              IconButton(tooltip: 'Open attachment', constraints: const BoxConstraints(minWidth: 44, minHeight: 44), icon: const Icon(Icons.attach_file_rounded, color: Brand.primary), onPressed: _openAttachment),
          ]),
          Text(widget.title, maxLines: _open ? null : 1, overflow: _open ? null : TextOverflow.ellipsis, style: const TextStyle(color: Brand.primary, fontWeight: FontWeight.w800, fontSize: 15.5)),
          const SizedBox(height: 4),
          LinkText(widget.message, maxLines: _open ? null : 3),
          Align(alignment: Alignment.centerRight, child: Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Brand.muted)),
        ]),
      );
}

/// Circular and Event tabs.
Widget circularEventsScreen(ScreenArgs a) => DefaultTabController(
      length: 2,
      child: KitPage(
        title: 'Circular and events',
        child: Column(children: [
          const Material(color: Colors.white, child: TabBar(tabs: [Tab(text: 'Circular'), Tab(text: 'Event')])),
          Expanded(child: TabBarView(children: [_circularTab(a, 'circular'), _circularTab(a, 'event')])),
        ]),
      ),
    );

Widget _circularTab(ScreenArgs a, String action) => AsyncList(
      emptyText: action == 'event' ? 'No events have been announced.' : 'No circulars have been published.',
      emptyIcon: Icons.campaign_outlined,
      load: () => Sx.list(a, '/circular/fetchData', body: {'action': action}),
      itemBuilder: (c, r, i) => ExpandCard(dateLabel: 'Date : ${s(r['date_'])}', title: s(r['title']), message: s(r['message']), attachment: s(r['file_name'])),
    );

/// Portfolio: one tab per title, expandable cards for the entries.
class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) => KitPage(
        title: 'Portfolio',
        child: AsyncBody<List<Map<String, dynamic>>>(
          emptyText: 'Your portfolio is empty.',
          isEmpty: (d) => d.isEmpty,
          load: () => Sx.list(args, Sx.url(args, '/studentPortfolioAPI')),
          builder: (c, items, reload) {
            final titles = <String>[];
            for (final r in items) {
              final t = s(r['title']).isEmpty ? 'Other' : s(r['title']);
              if (!titles.contains(t)) titles.add(t);
            }
            return DefaultTabController(
              length: titles.length,
              child: Column(children: [
                Material(color: Colors.white, child: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final t in titles) Tab(text: t)])),
                Expanded(
                  child: TabBarView(children: [
                    for (final t in titles)
                      RefreshIndicator(
                        onRefresh: reload,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            for (final r in items.where((r) => (s(r['title']).isEmpty ? 'Other' : s(r['title'])) == t))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ExpandCard(dateLabel: 'Date : ${s(r['created_at'])}', title: s(r['title']), message: s(r['description']), attachment: s(r['file_name'])),
                              ),
                          ],
                        ),
                      ),
                  ]),
                ),
              ]),
            );
          },
        ),
      );
}

bool _noRecord(Map<String, dynamic> res) => LegacyApi.messageOf(res, '').toLowerCase().contains('no record');

/// Result PDFs for one term. Newer `POST /api/result/cbse-1t5-result/pdf` first (same controller
/// method as the legacy one; 404 `success:false` "No Record" means an empty list, not an error),
/// then the legacy `studentResultPDFAPI` once if the new call fails.
Future<List<Map<String, dynamic>>> _loadResultPdfs(ScreenArgs a, String termId) {
  final body = {'term_id': termId};
  return Sx.newThenLegacy<List<Map<String, dynamic>>>(
    'result_pdf',
    () async {
      final res = await a.api.post('/api/result/cbse-1t5-result/pdf', body: body);
      if (LegacyApi.ok(res)) return Sx.dataRows(res['data']);
      if (_noRecord(res)) return const [];
      throw ApiException(LegacyApi.messageOf(res));
    },
    () async {
      final res = await a.api.post('/studentResultPDFAPI', body: body);
      if (LegacyApi.ok(res)) return Sx.dataRows(res['data']);
      throw ApiException(LegacyApi.messageOf(res));
    },
  );
}

/// Result documents per term.
class ResultPdfScreen extends StatelessWidget {
  const ResultPdfScreen({super.key, required this.args});
  final ScreenArgs args;

  List<Map<String, dynamic>> get _terms {
    final t = args.session.raw['term_data'];
    final list = rows(t);
    return list.isEmpty ? [<String, dynamic>{'term_id': '', 'title': 'Results'}] : list;
  }

  @override
  Widget build(BuildContext context) {
    final terms = _terms;
    return DefaultTabController(
      length: terms.length,
      child: KitPage(
        title: titleOf(args, 'Results'),
        child: Column(children: [
          if (terms.length > 1)
            Material(color: Colors.white, child: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final t in terms) Tab(text: s(t['title']))])),
          Expanded(
            child: TabBarView(children: [
              for (final t in terms)
                AsyncList(
                  emptyText: 'No results have been published for this term.',
                  emptyIcon: Icons.picture_as_pdf_outlined,
                  load: () => _loadResultPdfs(args, s(t['term_id'])),
                  itemBuilder: (c, r, i) {
                    final termTitle = s(t['title']);
                    final parts = termTitle.split('-');
                    final badge = parts.length > 1 ? parts[1].trim() : (termTitle.isEmpty ? '' : termTitle[0]);
                    final link = s(r['pdf_link']);
                    return KitCard(
                      onTap: link.isEmpty ? null : () => openUrl(c, link),
                      child: Row(children: [
                        CircleAvatar(radius: 22, backgroundColor: Brand.primary, child: Text(badge, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(s(r['title']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                        if (link.isNotEmpty) const Icon(Icons.open_in_new_rounded, color: Brand.primary),
                      ]),
                    );
                  },
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Timetable with a Mon..Sun strip; today is selected first.
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  late String _day = DateFormat('EEE').format(DateTime.now());
  List<Map<String, dynamic>>? _items;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Sx.list(widget.args, Sx.url(widget.args, '/studentTimetableAPI'));
      if (mounted) _items = r;
    } on ApiException catch (e) {
      if (mounted) _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  static const _edge = [Color(0xFF4169E1), Color(0xFF0EA5A4), Color(0xFFF59E0B), Color(0xFFE11D74)];

  @override
  Widget build(BuildContext context) {
    final todays = (_items ?? const <Map<String, dynamic>>[]).where((r) => s(r['week_day']).toLowerCase().startsWith(_day.toLowerCase())).toList();
    return KitPage(
      title: titleOf(widget.args, 'Timetable'),
      child: Column(children: [
        SizedBox(
          height: 70,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              for (final d in _days)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: SizedBox(width: 38, child: Text(d, textAlign: TextAlign.center)),
                    selected: _day == d,
                    onSelected: (_) => setState(() => _day = d),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? KitMessage(icon: Icons.cloud_off_outlined, text: _error!, action: 'Try again', onAction: _load)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: todays.isEmpty
                          ? ListView(children: const [SizedBox(height: 60), KitMessage(icon: Icons.event_available_outlined, text: 'No periods are scheduled for this day.')])
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: todays.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (c, i) {
                                final r = todays[i];
                                final period = s(r['period_name']).isEmpty ? '${i + 1}' : s(r['period_name']);
                                final time = [time12(r['start_time']), time12(r['end_time'])].where((t) => t.isNotEmpty).join(' - ');
                                return KitCard(
                                  child: Row(children: [
                                    Container(width: 5, height: 46, decoration: BoxDecoration(color: _edge[i % 4], borderRadius: BorderRadius.circular(4))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(s(r['subject_name']), style: const TextStyle(color: Brand.primary, fontWeight: FontWeight.w800, fontSize: 15.5)),
                                        Text(s(r['teacher_name']), style: const TextStyle(color: Brand.muted, fontSize: 13)),
                                        if (time.isNotEmpty) Text(time, style: const TextStyle(fontSize: 12.5)),
                                      ]),
                                    ),
                                    Column(children: [
                                      const Text('Period', style: TextStyle(color: Brand.muted, fontSize: 11.5)),
                                      Text(period, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                    ]),
                                  ]),
                                );
                              },
                            ),
                    ),
        ),
      ]),
    );
  }
}
