import 'package:flutter/material.dart';

import '../../../ui/theme.dart';

/// Small pieces shared by the Student report screens.

/// A rounded search box that filters a loaded list.
Widget reportSearchField({required ValueChanged<String> onChanged, String hint = 'Search'}) => TextField(
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

/// Label / value pairs laid out two to a row (no LayoutBuilder, so long lists stay light).
Widget labelValueGrid(List<(String, String)> items) {
  final rows = <Widget>[];
  for (var i = 0; i < items.length; i += 2) {
    final pair = items.sublist(i, i + 2 > items.length ? items.length : i + 2);
    rows.add(Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var j = 0; j < 2; j++) ...[
          if (j > 0) const SizedBox(width: 10),
          Expanded(child: j < pair.length ? _labelValue(pair[j].$1, pair[j].$2) : const SizedBox.shrink()),
        ],
      ]),
    ));
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
}

Widget _labelValue(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Brand.muted, fontSize: 11.5)),
      const SizedBox(height: 2),
      Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
    ]);

/// A slim rounded bar showing [value] out of [max].
class MiniBar extends StatelessWidget {
  const MiniBar({super.key, required this.value, required this.max, this.color = Brand.primary});
  final num value;
  final num max;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(value: max <= 0 ? 0 : (value / max).clamp(0, 1).toDouble(), minHeight: 6, backgroundColor: Brand.line, color: color),
      );
}

/// A small coloured "Boys 12" style chip.
Widget countChip(String label, num value, Color fg, Color bg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(color: fg, fontSize: 11.5)),
        const SizedBox(width: 6),
        Text('$value', style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 13)),
      ]),
    );

int toInt(dynamic v) => int.tryParse('$v'.trim()) ?? (num.tryParse('$v'.trim())?.toInt() ?? 0);
