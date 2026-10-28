import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';

/// Small helpers shared by every ported student screen.
class Sx {
  Sx._();

  /// The feed endpoint when the tile carries one, else [fallback] (relative).
  static String url(ScreenArgs a, String fallback) => a.item.api.trim().isNotEmpty ? a.item.api.trim() : fallback;

  static Future<Map<String, dynamic>> call(ScreenArgs a, String url,
          {Map<String, dynamic> body = const {}, bool get = false}) =>
      get ? a.api.get(url, query: body) : a.api.post(url, body: body);

  /// Calls [url] and returns `data` as a list of maps. A failed envelope throws an
  /// [ApiException] carrying the server message (or returns an empty list if [silent]).
  static Future<List<Map<String, dynamic>>> list(ScreenArgs a, String url,
      {Map<String, dynamic> body = const {}, bool get = false, bool silent = false}) async {
    final res = await call(a, url, body: body, get: get);
    if (!LegacyApi.ok(res)) {
      if (silent) return const [];
      throw ApiException(LegacyApi.messageOf(res));
    }
    return rows(res['data']);
  }

  /// Resilience rule for the switched read screens: run [fresh] (the newer `/api/*` call);
  /// when it fails for any reason (HTTP error, `success:false`, permission refusal,
  /// unparsable body) run [legacy] once and log the reason. [fresh] must only be used for
  /// reads; never call this after a write has been accepted.
  static Future<T> newThenLegacy<T>(String screen, Future<T> Function() fresh, Future<T> Function() legacy) async {
    try {
      return await fresh();
    } catch (e) {
      final reason = e is ApiException ? e.message : '$e';
      debugPrint('api-migration: $screen fell back to legacy: $reason');
      return legacy();
    }
  }

  /// `data` of an envelope as a list: a list stays, a single object becomes one row.
  static List<Map<String, dynamic>> dataRows(dynamic d) => d is Map ? [Map<String, dynamic>.from(d)] : rows(d);

  /// Raw user record fields from login (std_name, standard_id, mobile, term_data...).
  static String raw(ScreenArgs a, String key) => s(a.session.raw[key]);
}

/// "14:30" / "14:30:00" -> "2:30 PM". Unparseable input is returned unchanged.
String time12(dynamic v) {
  final t = s(v);
  final parts = t.split(':');
  if (parts.length < 2) return t;
  final h = int.tryParse(parts[0]);
  final mi = int.tryParse(parts[1]);
  if (h == null || mi == null) return t;
  final suffix = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${mi.toString().padLeft(2, '0')} $suffix';
}

/// Relative time the way the old notification hub showed it.
String relativeTime(dynamic v, {DateTime? now}) {
  final raw = s(v);
  final d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  if (d == null) return raw;
  final diff = (now ?? DateTime.now()).difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hours ago';
  if (diff.inHours < 48) return '1 day ago';
  return DateFormat('dd MMM yy hh:mm a').format(d);
}

String indian(num n) {
  final f = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  return f.format(n);
}

num numOf(dynamic v) => num.tryParse(s(v).replaceAll(',', '')) ?? 0;

/// Strips the HTML entities the question bank escapes (&lt; &gt; &quot; &#39; &nbsp; &amp; numeric).
String decodeEntities(String input) {
  var out = input
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");
  out = out.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final c = int.tryParse(m[1]!);
    return c == null ? m[0]! : String.fromCharCode(c);
  });
  return out.replaceAll('&amp;', '&');
}

/// Whole-word-ish image extension test.
bool looksLikeImage(String url) => RegExp(r'\.(jpe?g|png|gif|webp|bmp)(\?|$)', caseSensitive: false).hasMatch(url);

// ---------------------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------------------

/// Renders server HTML; link taps open externally.
class HtmlBlock extends StatelessWidget {
  const HtmlBlock(this.html, {super.key, this.style});
  final String html;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => HtmlWidget(
        html,
        textStyle: style ?? const TextStyle(fontSize: 14, height: 1.45, color: Brand.text),
        onTapUrl: (u) async {
          final uri = Uri.tryParse(u);
          if (isSafeLaunchUri(uri)) await launchUrl(uri!, mode: LaunchMode.externalApplication);
          return true;
        },
      );
}

/// Plain text whose http(s) links are tappable.
class LinkText extends StatefulWidget {
  const LinkText(this.text, {super.key, this.maxLines, this.style});
  final String text;
  final int? maxLines;
  final TextStyle? style;

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final base = widget.style ?? const TextStyle(fontSize: 14, height: 1.4, color: Brand.text);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in RegExp(r'(https?://[^\s]+)').allMatches(widget.text)) {
      if (m.start > last) spans.add(TextSpan(text: widget.text.substring(last, m.start)));
      final url = m[0]!;
      final rec = TapGestureRecognizer()
        ..onTap = () {
          final u = Uri.tryParse(url);
          if (isSafeLaunchUri(u)) launchUrl(u!, mode: LaunchMode.externalApplication);
        };
      _recognizers.add(rec);
      spans.add(TextSpan(
          text: url, recognizer: rec, style: const TextStyle(color: Brand.primary, decoration: TextDecoration.underline)));
      last = m.end;
    }
    if (last < widget.text.length) spans.add(TextSpan(text: widget.text.substring(last)));
    return Text.rich(TextSpan(style: base, children: spans),
        maxLines: widget.maxLines, overflow: widget.maxLines == null ? null : TextOverflow.ellipsis);
  }
}

/// A card made of label / value rows (the old key-value cards).
class InfoRows extends StatelessWidget {
  const InfoRows(this.rowsData, {super.key, this.trailing});
  final List<(String, String)> rowsData;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => KitCard(
        child: Column(children: [
          for (var i = 0; i < rowsData.length; i++) ...[
            if (i > 0) const Divider(height: 14, color: Brand.border),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 4, child: Text(rowsData[i].$1, style: const TextStyle(color: Brand.muted, fontSize: 13))),
              Expanded(
                  flex: 6,
                  child: Text(rowsData[i].$2.isEmpty ? '-' : rowsData[i].$2,
                      textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            ]),
          ],
          if (trailing != null) ...[const SizedBox(height: 8), trailing!],
        ]),
      );
}

/// Count tile used by the calendars and the result screens.
class StatTile extends StatelessWidget {
  const StatTile(this.label, this.value, this.color, {super.key});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

/// Round attachment / link button; hidden when [url] is empty.
class AttachmentButton extends StatelessWidget {
  const AttachmentButton(this.url, {super.key, this.label = 'Attachment'});
  final String url;
  final String label;

  @override
  Widget build(BuildContext context) => url.isEmpty
      ? const SizedBox.shrink()
      : TextButton.icon(
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          onPressed: () => openUrl(context, url),
          icon: const Icon(Icons.attach_file_rounded, size: 18),
          label: Text(label),
        );
}

/// Config-driven list screen: one call, one card per row. Covers most info screens.
class SimpleList extends StatelessWidget {
  const SimpleList({
    super.key,
    required this.args,
    required this.title,
    required this.url,
    required this.itemBuilder,
    this.body = const {},
    this.get = false,
    this.silent = false,
    this.emptyText = 'Nothing to show yet.',
    this.emptyIcon = Icons.inbox_outlined,
    this.transform,
  });

  final ScreenArgs args;
  final String title;
  final String url;
  final Map<String, dynamic> body;
  final bool get;
  final bool silent;
  final String emptyText;
  final IconData emptyIcon;
  final Widget Function(BuildContext, Map<String, dynamic>, int) itemBuilder;
  final List<Map<String, dynamic>> Function(List<Map<String, dynamic>>)? transform;

  @override
  Widget build(BuildContext context) => KitPage(
        title: title,
        child: AsyncList(
          emptyText: emptyText,
          emptyIcon: emptyIcon,
          load: () async {
            final r = await Sx.list(args, url, body: body, get: get, silent: silent);
            return transform == null ? r : transform!(r);
          },
          itemBuilder: itemBuilder,
        ),
      );
}

/// Title for a screen: the tile's label, or [fallback] when empty.
String titleOf(ScreenArgs a, String fallback) => a.item.label.isEmpty ? fallback : a.item.label;

/// A loading / error / content wrapper for screens that load a single payload.
class AsyncBody<T> extends StatefulWidget {
  const AsyncBody({super.key, required this.load, required this.builder, this.isEmpty, this.emptyText = 'Nothing to show yet.'});
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, Future<void> Function() reload) builder;
  final bool Function(T)? isEmpty;
  final String emptyText;

  @override
  State<AsyncBody<T>> createState() => _AsyncBodyState<T>();
}

class _AsyncBodyState<T> extends State<AsyncBody<T>> {
  T? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.load();
      if (mounted) setState(() => _data = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _data == null) {
      return KitMessage(icon: Icons.cloud_off_outlined, text: _error!, action: 'Try again', onAction: _run);
    }
    final d = _data as T;
    if (widget.isEmpty != null && widget.isEmpty!(d)) {
      return RefreshIndicator(
        onRefresh: _run,
        child: ListView(children: [const SizedBox(height: 60), KitMessage(icon: Icons.inbox_outlined, text: widget.emptyText)]),
      );
    }
    return widget.builder(context, d, _run);
  }
}
