import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth_controller.dart';
import '../../core/legacy_api.dart';
import '../../ui/home_page.dart' show HomeRole, roleOf;
import '../../ui/theme.dart';
import 'ai_chat_controller.dart';

/// The AI assistant: ask in plain words (English, Hindi or Gujarati), get an answer from the school's own data.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  late final AiChatController _con;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final HomeRole _role;

  @override
  void initState() {
    super.initState();
    final session = context.read<AuthController>().session!;
    _role = roleOf(session.userProfileName);
    // Staff ask about the school's students, so those questions are read from the Students module, which counts
    // the whole class list for the academic year. Without a module the server falls back to a name search that
    // stops at 20 rows ("20 students" for a 3,428-student school).
    _con = AiChatController(LegacyApi(session), module: _role == HomeRole.student ? null : 'students')..addListener(_onChange);
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  void dispose() {
    _con.removeListener(_onChange);
    _con.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final q = (text ?? _input.text).trim();
    if (q.isEmpty || _con.sending) return;
    _input.clear();
    FocusScope.of(context).unfocus();
    _con.send(q);
  }

  List<String> get _suggestions => switch (_role) {
        HomeRole.student => const ['What can you help me with?', 'Explain photosynthesis in simple words', 'Give me tips to prepare for exams', 'What is 15% of 240?'],
        HomeRole.teacher => const ['What can you help me with?', 'Suggest a lesson plan for fractions', 'Give me 5 quiz questions on the water cycle', 'How do I explain gravity to class 6?'],
        HomeRole.admin => const ['How many students are there in total?', 'What can you help me with?', 'Show attendance summary for today', 'Which students have pending fees?'],
      };

  @override
  Widget build(BuildContext context) {
    final empty = _con.messages.isEmpty;
    return Scaffold(
      backgroundColor: Brand.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: const Row(children: [
          Icon(Icons.auto_awesome_rounded, size: 20, color: Brand.champagne),
          SizedBox(width: 8),
          Text('AI Assistant'),
        ]),
        actions: [
          if (!empty)
            IconButton(
              tooltip: 'New chat',
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: _con.sending ? null : _con.newChat,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: empty
              ? _welcome()
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  itemCount: _con.messages.length + (_con.sending ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _con.messages.length) return const _Typing();
                    final m = _con.messages[i];
                    return m.mine ? _UserBubble(m.text) : _BotBubble(message: m, isLast: i == _con.messages.length - 1, onAsk: _send, onRetry: _con.retry, busy: _con.sending);
                  },
                ),
        ),
        _composer(),
      ]),
    );
  }

  Widget _welcome() => ListView(padding: const EdgeInsets.fromLTRB(20, 28, 20, 20), children: [
        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Brand.primary, Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: Brand.primary.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 16),
        const Text('How can I help?', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Ask in English, Hindi or Gujarati.', textAlign: TextAlign.center, style: TextStyle(color: Brand.muted, fontSize: 13.5)),
        const SizedBox(height: 22),
        for (final s in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _send(s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: Brand.line)),
                child: Row(children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Brand.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(s, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                  Icon(Icons.north_east_rounded, size: 16, color: Brand.ink3),
                ]),
              ),
            ),
          ),
      ]);

  Widget _composer() => Container(
        padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.paddingOf(context).bottom + 10),
        decoration: BoxDecoration(color: Brand.card, border: Border(top: BorderSide(color: Brand.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              decoration: InputDecoration(
                hintText: 'Ask anything…',
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: Brand.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            height: 46,
            child: IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Brand.primary, disabledBackgroundColor: Brand.line),
              onPressed: _con.sending ? null : _send,
              icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
            ),
          ),
        ]),
      );
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
          margin: const EdgeInsets.only(bottom: 10, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Brand.primary,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4)),
          ),
          child: SelectableText(text, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.35)),
        ),
      );
}

class _BotBubble extends StatelessWidget {
  const _BotBubble({required this.message, required this.isLast, required this.onAsk, required this.onRetry, required this.busy});
  final ChatMessage message;
  final bool isLast;
  final ValueChanged<String> onAsk;
  final VoidCallback onRetry;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final m = message;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.92),
        margin: const EdgeInsets.only(bottom: 10, right: 16),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: m.error ? Brand.err0 : Colors.white,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
          border: Border.all(color: m.error ? Brand.err.withValues(alpha: 0.25) : Brand.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (m.headline.isNotEmpty)
            SelectableText(m.headline, style: TextStyle(fontSize: 14.5, height: 1.4, fontWeight: m.sections.isEmpty ? FontWeight.w500 : FontWeight.w800, color: m.error ? Brand.err : Brand.ink)),
          for (final s in m.sections) _section(s),
          if (m.error && isLast)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextButton.icon(onPressed: busy ? null : onRetry, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Try again')),
            ),
          if (m.followUps.isNotEmpty && isLast && !m.error)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final f in m.followUps)
                  ActionChip(
                    label: Text(f, style: TextStyle(fontSize: 12.5, color: Brand.primaryDark, fontWeight: FontWeight.w600)),
                    backgroundColor: Brand.tint,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onPressed: busy ? null : () => onAsk(f),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _section(ChatSection s) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (s.title.isNotEmpty) Text(s.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Brand.primaryDark)),
          if (s.body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: SelectableText(s.body, style: TextStyle(fontSize: 14, height: 1.45, color: Brand.ink2))),
          for (final i in s.items)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 7, right: 8), child: Icon(Icons.circle, size: 5, color: Brand.primary)),
                Expanded(child: SelectableText(i, style: TextStyle(fontSize: 14, height: 1.4, color: Brand.ink2))),
              ]),
            ),
          for (final r in s.rows)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: Brand.surface, borderRadius: BorderRadius.circular(10)),
              child: SelectableText(r, style: TextStyle(fontSize: 13, height: 1.35, color: Brand.ink2)),
            ),
        ]),
      );
}

/// "Thinking…" with three softly pulsing dots.
class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: Brand.line)),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: Brand.primary.withValues(alpha: 0.25 + 0.75 * (0.5 + 0.5 * _wave((_c.value - i * 0.18) % 1.0))),
                    shape: BoxShape.circle,
                  ),
                ),
            ]),
          ),
        ),
      );

  double _wave(double t) => t < 0.5 ? t * 2 : (1 - t) * 2;
}
