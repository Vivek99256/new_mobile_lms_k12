import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';

/// Shared by Student Infirmary, Vaccination, Height Weight and Health: the student search the
/// web uses, the write/delete calls, validation and the small widgets all four screens share.

/// A student returned by `GET /student-infirmary/students`.
class CareStudent {
  CareStudent(Map<String, dynamic> r)
      : id = s(r['id']),
        enrollmentNo = s(r['enrollment_no']),
        name = s(r['student_name']);
  final String id, enrollmentNo, name;
}

/// Web rule: a doctor contact, when typed, is a 10-digit mobile number starting with 6-9.
String doctorContactError(String v) {
  final t = v.trim();
  if (t.isEmpty) return '';
  return RegExp(r'^[6-9]\d{9}$').hasMatch(t) ? '' : 'Enter a valid 10-digit contact number starting with 6-9.';
}

/// `yyyy-MM-dd` text from whatever the API returned (it may carry a time part).
DateTime? parseDay(String v) {
  final t = v.trim();
  if (t.length < 10) return null;
  return DateTime.tryParse(t.substring(0, 10));
}

/// The server's message, with the first field error appended when validation failed (422).
String careMessage(Map<String, dynamic> res, String fallback) {
  var msg = LegacyApi.messageOf(res, fallback);
  final errors = res['errors'];
  if (errors is Map && errors.isNotEmpty) {
    final first = errors.values.first;
    final text = first is List && first.isNotEmpty ? '${first.first}' : '$first';
    if (text.isNotEmpty) msg = '$msg $text';
  }
  return msg;
}

/// API calls shared by the four screens. All routes live in `routes/adminapi.php` (JWT only).
class CareApi {
  CareApi(this.args);
  final ScreenArgs args;
  LegacyApi get _api => args.api;

  /// `student-infirmary/students` (also used by the care screens): needs at least 2 characters.
  Future<List<CareStudent>> searchStudents(String q) async {
    final res = await _api.get('/student-infirmary/students', query: {'query': q});
    if (statusOf(res) != '1') throw ApiException(careMessage(res, "Couldn't search students. Try again."));
    return rows(res['data']).map(CareStudent.new).toList();
  }

  /// Create (POST) or update (POST with `_method=PUT`, so a file can travel in the same request).
  Future<(bool, String)> save(String path, String? id, Map<String, dynamic> body) async {
    try {
      final res = await _api.post(id == null ? path : '$path/$id', body: {...body, if (id != null) '_method': 'PUT'});
      final ok = statusOf(res) == '1';
      return (ok, careMessage(res, ok ? 'Saved.' : "Couldn't save. Check the details and try again."));
    } on ApiException catch (e) {
      return (false, e.message);
    }
  }

  Future<(bool, String)> delete(String path, String id) async {
    try {
      final session = args.session;
      final res = await AdminHttp.delete(session, '$path/$id', {
        'sub_institute_id': '${session.subInstituteId}',
        'syear': syearOf(session),
        'user_id': '${session.userId}',
      });
      final ok = statusOf(res) == '1';
      return (ok, careMessage(res, ok ? 'Deleted.' : "Couldn't delete. Try again."));
    } on ApiException catch (e) {
      return (false, e.message);
    }
  }
}

// -------------------------------------------------------------------------------------
// Shared widgets
// -------------------------------------------------------------------------------------

InputDecorationTheme careInputTheme() => InputDecorationTheme(
      filled: true,
      fillColor: Brand.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.primary, width: 1.6)),
    );

/// A titled white card used to group form fields.
Widget careGroup(String title, IconData icon, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SoftCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconTile(icon, size: 30),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
          const SizedBox(height: 14),
          for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 14), child: c),
        ]),
      ),
    );

/// Navy summary strip: a big number and its label, then small stat chips.
class CareHero extends StatelessWidget {
  const CareHero({super.key, required this.count, required this.label, this.chips = const []});
  final int count;
  final String label;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          CountUp(value: count, builder: (v) => Text('$v', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1))),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Brand.champagne, fontSize: 13)),
          const Spacer(),
          Wrap(spacing: 6, children: chips),
        ]),
      );
}

/// The search box above a list.
class CareSearchBar extends StatelessWidget {
  const CareSearchBar({super.key, required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: Brand.card,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
        ),
      );
}

/// A small "label / value" tile for a record card.
class CareFact extends StatelessWidget {
  const CareFact(this.label, this.value, {super.key});
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: Brand.surface, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(color: Brand.muted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '-' : value, style: TextStyle(color: Brand.ink, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Lays [facts] out two per row.
Widget careFactGrid(List<CareFact> facts) => LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 8) / 2;
        return Wrap(spacing: 8, runSpacing: 8, children: [for (final f in facts) SizedBox(width: w, child: f)]);
      },
    );

/// Edit / delete menu for a record card.
class CareMenu extends StatelessWidget {
  const CareMenu({super.key, required this.onEdit, required this.onDelete});
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        icon: Icon(Icons.more_vert_rounded, color: Brand.muted),
        onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      );
}

/// The student field of a form: tap to search by name or GR number (2+ characters).
class StudentPickerField extends StatelessWidget {
  const StudentPickerField({super.key, required this.api, required this.name, required this.onPicked, this.locked = false});
  final CareApi api;
  final String name;
  final ValueChanged<CareStudent> onPicked;

  /// When editing, the student cannot change (same as the web).
  final bool locked;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<CareStudent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Brand.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _StudentSearchSheet(api: api),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: locked ? null : () => _open(context),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Student *',
            suffixIcon: Icon(locked ? Icons.lock_outline_rounded : Icons.search_rounded, size: 20),
          ),
          child: Text(name.isEmpty ? 'Search by name or GR no' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: name.isEmpty ? Brand.muted : Brand.ink)),
        ),
      );
}

class _StudentSearchSheet extends StatefulWidget {
  const _StudentSearchSheet({required this.api});
  final CareApi api;

  @override
  State<_StudentSearchSheet> createState() => _StudentSearchSheetState();
}

class _StudentSearchSheetState extends State<_StudentSearchSheet> {
  final _text = TextEditingController();
  Timer? _debounce;
  List<CareStudent> _results = [];
  bool _busy = false;
  String? _error;
  String _asked = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    final q = v.trim();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _error = null;
        _busy = false;
        _asked = '';
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(q));
  }

  Future<void> _run(String q) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.api.searchStudents(q);
      if (!mounted || _text.text.trim() != q) return;
      setState(() {
        _results = r;
        _asked = q;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Brand.border, borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              controller: _text,
              autofocus: true,
              onChanged: _changed,
              decoration: InputDecoration(
                hintText: 'Student name or GR no (2+ letters)',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Brand.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _error != null
                ? Center(child: Text(_error!, style: TextStyle(color: Brand.err)))
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          _asked.isEmpty ? 'Type at least 2 characters.' : 'No students found.',
                          style: TextStyle(color: Brand.muted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => Divider(height: 1, color: Brand.line),
                        itemBuilder: (_, i) {
                          final st = _results[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: PersonAvatar(url: '', name: st.name, radius: 20),
                            title: Text(st.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('GR ${st.enrollmentNo}', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
                            onTap: () => Navigator.pop(context, st),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}
