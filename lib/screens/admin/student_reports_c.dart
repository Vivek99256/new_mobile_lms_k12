import 'package:flutter/material.dart';

import '../../presentation/admin/student_reports/c_submission_report_screen.dart';
import '../../presentation/admin/student_reports/c_van_summary_screen.dart';
import '../../presentation/admin/student_reports/c_van_wise_screen.dart';
import '../screen_registry.dart';
import 'records_report.dart';

/// Student Report menus, group C: homework reports and the two van reports.
/// Keys are the menu links, lowercased with the slashes stripped (`normalizeMenuLink`).
final Map<String, ScreenBuilder> studentReportsC = {
  'student_homework_report_index': _homeworkReport,
  'student_homework_submission_report_index': (a) => CSubmissionReportScreen(args: a),
  'transportation/van_wise_report': (a) => CVanWiseScreen(args: a),
  'transportation/van_summery_report': (a) => CVanSummaryScreen(args: a),
};

/// `POST student/student_homework_report`. `typewise=subjectwise` gives one row per homework (not one per
/// student it was set for); the "Teacher" line is then the person who set it.
Widget _homeworkReport(ScreenArgs a) => RecordsReportScreen(
      args: a,
      endpoint: '/student/student_homework_report',
      post: true,
      query: const {'typewise': 'subjectwise'},
      rowsKey: 'report_data',
      classFilter: true,
      dateRange: true,
      icon: Icons.menu_book_outlined,
      emptyText: 'No homework in this period.',
      titleKeys: const ['title'],
      subtitleKeys: const ['subject_name'],
      dateKey: 'date',
      badgeKeys: const ['standard_name'],
      fields: const [
        RecField('Division', ['division_name']),
        RecField('Set by', ['student_name']),
        RecField('Due', ['submission_date'], date: true),
        RecField('Details', ['description']),
      ],
    );
