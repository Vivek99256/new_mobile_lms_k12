import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../kit/kit.dart';

const _violet = Color(0xFF7C3AED);

/// Graphs for the admission reports, drawn with plain painters (no chart package):
/// the 6-month trend bar chart.
class AdmissionCharts extends StatelessWidget {
  const AdmissionCharts({super.key, required this.rows, required this.noun});
  final List<Map<String, dynamic>> rows;

  /// "Enquiries" / "Registrations" / "Confirmations", for the card titles.
  final String noun;

  List<(DateTime, int)> _months() {
    final now = DateTime.now();
    final buckets = [for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i)];
    final counts = {for (final b in buckets) b: 0};
    for (final r in rows) {
      final d = DateTime.tryParse(s(r['created_on']).split(' ').first);
      if (d == null) continue;
      final key = DateTime(d.year, d.month);
      if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
    }
    return [for (final b in buckets) (b, counts[b]!)];
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Panel(
      title: '$noun · last 6 months',
      child: SizedBox(height: 150, child: _BarChart(data: _months())),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Brand.line),
          boxShadow: Brand.softShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Brand.ink)),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.data});
  final List<(DateTime, int)> data;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (_, t, _) => CustomPaint(painter: _BarPainter(data, t), size: Size.infinite),
      );
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.data, this.t);
  final List<(DateTime, int)> data;
  final double t;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 20.0, topPad = 18.0;
    final maxV = math.max(1, data.map((e) => e.$2).reduce(math.max));
    final chartH = size.height - labelH - topPad;
    final slot = size.width / data.length;
    final barW = math.min(30.0, slot * 0.56);

    // Faint guide lines.
    final guide = Paint()..color = Brand.line..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = topPad + chartH * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guide);
    }

    for (var i = 0; i < data.length; i++) {
      final v = data[i].$2;
      final h = chartH * (v / maxV) * t;
      final cx = slot * i + slot / 2;
      final isLast = i == data.length - 1;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barW / 2, topPad + chartH - h, barW, math.max(h, v == 0 ? 0 : 3)),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
        bottomLeft: const Radius.circular(3),
        bottomRight: const Radius.circular(3),
      );
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isLast ? const [_violet, Brand.primary] : [Brand.primary.withValues(alpha: 0.55), Brand.primary.withValues(alpha: 0.25)],
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);

      _text(canvas, '$v', Offset(cx, topPad + chartH - h - 14), 11.5, FontWeight.w800, Brand.ink, center: true);
      _text(canvas, _months[data[i].$1.month - 1], Offset(cx, size.height - labelH + 4), 11.5, isLast ? FontWeight.w700 : FontWeight.w500, isLast ? Brand.ink : Brand.muted, center: true);
    }
  }

  void _text(Canvas c, String s, Offset at, double size, FontWeight w, Color color, {bool center = false}) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: size, fontWeight: w, color: color)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, center ? at.translate(-tp.width / 2, 0) : at);
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.t != t || old.data != data;
}
