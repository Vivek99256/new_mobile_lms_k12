import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'student_common.dart';

// ---------------------------------------------------------------------------------------
// Notification hub
// ---------------------------------------------------------------------------------------

Widget notificationHubScreen(ScreenArgs a) => SimpleList(
      args: a,
      title: titleOf(a, 'Notification hub'),
      url: Sx.url(a, '/notificationHubAPI'),
      silent: true,
      body: {'mobile_no': Sx.raw(a, 'mobile').isNotEmpty ? Sx.raw(a, 'mobile') : Sx.raw(a, 'mobile_no')},
      emptyText: 'No notifications yet.',
      emptyIcon: Icons.notifications_none_rounded,
      itemBuilder: (c, r, i) {
        final img = s(r['image']);
        return KitCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: img.isEmpty
                  ? IconBubble(icon: Icons.notifications_active_outlined, accent: Brand.accent(i), size: 48)
                  : Image.network(img, width: 48, height: 48, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => IconBubble(icon: Icons.notifications_active_outlined, accent: Brand.accent(i), size: 48)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s(r['NOTIFICATION_TYPE']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                LinkText(s(r['NOTIFICATION_DESCRIPTION'])),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.schedule, size: 14, color: Brand.muted),
                  const SizedBox(width: 4),
                  Text(relativeTime(r['NOTIFICATION_DATE']), style: const TextStyle(color: Brand.muted, fontSize: 12)),
                ]),
              ]),
            ),
          ]),
        );
      },
    );

// ---------------------------------------------------------------------------------------
// Virtual classroom
// ---------------------------------------------------------------------------------------

Widget virtualClassroomScreen(ScreenArgs a) => SimpleList(
      args: a,
      title: 'Virtual classroom',
      url: Sx.url(a, '/studentVirtualClassroomAPI'),
      emptyText: 'No live classes are scheduled.',
      emptyIcon: Icons.videocam_off_outlined,
      itemBuilder: (c, r, i) {
        final link = s(r['url']);
        return KitCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('By ${s(r['teacher_name'])}', style: const TextStyle(color: Brand.muted, fontSize: 13))),
              const Icon(Icons.schedule, size: 15, color: Brand.muted),
              const SizedBox(width: 4),
              Text(time12(r['to_time']), style: const TextStyle(color: Brand.muted, fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text(s(r['subject_name']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(84, 44), backgroundColor: const Color(0xFF16A34A)),
                onPressed: link.isEmpty ? null : () => openUrl(c, link),
                child: const Text('Join'),
              ),
            ]),
            const SizedBox(height: 4),
            Text('${fmtDate(r['event_date'], out: 'dd-MM-yyyy')} ${time12(r['from_time'])}'.trim(),
                style: const TextStyle(color: Brand.primary, fontWeight: FontWeight.w600)),
            if (s(r['chapter_name']).isNotEmpty || s(r['topic_name']).isNotEmpty) ...[
              const Divider(height: 18, color: Brand.border),
              Text('Chapter: ${s(r['chapter_name'])}', style: const TextStyle(fontSize: 13)),
              if (s(r['topic_name']).isNotEmpty) Text('Topic: ${s(r['topic_name'])}', style: const TextStyle(fontSize: 13)),
            ],
          ]),
        );
      },
    );

// ---------------------------------------------------------------------------------------
// Social collaborative (read-only doubt threads)
// ---------------------------------------------------------------------------------------

/// Student's own doubts. Newer `GET /api/lms/social-collaborative?mine=1` (token identity,
/// paginated, replies fetched per thread) first; legacy `studentSocialCollabrativeAPI` once on failure.
Future<List<Map<String, dynamic>>> _loadDoubts(ScreenArgs a) => Sx.newThenLegacy<List<Map<String, dynamic>>>(
      'social_collabrative',
      () async {
        final out = <Map<String, dynamic>>[];
        var page = 1, last = 1;
        do {
          final res = await a.api.get('/api/lms/social-collaborative',
              query: {'mine': 1, 'per_page': 50, 'page': page}, withIdentity: false);
          if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res));
          for (final r in rows(res['data'])) {
            out.add({...r, 'file_name': s(r['attachment_url']), '_v2': true});
          }
          last = int.tryParse(s(m(res['meta'])['last_page'])) ?? 1;
          page++;
        } while (page <= last && page <= 10);
        return out;
      },
      () async {
        final res = await Sx.call(a, Sx.url(a, '/studentSocialCollabrativeAPI'));
        if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res));
        final d = res['data'];
        return d is Map ? rows(d.values.toList()) : rows(d);
      },
    );

String _authorName(dynamic author) {
  if (author is Map) {
    for (final k in ['name', 'full_name', 'display_name', 'student_name']) {
      if (s(author[k]).isNotEmpty) return s(author[k]);
    }
    return '';
  }
  return s(author);
}

/// One doubt; with the newer API its replies load when the card is opened.
class _DoubtCard extends StatefulWidget {
  const _DoubtCard({required this.args, required this.row});
  final ScreenArgs args;
  final Map<String, dynamic> row;

  @override
  State<_DoubtCard> createState() => _DoubtCardState();
}

class _DoubtCardState extends State<_DoubtCard> {
  List<Map<String, dynamic>>? _comments;
  bool _loading = false, _failed = false;

  bool get _lazy => widget.row['_v2'] == true;

  Future<void> _toggle() async {
    if (_comments != null) {
      setState(() => _comments = null);
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final res = await widget.args.api.get('/api/lms/social-collaborative/${s(widget.row['id'])}', withIdentity: false);
      if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res));
      _comments = [
        for (final c in rows(m(res['data'])['comments'])) {...c, 'student_name': _authorName(c['author'])},
      ];
    } catch (e) {
      debugPrint('api-migration: social_collabrative thread failed: $e');
      _failed = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final convo = _lazy ? (_comments ?? const <Map<String, dynamic>>[]) : rows(r['ConversationData']);
    final count = int.tryParse(s(r['comment_count'])) ?? 0;
    return KitCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(s(r['created_at']), style: const TextStyle(color: Brand.muted, fontSize: 12, fontStyle: FontStyle.italic))),
          AttachmentButton(s(r['file_name'])),
        ]),
        Text(s(r['title']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        if (s(r['description']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: LinkText(s(r['description']))),
        for (final c in convo) ...[
          const Divider(height: 20, color: Brand.border),
          Text(s(c['message']), textAlign: TextAlign.right, maxLines: 4, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('${s(c['created_at'])}  |  By ${s(c['student_name'])}', style: const TextStyle(color: Brand.muted, fontSize: 12)),
        ],
        if (_lazy) ...[
          if (_failed) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Could not load the replies.', style: TextStyle(color: Brand.muted, fontSize: 12))),
          if (_loading)
            const Padding(padding: EdgeInsets.only(top: 8), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_comments != null || count > 0)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: EdgeInsets.zero),
              onPressed: _toggle,
              child: Text(_comments != null ? 'Hide replies' : 'View replies ($count)'),
            ),
        ],
      ]),
    );
  }
}

Widget socialCollaborativeScreen(ScreenArgs a) => KitPage(
      title: 'Social collaborative',
      child: AsyncList(
        emptyText: 'No discussions yet.',
        emptyIcon: Icons.forum_outlined,
        load: () => _loadDoubts(a),
        itemBuilder: (c, r, i) => _DoubtCard(args: a, row: r),
      ),
    );

// ---------------------------------------------------------------------------------------
// Leaderboard
// ---------------------------------------------------------------------------------------

Widget leaderboardScreen(ScreenArgs a) => KitPage(
      title: 'LMS leaderboard',
      child: AsyncList(
        emptyText: 'The leaderboard is empty for now.',
        emptyIcon: Icons.emoji_events_outlined,
        load: () => Sx.newThenLegacy<List<Map<String, dynamic>>>(
          'leaderboard',
          () async {
            final res = await a.api.get('/api/lms/leaderboard', withIdentity: false);
            if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res));
            final d = m(res['data']);
            if (d['has_data'] == false) return const []; // new empty state: has_data:false, not an empty list
            final me = m(d['learner']);
            final rank = s(me['rank']), size = s(me['class_size']);
            return [
              {'type': 'My Points', 'total_points': s(me['total_points'])},
              {'type': 'My Leaderboard', 'student_rank': rank.isEmpty ? '' : (size.isEmpty ? '#$rank' : '#$rank of $size')},
              {'type': 'My Tier', 'my_tier': s(me['medal'])},
            ];
          },
          () async {
            final res = await Sx.call(a, Sx.url(a, '/studentLeaderBoardAPI'));
            if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res));
            final d = res['data'];
            return d is Map ? rows(d.values.toList()) : rows(d);
          },
        ),
        itemBuilder: (c, r, i) {
          // The old app showed points, then rank, then tier by tile position.
          final (label, value) = switch (i) {
            0 => ('Total points', s(r['total_points'])),
            1 => ('Rank', s(r['student_rank'])),
            _ => ('Tier', s(r['my_tier'])),
          };
          final accent = Brand.accent(i);
          return KitCard(
            child: Row(children: [
              IconBubble(icon: i == 0 ? Icons.stars_rounded : i == 1 ? Icons.emoji_events_outlined : Icons.workspace_premium_outlined, accent: accent, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s(r['type']), style: const TextStyle(color: Brand.muted, fontSize: 13)),
                  Text(label, style: const TextStyle(fontSize: 12, color: Brand.muted)),
                ]),
              ),
              Text(value.isEmpty ? '-' : value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: accent.$1)),
            ]),
          );
        },
      ),
    );

// ---------------------------------------------------------------------------------------
// Discipline / exam schedule / holidays / teachers / homework
// ---------------------------------------------------------------------------------------

Widget disciplineScreen(ScreenArgs a) => SimpleList(
      args: a,
      title: 'Student discipline',
      url: '/studentDisciplineAPI',
      emptyText: 'No remarks have been recorded.',
      itemBuilder: (c, r, i) => KitCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s(r['message']), style: const TextStyle(fontSize: 15, height: 1.4)),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 14, color: Brand.muted),
            const SizedBox(width: 6),
            Expanded(child: Text(fmtDate(r['discipline_date'], out: 'dd MMMM yyyy'), style: const TextStyle(color: Brand.muted, fontSize: 13))),
            if (s(r['discipline']).isNotEmpty) Pill(s(r['discipline']), color: const Color(0xFF16A34A)),
          ]),
        ]),
      ),
    );

Widget examScheduleScreen(ScreenArgs a) => SimpleList(
      args: a,
      title: titleOf(a, 'Exam schedule'),
      url: Sx.url(a, '/studentExamScheduleAPI'),
      emptyText: 'No exams are scheduled yet.',
      emptyIcon: Icons.event_note_outlined,
      itemBuilder: (c, r, i) => KitCard(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s(r['title']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              AttachmentButton(s(r['file_name'])),
            ]),
          ),
          Text(fmtDate(r['date_'], out: 'dd MMM, yyyy'), style: const TextStyle(color: Brand.primary, fontWeight: FontWeight.w700)),
        ]),
      ),
    );

Widget holidayListScreen(ScreenArgs a) => SimpleList(
      args: a,
      title: 'Holiday list',
      url: '/studentCalenderAPI',
      body: const {'action': 'holiday', 'type': 'API'},
      emptyText: 'No holidays are listed.',
      emptyIcon: Icons.beach_access_outlined,
      itemBuilder: (c, r, i) => KitCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s(r['title']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              if (s(r['description']).isNotEmpty) Text(s(r['description']), style: const TextStyle(color: Brand.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(fmtDate(r['school_date'], out: 'dd MMMM yyyy'), textAlign: TextAlign.right, style: const TextStyle(color: Brand.primary, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      ),
    );

Color _subjectColor(String subject) {
  switch (subject.toLowerCase()) {
    case 'english':
    case 'social science':
      return const Color(0xFF2563EB);
    case 'gujarati':
    case 'activity':
    case 'hindi':
      return const Color(0xFF16A34A);
    default:
      return const Color(0xFFE52826);
  }
}

Widget teacherListScreen(ScreenArgs a) => SimpleList(
      args: a,
      title: 'Teacher list',
      url: '/studentTeacherListAPI',
      emptyText: 'No teachers are listed for your class.',
      emptyIcon: Icons.groups_outlined,
      itemBuilder: (c, r, i) => KitCard(
        child: Row(children: [
          PersonAvatar(url: s(r['image']), name: s(r['teacher_name']), radius: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s(r['teacher_name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(s(r['subject_name']), style: TextStyle(color: _subjectColor(s(r['subject_name'])), fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );

Widget homeworkScreen(ScreenArgs a) => SimpleList(
      args: a,
      title: titleOf(a, 'Homework'),
      url: Sx.url(a, '/studentHomeworkAssignmentAPI'),
      body: const {'action': 'Homework'},
      silent: true,
      emptyText: 'No homework has been assigned.',
      emptyIcon: Icons.edit_note_outlined,
      itemBuilder: (c, r, i) => KitCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PersonAvatar(url: s(r['user_image']), name: s(r['subject_name']).isEmpty ? s(r['title']) : s(r['subject_name']), radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s(r['title']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              if (s(r['subject_name']).isNotEmpty) Text(s(r['subject_name']), style: const TextStyle(color: Brand.primary, fontSize: 12.5)),
              Text(s(r['date']), style: const TextStyle(color: Brand.muted, fontSize: 12)),
              const SizedBox(height: 6),
              LinkText(s(r['description']), maxLines: 20),
              AttachmentButton(s(r['file_name']), label: 'Open attachment'),
            ]),
          ),
        ]),
      ),
    );
