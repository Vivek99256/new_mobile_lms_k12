import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

/// Renders the I-card HTML the server returns for `student_icard/preview`.
///
/// The server sends one document: a `<style>` block (the template's CSS plus a print grid)
/// and one `<div class="item">` per student. The HTML widget only reads inline styles, so the
/// simple class / id / tag rules of the template are applied to matching elements here, and
/// each card is shown on its own, scaled down to fit the phone width.
class IcardCards extends StatelessWidget {
  const IcardCards({super.key, required this.html});
  final String html;

  static final _styleBlock = RegExp(r'<style[^>]*>(.*?)</style>', caseSensitive: false, dotAll: true);

  /// The HTML of each card (one per student).
  static List<String> splitCards(String html) {
    final withoutStyle = html.replaceAll(_styleBlock, '');
    final parts = withoutStyle.split(RegExp(r'<div class="item">'));
    return parts.length <= 1 ? [withoutStyle] : parts.sublist(1);
  }

  @override
  Widget build(BuildContext context) {
    final css = _styleBlock.allMatches(html).map((m) => m.group(1) ?? '').join('\n');
    final rules = _parseCss(css);
    final cards = splitCards(html);
    return Column(children: [
      for (var i = 0; i < cards.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE4E7F0))),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 450,
                child: HtmlWidget(
                  cards[i],
                  customStylesBuilder: (element) => _stylesFor(element, rules),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _Compound {
  _Compound(this.tag, this.id, this.classes);
  final String tag, id;
  final List<String> classes;
}

class _Rule {
  _Rule(this.chain, this.decls);
  final List<_Compound> chain; // descendant chain, last is the target
  final Map<String, String> decls;
}

final _compoundRe = RegExp(r'^([a-zA-Z][a-zA-Z0-9]*)?(#[\w-]+)?((?:\.[\w-]+)*)$');

List<_Rule> _parseCss(String css) {
  final out = <_Rule>[];
  final clean = css.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  for (final block in clean.split('}')) {
    final i = block.indexOf('{');
    if (i < 0) continue;
    final decls = <String, String>{};
    for (final d in block.substring(i + 1).split(';')) {
      final c = d.indexOf(':');
      if (c < 0) continue;
      final prop = d.substring(0, c).trim().toLowerCase();
      final value = d.substring(c + 1).replaceAll(RegExp(r'!important', caseSensitive: false), '').trim();
      if (prop.isEmpty || value.isEmpty || prop.startsWith('-') || prop.contains('clamp')) continue;
      if (prop == 'display' && value.contains('webkit')) continue;
      decls[prop] = value;
    }
    if (decls.isEmpty) continue;
    for (final sel in block.substring(0, i).split(',')) {
      final chain = <_Compound>[];
      var ok = true;
      for (final part in sel.trim().split(RegExp(r'\s+'))) {
        final m = _compoundRe.firstMatch(part);
        if (part.isEmpty || m == null) {
          ok = false;
          break;
        }
        chain.add(_Compound(
          (m.group(1) ?? '').toLowerCase(),
          (m.group(2) ?? '').replaceFirst('#', ''),
          (m.group(3) ?? '').split('.').where((e) => e.isNotEmpty).toList(),
        ));
      }
      if (ok && chain.isNotEmpty) out.add(_Rule(chain, decls));
    }
  }
  return out;
}

bool _matches(dynamic e, _Compound c) {
  try {
    if (c.tag.isNotEmpty && '${e.localName}'.toLowerCase() != c.tag) return false;
    if (c.id.isNotEmpty && '${e.id}' != c.id) return false;
    final have = <String>{for (final x in e.classes as Iterable) '$x'};
    return c.classes.every(have.contains);
  } catch (_) {
    return false;
  }
}

bool _ruleMatches(dynamic element, _Rule r) {
  if (!_matches(element, r.chain.last)) return false;
  var idx = r.chain.length - 2;
  dynamic node = element;
  while (idx >= 0) {
    node = _parentOf(node);
    if (node == null) return false;
    if (_matches(node, r.chain[idx])) idx--;
  }
  return true;
}

dynamic _parentOf(dynamic node) {
  try {
    return node.parent;
  } catch (_) {
    return null;
  }
}

Map<String, String>? _stylesFor(dynamic element, List<_Rule> rules) {
  Map<String, String>? out;
  for (final r in rules) {
    if (_ruleMatches(element, r)) (out ??= {}).addAll(r.decls);
  }
  return out;
}
