import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'media.dart';
import 'quiz.dart';
import 'quiz_reports.dart';
import 'student_common.dart';

/// Learn / PAL: subjects -> chapters -> topics and content, plus tests and reports.

Widget learnScreen(ScreenArgs a) => _SubjectGrid(args: a, pal: false);
Widget palScreen(ScreenArgs a) => _SubjectGrid(args: a, pal: true);

String _stdName(ScreenArgs a) => Sx.raw(a, 'std_name');

String _subjectTitle(ScreenArgs a, Map<String, dynamic> subject) {
  final std = _stdName(a);
  return std.isEmpty ? s(subject['display_name']) : '${s(subject['display_name'])} - $std';
}

class _SubjectGrid extends StatelessWidget {
  const _SubjectGrid({required this.args, required this.pal});
  final ScreenArgs args;
  final bool pal;

  @override
  Widget build(BuildContext context) => KitPage(
        title: titleOf(args, pal ? 'PAL' : 'My subjects'),
        child: AsyncBody<List<Map<String, dynamic>>>(
          emptyText: 'No subjects are assigned to you yet.',
          isEmpty: (d) => d.isEmpty,
          load: () => Sx.list(args, '/studentSubjectAPI'),
          builder: (c, subjects, reload) => RefreshIndicator(
            onRefresh: reload,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.05),
              itemCount: subjects.length,
              itemBuilder: (c, i) {
                final sub = subjects[i];
                final img = s(sub['display_image']);
                final accent = Brand.accent(i);
                return KitCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () => Navigator.push(
                      c,
                      MaterialPageRoute(
                          builder: (_) => pal ? ChapterScreen(args: args, subject: sub) : SubjectDetailScreen(args: args, subject: sub))),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (img.isEmpty || img.toLowerCase().endsWith('.svg'))
                      IconBubble(icon: Icons.menu_book_outlined, accent: accent, size: 52)
                    else
                      Image.network(img, height: 52, width: 52, fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => IconBubble(icon: Icons.menu_book_outlined, accent: accent, size: 52)),
                    const SizedBox(height: 10),
                    Text(s(sub['display_name']), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                );
              },
            ),
          ),
        ),
      );
}

/// PAL chapter page: chapters of one subject.
class ChapterScreen extends StatelessWidget {
  const ChapterScreen({super.key, required this.args, required this.subject});
  final ScreenArgs args;
  final Map<String, dynamic> subject;

  @override
  Widget build(BuildContext context) => KitPage(title: _subjectTitle(args, subject), child: ChapterList(args: args, subject: subject));
}

/// Chapters of a subject (studentContentAPI returns a map keyed by chapter).
class ChapterList extends StatelessWidget {
  const ChapterList({super.key, required this.args, required this.subject});
  final ScreenArgs args;
  final Map<String, dynamic> subject;

  @override
  Widget build(BuildContext context) => AsyncList(
        emptyText: 'No chapters have been published for this subject.',
        emptyIcon: Icons.menu_book_outlined,
        load: () async {
          final res = await Sx.call(args, '/studentContentAPI', body: {'subject_id': s(subject['subject_id'])});
          if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res));
          final d = res['data'];
          return d is Map ? rows(d.values.toList()) : rows(d);
        },
        itemBuilder: (c, ch, i) => KitCard(
          onTap: () {
            if (rows(ch['topicData']).isEmpty) {
              toast(c, 'No content has been added to this chapter yet.', error: true);
            } else {
              Navigator.push(c, MaterialPageRoute(builder: (_) => ChapterDetailScreen(chapter: ch)));
            }
          },
          child: Row(children: [
            IconBubble(icon: Icons.auto_stories_outlined, accent: Brand.accent(i), size: 42),
            const SizedBox(width: 12),
            Expanded(child: Text(s(ch['chapter_name']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            const Icon(Icons.chevron_right_rounded, color: Brand.muted),
          ]),
        ),
      );
}

/// Learn / Test / Report tabs for one subject.
class SubjectDetailScreen extends StatelessWidget {
  const SubjectDetailScreen({super.key, required this.args, required this.subject});
  final ScreenArgs args;
  final Map<String, dynamic> subject;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: KitPage(
          title: _subjectTitle(args, subject),
          child: Column(children: [
            const Material(
              color: Colors.white,
              child: TabBar(tabs: [Tab(text: 'Learn'), Tab(text: 'Test'), Tab(text: 'Report')]),
            ),
            Expanded(
              child: TabBarView(children: [
                ChapterList(args: args, subject: subject),
                _PaperList(args: args, subject: subject, report: false),
                _PaperList(args: args, subject: subject, report: true),
              ]),
            ),
          ]),
        ),
      );
}

class _PaperList extends StatelessWidget {
  const _PaperList({required this.args, required this.subject, required this.report});
  final ScreenArgs args;
  final Map<String, dynamic> subject;
  final bool report;

  @override
  Widget build(BuildContext context) => AsyncList(
        emptyText: report ? 'No tests to report on yet.' : 'No tests are available for this subject.',
        emptyIcon: Icons.quiz_outlined,
        load: () => Sx.list(args, '/studentQuestionPaperListAPI', body: {'subject_id': s(subject['subject_id'])}),
        itemBuilder: (c, p, i) => KitCard(
          onTap: () => Navigator.push(
              c,
              MaterialPageRoute(
                  builder: (_) => report ? TestReportListScreen(args: args, paper: p) : QuizScreen(args: args, paper: p))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s(p['paper_name']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                if (s(p['time_allowed']).isNotEmpty && s(p['time_allowed']) != '0')
                  Text('${s(p['time_allowed'])} min', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
              ]),
            ),
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Brand.primary, borderRadius: BorderRadius.circular(12)),
              child: Text(s(p['total_ques']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      );
}

/// Topics of a chapter with their content (pdf, image, link, video).
class ChapterDetailScreen extends StatelessWidget {
  const ChapterDetailScreen({super.key, required this.chapter});
  final Map<String, dynamic> chapter;

  void _open(BuildContext c, Map<String, dynamic> item) {
    final type = s(item['file_type']).toLowerCase();
    final url = s(item['full_path']);
    final title = s(item['title']);
    if (url.isEmpty) {
      toast(c, 'This item has no file attached.', error: true);
    } else if (type == 'pdf') {
      openUrl(c, url);
    } else if (type == 'jpg' || type == 'jpeg' || type == 'png' || looksLikeImage(url)) {
      Navigator.push(c, MaterialPageRoute(builder: (_) => ZoomGallery(urls: [url], title: title)));
    } else if (type == 'link') {
      openUrl(c, url);
    } else {
      Navigator.push(c, MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: url, title: title)));
    }
  }

  IconData _icon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_outlined;
      case 'link':
        return Icons.link_rounded;
      default:
        return Icons.play_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topics = rows(chapter['topicData']);
    return KitPage(
      title: s(chapter['chapter_name']).isEmpty ? 'Chapter' : s(chapter['chapter_name']),
      child: topics.isEmpty
          ? const KitMessage(icon: Icons.folder_off_outlined, text: 'No topics have been added yet.')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: topics.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (c, i) {
                final t = topics[i];
                final content = rows(t['contentData']);
                return KitCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      IconBubble(icon: Icons.topic_outlined, accent: Brand.accent(i), size: 38),
                      const SizedBox(width: 10),
                      Expanded(child: Text(s(t['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
                    ]),
                    if (content.isEmpty)
                      const Padding(padding: EdgeInsets.only(top: 8), child: Text('No files in this topic yet.', style: TextStyle(color: Brand.muted))),
                    for (final item in content)
                      InkWell(
                        onTap: () => _open(c, item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Row(children: [
                            Icon(_icon(s(item['file_type'])), color: Brand.primary, size: 22),
                            const SizedBox(width: 10),
                            Expanded(child: Text(s(item['title']), style: const TextStyle(fontSize: 14))),
                            const Icon(Icons.chevron_right_rounded, color: Brand.muted, size: 20),
                          ]),
                        ),
                      ),
                  ]),
                );
              },
            ),
    );
  }
}
