import 'package:flutter/material.dart';

import '../../../ui/theme.dart';

/// Shared look of the Student-module admin screens: navy summary card and filled inputs.

InputDecorationTheme studentInputTheme() => InputDecorationTheme(
      filled: true,
      fillColor: Brand.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.primary, width: 1.6)),
      labelStyle: TextStyle(color: Brand.ink3, fontSize: 14),
    );

/// Navy gradient hero: icon, title, subtitle and an optional row of small stat tiles.
class StudentHero extends StatelessWidget {
  const StudentHero({super.key, required this.title, required this.subtitle, required this.icon, this.stats = const []});
  final String title;
  final String subtitle;
  final IconData icon;

  /// (label, value) pairs shown as compact tiles under the title.
  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Brand.navy.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 17.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Brand.champagne, fontSize: 12.5)),
              ]),
            ),
          ]),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(stats[i].$2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                      Text(stats[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.champagne, fontSize: 11.5)),
                    ]),
                  ),
                ),
              ],
            ]),
          ],
        ]),
      );
}

/// A rounded chip used for choosing subjects and filters; indigo when selected.
class PickChip extends StatelessWidget {
  const PickChip({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        avatar: selected ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
        selectedColor: Brand.primary,
        backgroundColor: Brand.surface,
        labelStyle: TextStyle(color: selected ? Colors.white : Brand.ink2, fontWeight: FontWeight.w600, fontSize: 12.5),
        side: BorderSide(color: selected ? Brand.primary : Brand.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
}
