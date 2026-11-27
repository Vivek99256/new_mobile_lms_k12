import 'package:flutter/material.dart';

import '../../../ui/design.dart';
import '../../../ui/theme.dart';

/// Shared look for the Student module admin screens (Add Student, Bulk Update, Houses, Shuffling).

/// Filled, rounded inputs (the same theme the student edit form uses).
InputDecorationTheme studentInputTheme() => InputDecorationTheme(
      filled: true,
      fillColor: Brand.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.primary, width: 1.6)),
    );

Widget withStudentInputs(BuildContext context, Widget child) =>
    Theme(data: Theme.of(context).copyWith(inputDecorationTheme: studentInputTheme()), child: child);

/// A white card with an icon + title and the fields below, spaced evenly.
class StudentGroup extends StatelessWidget {
  const StudentGroup({super.key, required this.title, required this.icon, required this.children, this.trailing});
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: SoftCard(
          radius: 20,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconTile(icon, size: 30),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              ?trailing,
            ]),
            const SizedBox(height: 14),
            for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 14), child: c),
          ]),
        ),
      );
}

/// Navy gradient summary strip with big numbers.
class NavyStats extends StatelessWidget {
  const NavyStats({super.key, required this.stats, this.caption});
  final List<(String, String)> stats;
  final String? caption;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Brand.navy.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            for (final st in stats)
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(st.$2, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
                  const SizedBox(height: 3),
                  Text(st.$1, style: const TextStyle(color: Brand.champagne, fontSize: 12)),
                ]),
              ),
          ]),
          if (caption != null) ...[
            const SizedBox(height: 10),
            Text(caption!, style: const TextStyle(color: Brand.champagne, fontSize: 12.5, height: 1.3)),
          ],
        ]),
      );
}

/// Inline notice (info / warning / error).
class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.kind = NoticeKind.info});
  final String text;
  final NoticeKind kind;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icon) = switch (kind) {
      NoticeKind.info => (Brand.info, Brand.info0, Icons.info_outline_rounded),
      NoticeKind.warn => (Brand.warn, Brand.warn0, Icons.warning_amber_rounded),
      NoticeKind.error => (Brand.err, Brand.err0, Icons.error_outline_rounded),
      NoticeKind.ok => (Brand.ok, Brand.ok0, Icons.check_circle_outline_rounded),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: fg, fontSize: 13, height: 1.3, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

enum NoticeKind { info, warn, error, ok }


/// Owns text controllers created for a bottom sheet or dialog and disposes them only when the sheet's widgets are
/// really removed. (Disposing right after `showModalBottomSheet` returns is too early: the closing animation is still
/// drawing the TextFields, which then use a disposed controller.)
class ControllerScope extends StatefulWidget {
  const ControllerScope({super.key, required this.controllers, required this.child});
  final List<TextEditingController> controllers;
  final Widget child;

  @override
  State<ControllerScope> createState() => _ControllerScopeState();
}

class _ControllerScopeState extends State<ControllerScope> {
  @override
  void dispose() {
    for (final c in widget.controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
