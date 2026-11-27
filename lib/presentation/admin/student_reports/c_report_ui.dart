import 'package:flutter/material.dart';

import '../../../ui/theme.dart';

/// Small pieces shared by the group-C student report screens (homework submission, van reports).

/// Navy header: an icon, a title line and a row of big numbers.
class CHero extends StatelessWidget {
  const CHero({super.key, required this.icon, required this.title, required this.subtitle, this.stats = const []});
  final IconData icon;
  final String title;
  final String subtitle;
  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Brand.navy.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Brand.champagne, fontSize: 12.5)),
              ]),
            ),
          ]),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) Container(width: 1, height: 30, margin: const EdgeInsets.symmetric(horizontal: 12), color: Colors.white.withValues(alpha: 0.16)),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(stats[i].$2, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, height: 1.1)),
                    const SizedBox(height: 2),
                    Text(stats[i].$1, style: const TextStyle(color: Brand.champagne, fontSize: 11.5)),
                  ]),
                ),
              ],
            ]),
          ],
        ]),
      );
}

/// A rounded search box that reports every change.
class CSearchBox extends StatelessWidget {
  const CSearchBox({super.key, required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          filled: true,
          fillColor: Brand.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
        ),
      );
}

/// An icon + one line of text (hidden when the text is empty).
class CInfoLine extends StatelessWidget {
  const CInfoLine(this.icon, this.text, {super.key, Color? color}) : _color = color;
  final IconData icon;
  final String text;
  final Color? _color;
  Color get color => _color ?? Brand.ink2;

  @override
  Widget build(BuildContext context) => text.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 15, color: Brand.ink3)),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: color, height: 1.3))),
          ]),
        );
}
