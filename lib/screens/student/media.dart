import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../kit/kit.dart';

/// Full-screen swipeable, pinch-zoom image pager.
class ZoomGallery extends StatefulWidget {
  const ZoomGallery({super.key, required this.urls, this.index = 0, this.title = ''});
  final List<String> urls;
  final int index;
  final String title;

  @override
  State<ZoomGallery> createState() => _ZoomGalleryState();
}

class _ZoomGalleryState extends State<ZoomGallery> {
  late final PageController _page = PageController(initialPage: widget.index.clamp(0, widget.urls.isEmpty ? 0 : widget.urls.length - 1));
  late int _i = widget.index;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(urls.length > 1 ? '${_i + 1} / ${urls.length}' : widget.title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'Share link',
            icon: const Icon(Icons.share_outlined),
            onPressed: urls.isEmpty ? null : () => SharePlus.instance.share(ShareParams(text: urls[_i])),
          ),
          IconButton(
            tooltip: 'Open in browser',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: urls.isEmpty ? null : () => openUrl(context, urls[_i]),
          ),
        ],
      ),
      body: urls.isEmpty
          ? const Center(child: Text('No image to show.', style: TextStyle(color: Colors.white70)))
          : PhotoViewGallery.builder(
              pageController: _page,
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _i = i),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              loadingBuilder: (_, _) => const Center(child: CircularProgressIndicator()),
              builder: (c, i) => PhotoViewGalleryPageOptions(
                imageProvider: NetworkImage(urls[i]),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
                errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48)),
              ),
            ),
    );
  }
}

/// Streams a video URL (autoplay, closes when it ends).
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.url, required this.title});
  final String url;
  final String title;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _c;
  String? _error;

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.url.trim());
    if (uri == null) {
      _error = 'This video link is not valid.';
      return;
    }
    final c = VideoPlayerController.networkUrl(uri);
    _c = c;
    c.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      c.play();
      c.addListener(_tick);
    }).catchError((Object _) {
      if (mounted) setState(() => _error = 'This video could not be played.');
    });
  }

  void _tick() {
    final c = _c;
    if (c == null || !mounted) return;
    final v = c.value;
    if (v.isInitialized && v.duration > Duration.zero && v.position >= v.duration) {
      c.removeListener(_tick);
      Navigator.maybePop(context);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _c?.removeListener(_tick);
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16))),
      body: Center(
        child: _error != null
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, style: const TextStyle(color: Colors.white70)),
                TextButton(onPressed: () => openUrl(context, widget.url), child: const Text('Open in browser')),
              ])
            : !ready
                ? const CircularProgressIndicator()
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    AspectRatio(aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio, child: VideoPlayer(c)),
                    VideoProgressIndicator(c, allowScrubbing: true, padding: const EdgeInsets.all(12)),
                    IconButton(
                      iconSize: 40,
                      color: Colors.white,
                      icon: Icon(c.value.isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline),
                      onPressed: () => c.value.isPlaying ? c.pause() : c.play(),
                    ),
                  ]),
      ),
    );
  }
}
