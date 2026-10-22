import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/legacy_api.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'admin_common.dart';
import 'camera_helper.dart';

/// Add a photo album or a YouTube video to the school gallery (opened from the shared
/// gallery list). Pops with true after a successful save so the list can reload.
class AdminAddPhotoVideoScreen extends StatefulWidget {
  const AdminAddPhotoVideoScreen({super.key, required this.args, this.video});
  final ScreenArgs args;

  /// Forces the tab; by default it follows the tile (`t_video_gallary` -> videos).
  final bool? video;

  @override
  State<AdminAddPhotoVideoScreen> createState() => _AdminAddPhotoVideoScreenState();
}

class _AdminAddPhotoVideoScreenState extends State<AdminAddPhotoVideoScreen> with SubmitGuard, SingleTickerProviderStateMixin {
  late final TabController tabs;
  CascadeSelection sel = CascadeSelection();
  final album = TextEditingController();
  final title = TextEditingController();
  final youtube = TextEditingController();
  final images = <String>[];

  @override
  void initState() {
    super.initState();
    final startVideo = widget.video ?? widget.args.item.screenName.toLowerCase().contains('video');
    tabs = TabController(length: 2, vsync: this, initialIndex: startVideo ? 1 : 0)..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    tabs.dispose();
    album.dispose();
    title.dispose();
    youtube.dispose();
    super.dispose();
  }

  bool get isVideo => tabs.index == 1;

  Future<void> _pick() async {
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
      if (mounted && picked.isNotEmpty) setState(() => images.addAll(picked.map((e) => e.path)));
    } catch (_) {
      if (mounted) toast(context, 'Could not open the photo library.', error: true);
    }
  }

  Future<void> _submit() async {
    if (missing(context, sel.standardId, 'Please select a standard.')) return;
    if (missing(context, sel.divisionId, 'Please select a division.')) return;
    if (missing(context, album.text, 'Please enter an album title.')) return;
    if (missing(context, title.text, 'Please enter a title.')) return;
    if (isVideo) {
      if (missing(context, youtube.text, 'Please enter a YouTube link.')) return;
    } else if (images.isEmpty) {
      toast(context, 'Please select at least one photo.', error: true);
      return;
    }
    await guarded(() async {
      final res = await widget.args.api.post(
        '/add_adminPhotoVideoAPI',
        body: {
          'standard_id': sel.standardId,
          'division_id': sel.divisionId,
          'date_': ymd(DateTime.now()),
          'album_title': album.text.trim(),
          'title': title.text.trim(),
          'type': isVideo ? 'Video' : 'Photo',
          if (isVideo) 'youtube_link': youtube.text.trim(),
        },
        files: isVideo ? const [] : [for (var i = 0; i < images.length; i++) UploadFile('attachment[$i]', images[i])],
      );
      if (!mounted) return;
      if (report(res, ok: 'Added to the gallery.')) Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) => KitPage(
        title: isVideo ? 'Add videos' : 'Add photos',
        bottom: formBar(label: isVideo ? 'Add video' : 'Add photos', busy: busy, onPressed: _submit),
        child: Column(children: [
          TabBar(controller: tabs, tabs: const [Tab(text: 'Photos'), Tab(text: 'Videos')]),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              CascadeFilter(api: widget.args.api, onChanged: (v) => setState(() => sel = v)),
              gap(),
              TextInput(label: 'Album title', controller: album),
              gap(),
              TextInput(label: isVideo ? 'Video title' : 'Photo title', controller: title),
              gap(),
              if (isVideo)
                TextInput(label: 'YouTube link', controller: youtube, keyboard: TextInputType.url)
              else ...[
                const SectionLabel('Photos'),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    for (var i = 0; i < images.length; i++) PhotoTile(path: images[i], onRemove: () => setState(() => images.removeAt(i))),
                    AddPhotoTile(onTap: _pick, label: 'Select photos'),
                  ],
                ),
              ],
            ]),
          ),
        ]),
      );
}
