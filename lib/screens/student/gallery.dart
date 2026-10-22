import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'media.dart';
import 'student_common.dart';

/// Photo and video albums (the feed's screen_name decides which `action` is sent).
class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({super.key, required this.args, required this.video});
  final ScreenArgs args;
  final bool video;

  @override
  Widget build(BuildContext context) => KitPage(
        title: titleOf(args, video ? 'Video gallery' : 'Photo gallery'),
        child: AsyncBody<List<List<Map<String, dynamic>>>>(
          emptyText: video ? 'No video albums yet.' : 'No photo albums yet.',
          isEmpty: (d) => d.isEmpty,
          load: () async {
            final res = await Sx.call(args, Sx.url(args, '/studentPhotoVideoGalleryAPI'), body: {'action': video ? 'Video' : 'Photo'});
            if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res));
            final d = res['data'];
            final groups = d is Map ? d.values : (d is List ? [d] : const []);
            return [for (final g in groups) if (rows(g).isNotEmpty) rows(g)];
          },
          builder: (c, albums, reload) => RefreshIndicator(
            onRefresh: reload,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.15),
              itemCount: albums.length,
              itemBuilder: (c, i) {
                final items = albums[i];
                return KitCard(
                  onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => AlbumViewScreen(items: items, video: video))),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconBubble(icon: video ? Icons.video_library_outlined : Icons.folder_outlined, accent: Brand.accent(i), size: 52),
                    const SizedBox(height: 10),
                    Text(s(items.first['album_title']), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${items.length} item${items.length == 1 ? '' : 's'}', style: const TextStyle(color: Brand.muted, fontSize: 12)),
                  ]),
                );
              },
            ),
          ),
        ),
      );
}

String _thumb(Map<String, dynamic> it, bool video) {
  if (!video) return s(it['file_name']);
  final url = s(it['file_name']);
  final id = url.contains('v=') ? url.split('v=').last.split('&').first : url.split('/').last;
  return 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
}

class AlbumViewScreen extends StatefulWidget {
  const AlbumViewScreen({super.key, required this.items, required this.video});
  final List<Map<String, dynamic>> items;
  final bool video;

  @override
  State<AlbumViewScreen> createState() => _AlbumViewScreenState();
}

class _AlbumViewScreenState extends State<AlbumViewScreen> {
  final Set<int> _sel = {};

  void _tap(int i) {
    if (_sel.isNotEmpty) {
      setState(() => _sel.contains(i) ? _sel.remove(i) : _sel.add(i));
      return;
    }
    final url = s(widget.items[i]['file_name']);
    if (widget.video) {
      openUrl(context, url);
    } else {
      final urls = [for (final it in widget.items) s(it['file_name'])];
      Navigator.push(context, MaterialPageRoute(builder: (_) => ZoomGallery(urls: urls, index: i)));
    }
  }

  List<String> get _selectedUrls => [for (final i in _sel.toList()..sort()) s(widget.items[i]['file_name'])];

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return PopScope(
      canPop: _sel.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_sel.clear);
      },
      child: KitPage(
        title: _sel.isEmpty ? s(items.first['album_title']) : '${_sel.length} selected',
        actions: [
          if (_sel.isNotEmpty) ...[
            IconButton(tooltip: 'Share links', icon: const Icon(Icons.share_outlined, color: Colors.white), onPressed: () => SharePlus.instance.share(ShareParams(text: _selectedUrls.join('\n')))),
            IconButton(tooltip: 'Open in browser', icon: const Icon(Icons.download_rounded, color: Colors.white), onPressed: () async {
              for (final u in _selectedUrls) {
                await openUrl(context, u);
              }
            }),
          ],
        ],
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.95),
          itemCount: items.length,
          itemBuilder: (c, i) => GestureDetector(
            onTap: () => _tap(i),
            onLongPress: () => setState(() => _sel.add(i)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(fit: StackFit.expand, children: [
                Image.network(_thumb(items[i], widget.video), fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Brand.border, child: Icon(Icons.broken_image_outlined, color: Brand.muted))),
                if (widget.video) const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 44)),
                if (_sel.contains(i)) ColoredBox(color: Brand.primary.withValues(alpha: 0.45), child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 36)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.black54,
                    child: Text(s(items[i]['title']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
