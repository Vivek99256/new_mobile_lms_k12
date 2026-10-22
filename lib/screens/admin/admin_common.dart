import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/legacy_api.dart';
import '../../core/session.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';

/// Helpers shared by the admin screens: PUT/DELETE calls (LegacyApi only has POST/GET),
/// success detection that accepts both `status` and `status_code`, and a student picker.

/// `status` or `status_code` as a string.
String statusOf(Map<String, dynamic> res) => '${res['status'] ?? res['status_code'] ?? ''}'.trim();

/// Strict success for writes: the envelope must say "1".
bool submitOk(Map<String, dynamic> res) => statusOf(res) == '1';

String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Academic year for the identity-less calls (the old app defaulted to "2021").
String syearOf(Session session) => session.mobileSyear ?? '';

/// PUT / DELETE with query-string parameters, the way the old ApiClient called them.
class AdminHttp {
  AdminHttp._();

  /// Tests inject a fake client here.
  static http.Client? client;

  static Future<Map<String, dynamic>> send(
    Session session,
    String method,
    String path, {
    Map<String, String> query = const {},
  }) async {
    final base = Uri.parse('${AppConfig.apiBase}$path');
    final uri = base.replace(queryParameters: {
      ...base.queryParameters,
      'type': 'API',
      'token': session.token,
      ...query,
    });
    final req = http.Request(method, uri)
      ..headers.addAll({'Accept': 'application/json', 'Authorization': 'Bearer ${session.token}'});
    final http.Response res;
    try {
      final c = client ?? http.Client();
      res = await http.Response.fromStream(await c.send(req)).timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Try again.');
    } catch (_) {
      throw ApiException('Check your internet connection and try again.');
    }
    if (res.statusCode >= 500) throw ApiException('The server had a problem. Try again shortly.');
    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      throw ApiException('The server returned an unexpected response.', statusCode: res.statusCode);
    }
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{'data': decoded};
    if (statusOf(map) == '2') {
      throw ApiException('${map['message'] ?? 'Your session has expired. Sign in again.'}', statusCode: 401);
    }
    return map;
  }

  static Future<Map<String, dynamic>> put(Session session, String path, Map<String, String> query) =>
      send(session, 'PUT', path, query: query);

  static Future<Map<String, dynamic>> delete(Session session, String path, [Map<String, String> query = const {}]) =>
      send(session, 'DELETE', path, query: query);
}

/// Adds simple submit-guard behaviour to a State.
mixin SubmitGuard<T extends StatefulWidget> on State<T> {
  bool busy = false;

  /// Runs [action] once at a time, turning ApiException into a toast. Returns true if
  /// [action] finished without throwing.
  Future<bool> guarded(Future<void> Function() action) async {
    if (busy) return false;
    setState(() => busy = true);
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Toast the server message and report whether [res] was a success.
  bool report(Map<String, dynamic> res, {String ok = 'Saved.'}) {
    final good = submitOk(res);
    toast(context, LegacyApi.messageOf(res, good ? ok : 'Something went wrong.'), error: !good);
    return good;
  }
}

/// A "field is required" toast helper: returns true (and toasts) when [value] is empty.
bool missing(BuildContext context, String? value, String message) {
  if (value == null || value.trim().isEmpty) {
    toast(context, message, error: true);
    return true;
  }
  return false;
}

Widget gap([double h = 12]) => SizedBox(height: h);

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Brand.text)),
      );
}

/// Pinned submit bar used by the form screens.
Widget formBar({required String label, required bool busy, required VoidCallback? onPressed, Color? color}) =>
    PrimaryButton(label: label, onPressed: onPressed, busy: busy, color: color);

/// Opens a detail/edit/receipt screen and returns whatever it pops with.
Future<T?> push<T>(BuildContext context, Widget screen) =>
    Navigator.push<T>(context, MaterialPageRoute(builder: (_) => screen));

/// A student row used by pickers and lists.
class StudentTile extends StatelessWidget {
  const StudentTile({super.key, required this.student, this.onTap, this.leading, this.trailing, this.showMobile = false});
  final Map<String, dynamic> student;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final bool showMobile;

  @override
  Widget build(BuildContext context) {
    final cls = [s(student['standard_name']), s(student['division_name'])].where((e) => e.isNotEmpty).join(' - ');
    return KitCard(
      onTap: onTap,
      child: Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        PersonAvatar(url: s(student['student_image']), name: s(student['student_name'])),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s(student['student_name']), style: const TextStyle(fontWeight: FontWeight.w700)),
            if (cls.isNotEmpty) Text(cls, style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
            Text(
              [
                if (s(student['roll_no']).isNotEmpty) 'Roll No. ${s(student['roll_no'])}',
                if (s(student['enrollment_no']).isNotEmpty) 'GR No. ${s(student['enrollment_no'])}',
              ].join('   '),
              style: const TextStyle(color: Brand.muted, fontSize: 12.5),
            ),
            if (showMobile && s(student['mobile']).isNotEmpty)
              Text('+91${s(student['mobile'])}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

/// Section > Standard > Division (> Subject) filter, a Search button and the resulting
/// student list. With [selectable] each row has a checkbox (and a Select all row).
///
/// The parent learns about results/selection through [onChanged].
class StudentPicker extends StatefulWidget {
  const StudentPicker({
    super.key,
    required this.api,
    required this.onChanged,
    this.endpoint = '/get_adminStudentList',
    this.withSubject = false,
    this.selectable = true,
    this.needDivision = false,
    this.onOpen,
    this.openLabel,
  });

  final LegacyApi api;
  final String endpoint;
  final bool withSubject;
  final bool selectable;

  /// Division mandatory for Search (capture-photos, fees).
  final bool needDivision;
  final void Function(List<Map<String, dynamic>> all, List<Map<String, dynamic>> selected, CascadeSelection filter) onChanged;

  /// For non-selectable lists: tap handler per student (and an optional button label).
  final void Function(Map<String, dynamic> student, CascadeSelection filter)? onOpen;
  final String? openLabel;

  @override
  State<StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<StudentPicker> {
  CascadeSelection sel = CascadeSelection();
  List<Map<String, dynamic>>? students;
  final selected = <String>{};
  bool searching = false;
  String? error;

  bool get canSearch {
    if (sel.sectionId == null || sel.standardId == null) return false;
    if (widget.needDivision && sel.divisionId == null) return false;
    if (widget.withSubject && sel.subjectId == null) return false;
    return true;
  }

  String _id(Map<String, dynamic> st) => s(st['id']);

  void _emit() {
    final all = students ?? const <Map<String, dynamic>>[];
    widget.onChanged(all, [for (final st in all) if (selected.contains(_id(st))) st], sel);
  }

  Future<void> _search() async {
    if (searching) return;
    setState(() {
      searching = true;
      error = null;
    });
    try {
      final res = await widget.api.post(widget.endpoint, body: {
        'grade_id': sel.sectionId,
        'standard_id': sel.standardId,
        'division_id': sel.divisionId,
      });
      if (!mounted) return;
      if (!LegacyApi.ok(res) && statusOf(res) == '0') {
        setState(() {
          students = const [];
          error = LegacyApi.messageOf(res);
        });
      } else {
        selected.clear();
        setState(() => students = rows(res['data']));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => searching = false);
    }
    if (mounted) _emit();
  }

  void _onFilter(CascadeSelection v) {
    // Any change to the filter invalidates the previous result.
    final changed = students != null;
    setState(() {
      sel = v;
      if (changed) {
        students = null;
        selected.clear();
      }
    });
    if (changed) _emit();
  }

  @override
  Widget build(BuildContext context) {
    final list = students;
    final allSelected = list != null && list.isNotEmpty && list.every((st) => selected.contains(_id(st)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CascadeFilter(api: widget.api, withSubject: widget.withSubject, onChanged: _onFilter),
      gap(14),
      PrimaryButton(label: 'Search students', busy: searching, onPressed: canSearch ? _search : null),
      gap(14),
      if (error != null) KitMessage(icon: Icons.cloud_off_outlined, text: error!, action: 'Try again', onAction: _search),
      if (list != null && list.isEmpty && error == null)
        const KitMessage(icon: Icons.people_outline, text: 'No students found for this class.'),
      if (list != null && list.isNotEmpty) ...[
        if (widget.selectable)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text('Select all (${selected.length} of ${list.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
            value: allSelected,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  selected.addAll(list.map(_id));
                } else {
                  selected.clear();
                }
              });
              _emit();
            },
          ),
        for (final st in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: StudentTile(
              student: st,
              showMobile: widget.selectable,
              onTap: widget.selectable
                  ? () {
                      setState(() => selected.contains(_id(st)) ? selected.remove(_id(st)) : selected.add(_id(st)));
                      _emit();
                    }
                  : (widget.onOpen == null ? null : () => widget.onOpen!(st, sel)),
              leading: widget.selectable
                  ? Checkbox(
                      value: selected.contains(_id(st)),
                      onChanged: (v) {
                        setState(() => v == true ? selected.add(_id(st)) : selected.remove(_id(st)));
                        _emit();
                      },
                    )
                  : null,
              trailing: !widget.selectable && widget.openLabel != null
                  ? FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
                      onPressed: widget.onOpen == null ? null : () => widget.onOpen!(st, sel),
                      child: Text(widget.openLabel!),
                    )
                  : (widget.selectable ? null : const Icon(Icons.chevron_right_rounded, color: Brand.muted)),
            ),
          ),
      ],
    ]);
  }
}

/// Convenience for building a `ScreenArgs`-less sub screen.
typedef AdminArgs = ScreenArgs;
