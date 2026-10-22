import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'api_migration.dart';
import 'tk.dart';

/// Read-only lists: message, proxy, virtual classroom, resources, social, notification
/// report, calendar, timetable.

String time12(String hms) {
  final t = s(hms);
  if (t.isEmpty) return '';
  final d = DateTime.tryParse('2000-01-01T${t.length == 5 ? '$t:00' : t}');
  return d == null ? t : DateFormat('h:mm a').format(d);
}

Widget _title(String t) => Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Brand.text));

class TMessageScreen extends StatelessWidget {
  const TMessageScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) => ListPage(
        title: args.title.isEmpty ? 'Messages' : args.title,
        emptyText: 'No messages yet.',
        emptyIcon: Icons.chat_bubble_outline_rounded,
        load: () async {
          final res = await postOk(args.api, '/teacherAnnoucementAPI', body: {'annoucement_type': 'SMS'});
          return dataRows(res);
        },
        itemBuilder: (c, r, i) => KitCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (s(r['title']).isNotEmpty) _title(s(r['title'])),
            Text(s(r['message']).isNotEmpty ? s(r['message']) : s(r['description'])),
            if (s(r['created_at']).isNotEmpty) KV('Date', fmtDate(r['created_at'], out: 'dd MMM yyyy, hh:mm a')),
          ]),
        ),
      );
}

class ProxyScreen extends StatelessWidget {
  const ProxyScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) => RangeListPage(
        title: args.title.isEmpty ? 'Proxy' : args.title,
        emptyText: 'No proxy lectures in this date range.',
        load: (from, to) async {
          final res = await postOk(args.api, isAdmin(args) ? '/get_adminTodaysProxyListAPI' : '/get_proxy_master',
              body: {'from_date': ymd(from), 'to_date': ymd(to)});
          return dataRows(res);
        },
        itemBuilder: (c, r, i) => KitCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: _title(s(r['sub_name']))), Pill(fmtDate(r['proxy_date'], out: 'dd MMMM yyyy'))]),
            gap(6),
            KV('Teacher', s(r['teacher_name'])),
            KV('Proxy teacher', s(r['proxy_teacher_name'])),
            KV('Period', s(r['period_name'])),
            KV('Class', [s(r['standard_name']), s(r['division_name'])].where((e) => e.isNotEmpty).join(' - ')),
          ]),
        ),
      );
}

class VirtualClassroomScreen extends StatelessWidget {
  const VirtualClassroomScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) => ListPage(
        title: args.title.isEmpty ? 'Virtual classroom' : args.title,
        emptyText: 'No virtual classes are scheduled.',
        emptyIcon: Icons.videocam_outlined,
        load: () async => dataRows(await postOk(args.api, '/get_teacherVirtualClassroomAPI')),
        itemBuilder: (c, r, i) {
          final date = fmtDate(r['event_date'], out: 'dd-MM-yyyy');
          return KitCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: _title(s(r['subject_name']))),
                if (s(r['to_time']).isNotEmpty) Pill('Until ${time12(s(r['to_time']))}', color: const Color(0xFF047857)),
              ]),
              if (s(r['teacher_name']).isNotEmpty) Text('By ${s(r['teacher_name'])}', style: const TextStyle(color: Brand.muted)),
              gap(6),
              KV('When', '$date ${time12(s(r['from_time']))}'.trim()),
              KV('Class', s(r['standard_name'])),
              KV('Chapter', s(r['chapter_name'])),
              KV('Topic', s(r['topic_name'])),
              KV('Room', s(r['room_name'])),
              KV('Password', s(r['password'])),
              gap(8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
                  onPressed: s(r['url']).isEmpty ? null : () => openUrl(context, s(r['url'])),
                  icon: const Icon(Icons.video_call_rounded),
                  label: const Text('Join'),
                ),
              ),
            ]),
          );
        },
      );
}

class TeacherResourceScreen extends StatelessWidget {
  const TeacherResourceScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) => ListPage(
        title: args.title.isEmpty ? 'Resources' : args.title,
        emptyText: 'No resources have been shared yet.',
        emptyIcon: Icons.folder_open_rounded,
        load: () async => dataRows(await postOk(args.api, '/get_teacherResourceAPI')),
        itemBuilder: (c, r, i) => KitCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _title(s(r['title']))),
              attachmentButton(c, s(r['file_name'])),
            ]),
            if (s(r['teacher_name']).isNotEmpty) Text('By ${s(r['teacher_name'])}', style: const TextStyle(color: Brand.muted)),
            gap(4),
            KV('Subject', s(r['subject_name'])),
            KV('Chapter', s(r['chapter_name'])),
            KV('Topic', s(r['topic_name'])),
          ]),
        ),
      );
}

class SocialCollaborativeScreen extends StatelessWidget {
  const SocialCollaborativeScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) => ListPage(
        title: args.title.isEmpty ? 'Social collaborative' : args.title,
        emptyText: 'No student doubts to show.',
        emptyIcon: Icons.forum_outlined,
        load: () async => dataRows(await postOk(args.api, '/teacherSocialCollabrativeAPI')),
        itemBuilder: (c, r, i) {
          final convo = rows(r['ConversationData']);
          return KitCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                PersonAvatar(url: s(r['image']), name: s(r['student_name'])),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${s(r['student_name'])} asked', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(fmtDate(r['created_at'], out: 'MMM dd, yyyy hh:mm a'), style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                  ]),
                ),
              ]),
              gap(8),
              if (s(r['title']).isNotEmpty) _title(s(r['title'])),
              Text(s(r['description'])),
              attachmentButton(c, s(r['file_name'])),
              if (convo.isNotEmpty) ...[
                const Divider(height: 22),
                for (final x in convo)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      PersonAvatar(url: s(x['image']), name: s(x['student_name']), radius: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${s(x['student_name'])} replied', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          if (s(x['message']).isNotEmpty) Text(s(x['message']), style: const TextStyle(fontSize: 13)),
                          Text(s(x['comment_date']), style: const TextStyle(color: Brand.muted, fontSize: 12)),
                        ]),
                      ),
                    ]),
                  ),
              ],
            ]),
          );
        },
      );
}

class NotificationReportScreen extends StatelessWidget {
  const NotificationReportScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) => RangeListPage(
        title: args.title.isEmpty ? 'Notification report' : args.title,
        emptyText: 'No notifications were sent in this date range.',
        load: (from, to) async {
          final query = {'from_date': ymd(from), 'to_date': ymd(to)};
          return readNewThenLegacy(
            't_notification_report',
            () async => adaptNotificationRows(dataRows(await getNew(args.api, '/api/easy_com/reports/notification', query: query))),
            () async => dataRows(await getOk(args.api, '/easy_com/notification_report/create', query: query)),
          );
        },
        itemBuilder: (c, r, i) => KitCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _title(s(r['stu_name']))),
              if (s(r['NOTIFICATION_TYPE']).isNotEmpty) Pill(s(r['NOTIFICATION_TYPE'])),
            ]),
            Text('${s(r['std_name'])} - ${s(r['div_name'])}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
            gap(6),
            Text(s(r['NOTIFICATION_DESCRIPTION'])),
            gap(4),
            Text(s(r['NOTOFICATION_DATE']), style: const TextStyle(color: Brand.muted, fontSize: 12)),
          ]),
        ),
      );
}

// ---------------------------------------------------------------------------------------
// Calendar (filtered list) and timetable
// ---------------------------------------------------------------------------------------

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  ClassSel? cls;
  final ctrl = AsyncListController();
  final keyword = TextEditingController();

  @override
  void dispose() {
    keyword.dispose();
    super.dispose();
  }

  Color _typeColor(String t) {
    final l = t.toLowerCase();
    if (l.contains('holiday')) return const Color(0xFFDC2626);
    if (l.contains('event')) return const Color(0xFF047857);
    return Brand.primary;
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    return ListPage(
      title: a.title.isEmpty ? 'Calendar' : a.title,
      controller: ctrl,
      emptyText: cls?.stdId == null ? 'Select a standard to see its calendar.' : 'No calendar events found.',
      emptyIcon: Icons.event_outlined,
      header: Column(children: [
        ClassPicker(
          api: a.api,
          admin: isAdmin(a),
          withDivision: false,
          autoSelectFirst: true,
          onChanged: (c) {
            cls = c;
            ctrl.reload();
          },
        ),
        gap(),
        TextField(
          controller: keyword,
          decoration: const InputDecoration(labelText: 'Search by keyword', prefixIcon: Icon(Icons.search_rounded)),
          onChanged: (_) => ctrl.reload(),
        ),
      ]),
      load: () async {
        if (cls?.stdId == null) return const [];
        final res = await postOk(a.api, '/calendar/TeacherFetchData', body: {'standard_id': cls!.stdId});
        final k = keyword.text.trim().toLowerCase();
        return [
          for (final r in dataRows(res))
            if (k.isEmpty || s(r['title']).toLowerCase().contains(k)) r,
        ];
      },
      itemBuilder: (c, r, i) => KitCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (s(r['event_type']).isNotEmpty) Pill(s(r['event_type']), color: _typeColor(s(r['event_type']))),
            const Spacer(),
            Text(fmtDate(r['school_date'], out: 'dd MMMM yyyy'), style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
          ]),
          gap(6),
          _title(s(r['title'])),
          if (s(r['description']).isNotEmpty) Text(s(r['description'])),
        ]),
      ),
    );
  }
}

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  static const days = [('M', 'Mon'), ('T', 'Tue'), ('W', 'Wed'), ('H', 'Thu'), ('F', 'Fri'), ('S', 'Sat')];
  // DateTime.weekday: Mon=1 ... Sat=6, Sun=7.
  late String day = DateTime.now().weekday >= 7 ? '' : days[DateTime.now().weekday - 1].$1;
  final ctrl = AsyncListController();
  List<Map<String, dynamic>> all = [];

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    return ListPage(
      title: a.title.isEmpty ? 'Timetable' : a.title,
      controller: ctrl,
      emptyText: day.isEmpty ? 'No lectures on Sunday.' : 'No lectures on this day.',
      emptyIcon: Icons.schedule_rounded,
      header: Row(children: [
        for (final d in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                showCheckmark: false,
                label: SizedBox(width: double.infinity, child: Text(d.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5))),
                labelPadding: EdgeInsets.zero,
                selected: day == d.$1,
                onSelected: (_) {
                  setState(() => day = d.$1);
                  ctrl.reload();
                },
              ),
            ),
          ),
      ]),
      load: () async {
        all = dataRows(await postOk(a.api, '/teacherTimetableAPI'));
        return [for (final r in all) if (s(r['week_day']).toUpperCase() == day) r];
      },
      itemBuilder: (c, r, i) => KitCard(
        child: Row(children: [
          Expanded(flex: 2, child: Text(s(r['periodname']), style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.primary))),
          Expanded(flex: 4, child: Text(s(r['lectures']), style: const TextStyle(fontSize: 14))),
        ]),
      ),
    );
  }
}
