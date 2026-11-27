import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/api_client.dart';
import '../../../core/config.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import '../student_module/student_ui.dart';

/// Shared pieces of the Student Report screens (group B): the hero, the filter card, small helpers.

const bMonths = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const bMonthsShort = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

int bInt(dynamic v) => int.tryParse(s(v)) ?? double.tryParse(s(v))?.round() ?? 0;

/// A JSON object whose keys were 0..n-1 comes back as a list: read both shapes as a map.
Map<String, dynamic> bMap(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  if (v is List) return {for (var i = 0; i < v.length; i++) '$i': v[i]};
  return {};
}

String bStudentName(Map<String, dynamic> r) {
  final direct = s(r['student_name']);
  if (direct.isNotEmpty) return direct;
  final parts = [s(r['first_name']), s(r['middle_name']), s(r['last_name'])].where((e) => e.isNotEmpty).toList();
  return parts.isEmpty ? 'Student' : parts.join(' ');
}

/// "2026-11-17 10:30:00" -> "17 Nov 2026".
String bDate(dynamic v) {
  final t = s(v);
  if (t.isEmpty) return '';
  final d = DateTime.tryParse(t.split(' ').first);
  if (d == null) return t;
  return '${d.day} ${bMonthsShort[d.month]} ${d.year}';
}

/// The navy summary card at the top of a report.
class BHero extends StatelessWidget {
  const BHero({super.key, required this.icon, required this.title, required this.subtitle, this.stats = const []});
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
            const SizedBox(width: 14),
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

/// The white card holding a report's filters and its Show button.
class BFilterCard extends StatelessWidget {
  const BFilterCard({super.key, required this.children, required this.onShow, required this.busy, this.label = 'Show report', this.title = 'Filters'});
  final List<Widget> children;
  final VoidCallback onShow;
  final bool busy;
  final String label;
  final String title;

  @override
  Widget build(BuildContext context) => SoftCard(
        radius: 20,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const IconTile(Icons.tune_rounded, size: 30),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
          const SizedBox(height: 14),
          for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: busy ? null : onShow,
              icon: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search_rounded),
              label: Text(busy ? 'Loading…' : label),
            ),
          ),
        ]),
      );
}

/// A date that may be left empty (shows a clear button once picked).
class BOptionalDate extends StatelessWidget {
  const BOptionalDate({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: DateField(label: label, value: value, onChanged: onChanged)),
        if (value != null) IconButton(tooltip: 'Clear', onPressed: () => onChanged(null), icon: const Icon(Icons.close_rounded, size: 20)),
      ]);
}

/// A search box for filtering the loaded cards.
class BSearchBox extends StatelessWidget {
  const BSearchBox({super.key, required this.hint, required this.onChanged});
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

/// Label above a value (used inside report cards).
class BKeyValue extends StatelessWidget {
  const BKeyValue(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 104, child: Text(label, style: TextStyle(color: Brand.muted, fontSize: 12.5))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
      );
}

/// Present-share bar: green over a light track.
class BBar extends StatelessWidget {
  const BBar(this.fraction, {super.key, Color? color}) : _color = color;
  final double fraction;
  final Color? _color;
  Color get color => _color ?? Brand.ok;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(value: fraction.clamp(0.0, 1.0), minHeight: 7, backgroundColor: Brand.field, color: color),
      );
}

/// Runs [load] and turns failures into a message; used by every screen so errors read the same.
Future<String?> bGuard(Future<void> Function() load) async {
  try {
    await load();
    return null;
  } on ApiException catch (e) {
    return e.message.toLowerCase().contains('unexpected response') ? 'This report is not available right now. Try again shortly.' : e.message;
  } catch (_) {
    return 'Could not load this report. Try again.';
  }
}

/// A page showing an HTML certificate on an A4 sheet scaled to the phone, with pinch-zoom and Print.
class BHtmlPage extends StatelessWidget {
  const BHtmlPage({super.key, required this.title, required this.html});
  final String title;
  final String html;

  Future<void> _print(BuildContext context) async {
    final doc = '<html><head><meta charset="utf-8"><style>@page{size:A4;margin:10mm}body{margin:0;font-family:sans-serif}</style></head><body>$html</body></html>';
    try {
      await Printing.layoutPdf(
        name: title,
        format: PdfPageFormat.a4,
        // ignore: deprecated_member_use
        onLayout: (format) => Printing.convertHtml(format: format, html: doc, baseUrl: AppConfig.apiBase),
      );
    } catch (e) {
      if (context.mounted) toast(context, "Couldn't print: $e", error: true);
    }
  }

  @override
  Widget build(BuildContext context) => KitPage(
        title: title,
        actions: [IconButton(tooltip: 'Print / Save as PDF', icon: const Icon(Icons.print_rounded), onPressed: () => _print(context))],
        child: LayoutBuilder(builder: (context, box) {
          const sheet = 794.0;
          return InteractiveViewer(
            constrained: false,
            minScale: 1,
            maxScale: 4,
            boundaryMargin: EdgeInsets.zero,
            child: SizedBox(
              width: box.maxWidth,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                  child: ColoredBox(color: Colors.white, child: SizedBox(width: sheet, child: Padding(padding: const EdgeInsets.all(24), child: HtmlWidget(html)))),
                ),
              ),
            ),
          );
        }),
      );
}

/// The page frame every group-B screen uses: input theme, padding, list of children.
Widget bPage(BuildContext context, String title, List<Widget> children) => KitPage(
      title: title,
      child: withStudentInputs(context, ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 28), children: children)),
    );

/// First day of the academic year containing today (1 April).
DateTime bAcademicStart() {
  final n = DateTime.now();
  return DateTime(n.month >= 4 ? n.year : n.year - 1, 4, 1);
}

String bYmd(DateTime d) => ymd(d);
