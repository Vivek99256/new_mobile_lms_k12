import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'tk.dart';

/// Albums as `title -> items`, from either a map keyed by album or a flat list.
List<MapEntry<String, List<Map<String, dynamic>>>> groupAlbums(dynamic data) {
  final out = <String, List<Map<String, dynamic>>>{};
  if (data is Map) {
    for (final e in data.entries) {
      final items = rows(e.value);
      if (items.isNotEmpty) out['${e.key}'] = items;
    }
  } else {
    for (final r in rows(data)) {
      out.putIfAbsent(s(r['album_title']), () => []).add(r);
    }
  }
  return out.entries.toList();
}

String youtubeThumb(String link) {
  final u = Uri.tryParse(link);
  final id = u?.queryParameters['v'] ?? (u != null && u.host.contains('youtu.be') && u.pathSegments.isNotEmpty ? u.pathSegments.first : '');
  return id.isEmpty ? '' : 'https://img.youtube.com/vi/$id/0.jpg';
}

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, required this.args, this.video = false});
  final ScreenArgs args;
  final bool video;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late bool video = widget.video;
  ClassSel sel = ClassSel();
  List<MapEntry<String, List<Map<String, dynamic>>>> albums = [];
  bool loading = true;
  String? error;
  int _gen = 0;

  bool get admin => isAdmin(widget.args);

  Future<void> _load() async {
    if (!admin && sel.stdId == null) {
      setState(() => loading = false);
      return;
    }
    final gen = ++_gen;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await postOk(widget.args.api, admin ? '/get_adminPhotoVideoAPI' : '/photo_video_gallary/TeacherFetchData',
          body: {if (!admin) 'standard_id': sel.stdId, 'type': video ? 'Video' : 'Photo'});
      if (mounted && gen == _gen) setState(() => albums = groupAlbums(res['data']));
    } catch (e) {
      if (mounted && gen == _gen) {
        setState(() {
          albums = [];
          error = '$e';
        });
      }
    } finally {
      if (mounted && gen == _gen) setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (admin) _load();
  }

  Future<void> _add() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AddPhotoVideoScreen(args: widget.args, video: video)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    return KitPage(
      title: a.title.isEmpty ? (video ? 'Video gallery' : 'Photo gallery') : a.title,
      actions: [addAction(context, _add)],
      bottom: PrimaryButton(label: video ? 'Add videos' : 'Add photos', onPressed: _add),
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: false, label: Text('Photos'), icon: Icon(Icons.photo_outlined)), ButtonSegment(value: true, label: Text('Videos'), icon: Icon(Icons.videocam_outlined))],
            selected: {video},
            onSelectionChanged: (v) {
              setState(() => video = v.first);
              _load();
            },
          ),
          if (!admin) ...[
            gap(),
            ClassPicker(
              api: a.api,
              admin: false,
              withDivision: false,
              autoSelectFirst: true,
              onChanged: (c) {
                sel = c;
                if (c.stdId != null) _load();
              },
            ),
          ],
          gap(),
          if (loading)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (error != null)
            KitMessage(icon: Icons.cloud_off_outlined, text: error!, action: 'Try again', onAction: _load)
          else if (albums.isEmpty)
            KitMessage(icon: Icons.photo_library_outlined, text: !admin && sel.stdId == null ? 'Select a standard to see its albums.' : 'No ${video ? 'video' : 'photo'} albums yet.')
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
              children: [for (final al in albums) _AlbumTile(album: al, video: video)],
            ),
        ]),
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.album, required this.video});
  final MapEntry<String, List<Map<String, dynamic>>> album;
  final bool video;

  @override
  Widget build(BuildContext context) {
    final first = album.value.first;
    final cover = video ? youtubeThumb(s(first['file_name'])) : s(first['file_name']);
    final name = s(first['album_title']).isEmpty ? album.key : s(first['album_title']);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        if (video) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => _VideoAlbum(title: name, items: album.value)));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PhotosScreen(title: name, items: album.value)));
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(fit: StackFit.expand, children: [
          Container(color: const Color(0xFFE8EDFC)),
          if (cover.isNotEmpty) Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xCC0F172A)]))),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              Text('${album.value.length} item${album.value.length == 1 ? '' : 's'}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _VideoAlbum extends StatelessWidget {
  const _VideoAlbum({required this.title, required this.items});
  final String title;
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) => KitPage(
        title: title,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          for (final v in items) ...[
            KitCard(
              onTap: () => openUrl(context, s(v['file_name'])),
              child: Row(children: [
                const Icon(Icons.play_circle_fill_rounded, color: Brand.primary, size: 34),
                const SizedBox(width: 12),
                Expanded(child: Text(s(v['title']).isEmpty ? s(v['file_name']) : s(v['title']), maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
            ),
            gap(8),
          ],
        ]),
      );
}

Future<void> shareUrls(BuildContext context, List<String> urls) async {
  try {
    final files = <XFile>[];
    for (final u in urls) {
      final res = await http.get(Uri.parse(u));
      if (res.statusCode != 200) continue;
      final name = Uri.parse(u).pathSegments.isEmpty ? 'photo.jpg' : Uri.parse(u).pathSegments.last;
      final f = File('${Directory.systemTemp.path}${Platform.pathSeparator}${DateTime.now().microsecondsSinceEpoch}_$name');
      await f.writeAsBytes(res.bodyBytes);
      files.add(XFile(f.path));
    }
    if (files.isEmpty) {
      if (context.mounted) toast(context, 'Could not download the photo.', error: true);
      return;
    }
    await SharePlus.instance.share(ShareParams(files: files));
  } catch (_) {
    if (context.mounted) toast(context, 'Could not share the photo.', error: true);
  }
}

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key, required this.title, required this.items});
  final String title;
  final List<Map<String, dynamic>> items;

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  final Set<int> picked = {};
  bool get selecting => picked.isNotEmpty;

  List<String> get _urls => [for (final i in picked) s(widget.items[i]['file_name'])];

  @override
  Widget build(BuildContext context) => KitPage(
        title: selecting ? '${picked.length} selected' : widget.title,
        actions: [
          if (selecting) ...[
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white),
              onPressed: () async {
                final urls = _urls;
                setState(picked.clear);
                await shareUrls(context, urls);
              },
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.white),
              onPressed: () {
                for (final u in _urls) {
                  openUrl(context, u);
                }
                setState(picked.clear);
              },
            ),
          ],
        ],
        child: widget.items.isEmpty
            ? const KitMessage(icon: Icons.photo_outlined, text: 'This album has no photos.')
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12),
                itemCount: widget.items.length,
                itemBuilder: (c, i) {
                  final on = picked.contains(i);
                  return GestureDetector(
                    onLongPress: () => setState(() => picked.add(i)),
                    onTap: () {
                      if (selecting) {
                        setState(() => on ? picked.remove(i) : picked.add(i));
                      } else {
                        Navigator.push(c, MaterialPageRoute(builder: (_) => ZoomPhotoScreen(urls: [for (final x in widget.items) s(x['file_name'])], index: i)));
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(fit: StackFit.expand, children: [
                        Image.network(s(widget.items[i]['file_name']), fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFFE8EDFC), child: const Icon(Icons.broken_image_outlined))),
                        if (on) Container(color: Brand.primary.withValues(alpha: 0.35)),
                        if (on) const Positioned(top: 8, right: 8, child: CircleAvatar(radius: 12, backgroundColor: Brand.primary, child: Icon(Icons.check, size: 16, color: Colors.white))),
                      ]),
                    ),
                  );
                },
              ),
      );
}

class ZoomPhotoScreen extends StatefulWidget {
  const ZoomPhotoScreen({super.key, required this.urls, required this.index});
  final List<String> urls;
  final int index;

  @override
  State<ZoomPhotoScreen> createState() => _ZoomPhotoScreenState();
}

class _ZoomPhotoScreenState extends State<ZoomPhotoScreen> {
  late int current = widget.index;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('${current + 1} / ${widget.urls.length}'),
          actions: [
            IconButton(icon: const Icon(Icons.share_outlined), onPressed: () => shareUrls(context, [widget.urls[current]])),
            IconButton(icon: const Icon(Icons.download_rounded), onPressed: () => openUrl(context, widget.urls[current])),
          ],
        ),
        body: PhotoViewGallery.builder(
          itemCount: widget.urls.length,
          pageController: PageController(initialPage: widget.index),
          onPageChanged: (i) => setState(() => current = i),
          builder: (c, i) => PhotoViewGalleryPageOptions(imageProvider: NetworkImage(widget.urls[i]), minScale: PhotoViewComputedScale.contained),
          loadingBuilder: (_, _) => const Center(child: CircularProgressIndicator()),
        ),
      );
}

/// Add photos (or a YouTube link) to an album.
class AddPhotoVideoScreen extends StatefulWidget {
  const AddPhotoVideoScreen({super.key, required this.args, this.video = false});
  final ScreenArgs args;
  final bool video;

  @override
  State<AddPhotoVideoScreen> createState() => _AddPhotoVideoScreenState();
}

class _AddPhotoVideoScreenState extends State<AddPhotoVideoScreen> with BusyMixin {
  late bool video = widget.video;
  ClassSel sel = ClassSel();
  final album = TextEditingController(), title = TextEditingController(), link = TextEditingController();
  final List<XFile> images = [];

  @override
  void dispose() {
    album.dispose();
    title.dispose();
    link.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final r = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (r.isNotEmpty && mounted) setState(() => images.addAll(r));
  }

  void _submit() {
    if (sel.stdId == null || sel.divId == null) return toast(context, 'Select a standard and division.', error: true);
    if (album.text.trim().isEmpty) return toast(context, 'Please enter the album title.', error: true);
    if (title.text.trim().isEmpty) return toast(context, 'Please enter the photo title.', error: true);
    if (!video && images.isEmpty) return toast(context, 'Please choose at least one photo.', error: true);
    if (video && link.text.trim().isEmpty) return toast(context, 'Please enter the YouTube link.', error: true);
    submit(() => postOk(
          widget.args.api,
          '/add_adminPhotoVideoAPI',
          body: {
            'standard_id': sel.stdId,
            'division_id': sel.divId,
            'date_': DateTime.now().toString(),
            'album_title': album.text.trim(),
            'title': title.text.trim(),
            'type': video ? 'Video' : 'Photo',
            if (video) 'youtube_link': link.text.trim(),
          },
          files: video ? const [] : [for (var i = 0; i < images.length; i++) UploadFile('attachment[$i]', images[i].path)],
        ));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    return KitPage(
      title: video ? 'Add video' : 'Add photos',
      bottom: PrimaryButton(label: 'Submit', busy: busy, onPressed: _submit),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: false, label: Text('Photos')), ButtonSegment(value: true, label: Text('Video link'))],
          selected: {video},
          onSelectionChanged: (v) => setState(() => video = v.first),
        ),
        gap(),
        FormCard(children: [
          ClassPicker(api: a.api, admin: isAdmin(a), onChanged: (c) => sel = c),
          TextInput(label: 'Album title', controller: album),
          TextInput(label: video ? 'Video title' : 'Photo title', controller: title),
          if (video)
            TextInput(label: 'YouTube link', controller: link, keyboard: TextInputType.url)
          else ...[
            OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)), onPressed: _pick, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Select photos')),
            if (images.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < images.length; i++)
                  Stack(clipBehavior: Clip.none, children: [
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(images[i].path), width: 76, height: 76, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 76, height: 76, child: Icon(Icons.image)))),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: InkWell(onTap: () => setState(() => images.removeAt(i)), child: const CircleAvatar(radius: 11, backgroundColor: Color(0xFFDC2626), child: Icon(Icons.close, size: 14, color: Colors.white))),
                    ),
                  ]),
              ]),
          ],
        ]),
      ]),
    );
  }
}
