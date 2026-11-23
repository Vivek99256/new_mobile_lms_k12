import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/screen_registry.dart';
import 'fees_details/fees_collect_details_screen.dart';

/// Fees Collect (and Online Fees Collect): pick a class and student, then open that student's
/// fees. The class / division / student search itself is the shared StudentPicker widget.
class FeesCollectController {
  FeesCollectController({required this.args});
  final ScreenArgs args;

  String get title => args.item.label.isEmpty ? 'Fees collect' : args.item.label;

  /// "Collect fees" tapped on a student.
  Future<void> openStudent(BuildContext context, Map<String, dynamic> student) =>
      push(context, FeesCollectDetailsScreen(args: args, student: student));
}
