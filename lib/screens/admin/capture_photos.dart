import 'package:flutter/material.dart';

import '../kit/kit.dart';
import '../screen_registry.dart';
import 'admin_common.dart';
import 'student_attendance_photos.dart';

/// Pick a class, find a student and open their reference-photo screen (used later by
/// photo-based attendance).
class CapturePhotosScreen extends StatefulWidget {
  const CapturePhotosScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<CapturePhotosScreen> createState() => _CapturePhotosScreenState();
}

class _CapturePhotosScreenState extends State<CapturePhotosScreen> {
  @override
  Widget build(BuildContext context) => KitPage(
        title: widget.args.item.label.isEmpty ? 'Capture photos' : widget.args.item.label,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          StudentPicker(
            api: widget.args.api,
            selectable: false,
            needDivision: true,
            onChanged: (_, _, _) {},
            onOpen: (student, filter) => push(
              context,
              StudentAttendancePhotosScreen(args: widget.args, student: student, sectionName: filter.sectionName ?? ''),
            ),
          ),
        ]),
      );
}
