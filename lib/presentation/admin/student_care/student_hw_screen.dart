import 'package:flutter/material.dart';

import '../../../screens/screen_registry.dart';
import 'student_care_controller.dart';
import 'student_care_screen.dart';

/// Student HeightWeight (menu link `student/student_hw`).
class StudentHeightWeightScreen extends StatelessWidget {
  const StudentHeightWeightScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) => StudentCareScreen(args: args, spec: CareSpec.heightWeight);
}
