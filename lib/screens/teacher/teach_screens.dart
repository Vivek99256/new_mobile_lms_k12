import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'tk.dart';

/// t_teach: subjects of a standard -> chapters -> topics and their content.
class TeachScreen extends StatefulWidget {
  const TeachScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<TeachScreen> createState() => _TeachScreenState();
}

class _TeachScreenState extends State<TeachScreen> {
  ClassSel sel = ClassSel();
  final ctrl = AsyncListController();

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    final admin = isAdmin(a);
    return ListPage(
      title: a.title.isEmpty ? 'Teach' : a.title,
      controller: ctrl,
      emptyText: sel.stdId == null ? 'Select a standard to see its subjects.' : 'No subjects found for this standard.',
      emptyIcon: Icons.menu_book_outlined,
      header: ClassPicker(
        api: a.api,
        admin: admin,
        withDivision: false,
        autoSelectFirst: true,
        onChanged: (c) {
          sel = c;
          ctrl.reload();
        },
      ),
      load: () async {
        if (sel.stdId == null) return const [];
        final res = await postOk(a.api, admin ? '/get_adminSubject' : '/get_teacher_timetablewiseSubject', body: {'standard_id': sel.stdId});
        final seen = <String>{};
        return [
          for (final r in dataRows(res))
            if (seen.add(s(admin ? r['subject_id'] : r['sub_id']))) {'id': s(admin ? r['subject_id'] : r['sub_id']), 'name': s(admin ? r['subject_name'] : r['sub_name'])},
        ];
      },
      itemBuilder: (c, r, i) => KitCard(
        onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ChapterListScreen(args: a, standardId: sel.stdId!, subjectId: s(r['id']), subjectName: s(r['name'])))),
        child: Row(children: [
          IconBubble(icon: Icons.auto_stories_rounded, accent: Brand.accent(i)),
          const SizedBox(width: 12),
          Expanded(child: Text(s(r['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          const Icon(Icons.chevron_right_rounded, color: Brand.muted),
        ]),
      ),
    );
  }
}

class ChapterListScreen extends StatelessWidget {
  const ChapterListScreen({super.key, required this.args, required this.standardId, required this.subjectId, required this.subjectName});
  final ScreenArgs args;
  final String standardId, subjectId, subjectName;

  @override
  Widget build(BuildContext context) => ListPage(
        title: subjectName.isEmpty ? 'Chapters' : subjectName,
        emptyText: 'No chapters have been added for this subject.',
        emptyIcon: Icons.library_books_outlined,
        load: () async {
          final res = await postOk(args.api, '/get_teacherContentAPI', body: {'standard_id': standardId, 'subject_id': subjectId});
          return dataRows(res);
        },
        itemBuilder: (c, r, i) {
          final topics = rows(r['topicData']);
          return KitCard(
            onTap: () {
              if (topics.isEmpty) {
                toast(c, 'This chapter has no topics yet.');
              } else {
                Navigator.push(c, MaterialPageRoute(builder: (_) => ChapterDetailScreen(chapter: r)));
              }
            },
            child: Row(children: [
              CircleAvatar(radius: 16, backgroundColor: const Color(0xFFE8EDFC), child: Text('${i + 1}', style: const TextStyle(color: Brand.primary, fontWeight: FontWeight.w800, fontSize: 13))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s(r['chapter_name']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  Text('${topics.length} topic${topics.length == 1 ? '' : 's'}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: Brand.muted),
            ]),
          );
        },
      );
}

class ChapterDetailScreen extends StatelessWidget {
  const ChapterDetailScreen({super.key, required this.chapter});
  final Map<String, dynamic> chapter;

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
        return Icons.play_circle_outline_rounded;
    }
  }

  void _open(BuildContext context, Map<String, dynamic> c) {
    final type = s(c['file_type']).toLowerCase();
    final url = s(c['full_path']).isNotEmpty ? s(c['full_path']) : s(c['url']);
    if (url.isEmpty) {
      toast(context, 'This item has no file attached.', error: true);
      return;
    }
    // Documents, images and links open externally; anything else is treated as video.
    if (type == 'pdf' || type == 'jpg' || type == 'jpeg' || type == 'png' || type == 'link') {
      openUrl(context, url);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VideoScreen(title: s(c['title']), url: url)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topics = rows(chapter['topicData']);
    return KitPage(
      title: s(chapter['chapter_name']).isEmpty ? 'Chapter' : s(chapter['chapter_name']),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (s(chapter['chapter_desc']).isNotEmpty) ...[Text(s(chapter['chapter_desc']), style: const TextStyle(color: Brand.muted)), gap()],
        if (topics.isEmpty) const KitMessage(icon: Icons.topic_outlined, text: 'No topics in this chapter.'),
        for (final t in topics) ...[
          KitCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s(t['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              gap(6),
              if (rows(t['contentData']).isEmpty) const Text('No content yet.', style: TextStyle(color: Brand.muted)),
              for (final c in rows(t['contentData']))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minVerticalPadding: 8,
                  leading: Icon(_icon(s(c['file_type'])), color: Brand.primary),
                  title: Text(s(c['title']), style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: Brand.muted),
                  onTap: () => _open(context, c),
                ),
            ]),
          ),
          gap(10),
        ],
      ]),
    );
  }
}

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key, required this.title, required this.url});
  final String title, url;

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  VideoPlayerController? ctrl;
  String? error;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    ctrl = c;
    c.initialize().then((_) {
      if (mounted) {
        setState(() {});
        c.play();
      }
    }).catchError((_) {
      if (mounted) setState(() => error = 'This video could not be played.');
    });
  }

  @override
  void dispose() {
    ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ctrl!;
    return KitPage(
      title: widget.title.isEmpty ? 'Video' : widget.title,
      child: error != null
          ? KitMessage(icon: Icons.error_outline_rounded, text: error!, action: 'Open in browser', onAction: () => openUrl(context, widget.url))
          : !c.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
                  gap(),
                  IconButton.filled(
                    iconSize: 32,
                    onPressed: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
                    icon: Icon(c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  ),
                ]),
    );
  }
}
