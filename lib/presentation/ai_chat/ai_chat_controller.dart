import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';

/// One block of a reply: an optional title, then text, a list of lines, or table rows.
class ChatSection {
  const ChatSection({this.title = '', this.body = '', this.items = const [], this.rows = const []});
  final String title;
  final String body;
  final List<String> items;

  /// Table rows, each already flattened to "Label: value  ·  Label: value".
  final List<String> rows;

  bool get isEmpty => title.isEmpty && body.isEmpty && items.isEmpty && rows.isEmpty;
}

class ChatMessage {
  ChatMessage.user(this.text)
      : mine = true,
        headline = '',
        sections = const [],
        followUps = const [],
        error = false;

  ChatMessage.bot({this.headline = '', this.sections = const [], this.followUps = const [], this.error = false})
      : mine = false,
        text = '';

  final bool mine;

  /// What the user typed.
  final String text;

  /// The assistant's one-line answer, then its detail blocks and suggested next questions.
  final String headline;
  final List<ChatSection> sections;
  final List<String> followUps;
  final bool error;
}

/// The assistant behind `POST /api/ai/ask` (the same pipeline the web chat panel uses). The server keeps the
/// thread, so each turn sends back the `conversation_id` it returned and follow-ups keep their context.
class AiChatController extends ChangeNotifier {
  AiChatController(this._api, {this.module});
  final LegacyApi _api;

  /// The server module the questions are answered in (null lets the server choose).
  final String? module;

  final List<ChatMessage> messages = [];
  bool sending = false;
  int? _conversationId;

  /// The last question, kept so a failed turn can be retried.
  String? _lastQuestion;

  Future<void> send(String raw) async {
    final q = raw.trim();
    if (q.isEmpty || sending) return;
    _lastQuestion = q;
    messages.add(ChatMessage.user(q));
    sending = true;
    notifyListeners();
    try {
      final res = await _api.post(
        '/api/ai/ask',
        withIdentity: false,
        body: {
          'question': q.length > 1000 ? q.substring(0, 1000) : q,
          if (_conversationId != null) 'conversation_id': _conversationId,
          'language': 'en',
          if (module != null) 'module': module,
        },
      );
      if (!LegacyApi.ok(res)) {
        final msg = LegacyApi.messageOf(res, 'The assistant could not answer that.');
        messages.add(ChatMessage.bot(headline: msg, error: true));
      } else {
        final data = res['data'];
        final d = data is Map ? data : const {};
        final conv = d['conversation'];
        if (conv is Map && conv['id'] != null) _conversationId = int.tryParse('${conv['id']}') ?? _conversationId;
        final answer = d['answer'] is Map ? d['answer'] as Map : const {};
        // The backend prefixes a "could not match a specific lookup" disclaimer when it falls back to an overview;
        // the overview's own figures follow it, so show those on their own.
        var headline = '${answer['headline'] ?? res['message'] ?? ''}'.trim();
        final stripped = headline.replaceFirst(RegExp(r'^I could not match that to a specific lookup[^.]*\.\s*', caseSensitive: false), '').trim();
        if (stripped.isNotEmpty) headline = stripped[0].toUpperCase() + stripped.substring(1);
        final sections = <ChatSection>[
          for (final s in (answer['sections'] is List ? answer['sections'] as List : const []))
            if (s is Map) _section(s),
        ].where((s) => !s.isEmpty && !_isProvenance(s)).toList();
        final followUps = [
          for (final f in (answer['follow_ups'] is List ? answer['follow_ups'] as List : const []))
            if (f is String && f.trim().isNotEmpty) f.trim() else if (f is Map && '${f['label'] ?? f['question'] ?? ''}'.trim().isNotEmpty) '${f['label'] ?? f['question']}'.trim(),
        ].take(4).toList();
        messages.add(ChatMessage.bot(
          headline: headline.isEmpty && sections.isEmpty ? 'I could not answer that.' : headline,
          sections: sections,
          followUps: followUps,
        ));
      }
    } on ApiException catch (e) {
      messages.add(ChatMessage.bot(headline: e.message, error: true));
    } catch (_) {
      messages.add(ChatMessage.bot(headline: 'Something went wrong. Try again.', error: true));
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  /// Asks the last question again after a failure (the failed reply is dropped first).
  Future<void> retry() async {
    final q = _lastQuestion;
    if (q == null || sending) return;
    if (messages.isNotEmpty && !messages.last.mine) messages.removeLast();
    if (messages.isNotEmpty && messages.last.mine) messages.removeLast();
    await send(q);
  }

  void newChat() {
    messages.clear();
    _conversationId = null;
    _lastQuestion = null;
    notifyListeners();
  }

  static String _flat(dynamic v) {
    if (v == null) return '';
    if (v is Map) {
      // A record with a name reads as "NAME  ·  Id: 12", not "Title: NAME  ·  Id: 12".
      for (final k in const ['name', 'title', 'label', 'student_name']) {
        final lead = '${v[k] ?? ''}'.trim();
        if (lead.isEmpty || v[k] is Map || v[k] is List) continue;
        final rest = v.entries
            .where((e) => e.key != k && '${e.value}'.trim().isNotEmpty && e.value is! Map && e.value is! List)
            .map((e) => '${_label(e.key)}: ${e.value}');
        return [lead, ...rest].join('  ·  ');
      }
      return v.entries.where((e) => '${e.value}'.trim().isNotEmpty && e.value is! Map && e.value is! List).map((e) => '${_label(e.key)}: ${e.value}').join('  ·  ');
    }
    if (v is List) return v.map(_flat).where((e) => e.isNotEmpty).join(', ');
    return '$v'.trim();
  }

  /// "Where this came from" is a note about the backend's lookup, not part of the answer.
  static bool _isProvenance(ChatSection s) => RegExp(r'^(where this came from|source|sources)$', caseSensitive: false).hasMatch(s.title);

  static String _label(Object? k) {
    final t = '$k'.replaceAll('_', ' ').trim();
    return t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1)}';
  }

  static ChatSection _section(Map s) {
    final items = s['items'] is List ? [for (final i in s['items'] as List) _flat(i)] : <String>[];
    final rows = s['rows'] is List ? [for (final r in s['rows'] as List) _flat(r)] : <String>[];
    return ChatSection(
      title: '${s['title'] ?? ''}'.trim(),
      body: '${s['body'] ?? s['text'] ?? ''}'.trim(),
      items: items.where((e) => e.isNotEmpty).toList(),
      rows: rows.where((e) => e.isNotEmpty).toList(),
    );
  }
}
