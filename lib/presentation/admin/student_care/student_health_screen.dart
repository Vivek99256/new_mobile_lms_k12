import 'package:flutter/material.dart';

import '../../../screens/screen_registry.dart';
import 'student_care_controller.dart';
import 'student_care_screen.dart';

/// Student Health (menu link `student/student_health`).
class StudentHealthScreen extends StatelessWidget {
  const StudentHealthScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) => StudentCareScreen(args: args, spec: CareSpec.health);
}
