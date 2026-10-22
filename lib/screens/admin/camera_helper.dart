import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../kit/kit.dart';

/// Opens the camera (after asking for permission) and returns the photo path, or null.
Future<String?> takePhoto(BuildContext context) async {
  final status = await Permission.camera.request();
  if (!context.mounted) return null;
  if (!status.isGranted) {
    toast(context, 'Allow camera access in Settings to take photos.', error: true);
    if (status.isPermanentlyDenied) await openAppSettings();
    return null;
  }
  try {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 500, maxHeight: 500);
    return x?.path;
  } catch (_) {
    if (context.mounted) toast(context, 'Could not open the camera.', error: true);
    return null;
  }
}

/// Thumbnail tile for a captured photo (local file or server URL) with a remove button.
class PhotoTile extends StatelessWidget {
  const PhotoTile({super.key, this.path, this.url, this.onRemove, this.done = false});
  final String? path;
  final String? url;
  final VoidCallback? onRemove;
  final bool done;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(fit: StackFit.expand, children: [
          if (path != null && File(path!).existsSync())
            Image.file(File(path!), fit: BoxFit.cover)
          else if (url != null && url!.isNotEmpty)
            Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFE2E8F0), child: Icon(Icons.broken_image_outlined)))
          else
            const ColoredBox(color: Color(0xFFE2E8F0), child: Icon(Icons.image_outlined)),
          if (done)
            const Positioned(left: 6, bottom: 6, child: CircleAvatar(radius: 11, backgroundColor: Color(0xFF16A34A), child: Icon(Icons.check, size: 14, color: Colors.white))),
          if (onRemove != null)
            Positioned(
              right: 2,
              top: 2,
              child: InkWell(
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircleAvatar(radius: 11, backgroundColor: Color(0xFFDC2626), child: Icon(Icons.close, size: 14, color: Colors.white)),
                ),
              ),
            ),
        ]),
      );
}

/// The dashed "add a photo" tile.
class AddPhotoTile extends StatelessWidget {
  const AddPhotoTile({super.key, required this.onTap, this.label = 'Add photo'});
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.photo_camera_outlined, color: Color(0xFF4169E1)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ]),
        ),
      );
}
