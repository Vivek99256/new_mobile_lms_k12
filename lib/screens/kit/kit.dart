import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';

/// Shared building blocks for the ported screens: a page frame, async loading, form fields
/// and the cascading Section > Standard > Division filter the old app used everywhere.

// ---------------------------------------------------------------------------------------
// Page frame, feedback
// ---------------------------------------------------------------------------------------

class KitPage extends StatelessWidget {
  const KitPage({super.key, required this.title, required this.child, this.actions = const [], this.bottom});
  final String title;
  final Widget child;
  final List<Widget> actions;

  /// Pinned below the body (a Save / Submit bar).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Brand.surface,
        appBar: AppBar(
          titleSpacing: 0,
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [...actions, const SizedBox(width: 4)],
        ),
        body: child,
        bottomNavigationBar: bottom == null
            ? null
            : Container(
                padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 12),
                decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Brand.line))),
                child: bottom,
              ),
      );
}

void toast(BuildContext context, String message, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? Brand.err : Brand.ok,
    ));
}

Future<bool> confirm(BuildContext context, String title, String message, {String yes = 'Yes'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(90, 42)), onPressed: () => Navigator.pop(context, true), child: Text(yes)),
      ],
    ),
  );
  return r ?? false;
}

/// Links come from server data (menu rows, HTML content), so only web, mail and phone links open.
/// `intent:`, `file:`, `javascript:` and app-specific schemes are never launched.
bool isSafeLaunchUri(Uri? uri) {
  if (uri == null) return false;
  const allowed = {'http', 'https', 'mailto', 'tel'};
  if (!allowed.contains(uri.scheme.toLowerCase())) return false;
  // user:password@host is the classic look-alike trick.
  if ((uri.scheme == 'http' || uri.scheme == 'https') && (uri.host.isEmpty || uri.userInfo.isNotEmpty)) return false;
  return true;
}

Future<void> openUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (!isSafeLaunchUri(uri) || !await launchUrl(uri!, mode: LaunchMode.externalApplication)) {
    if (context.mounted) toast(context, 'Could not open this file.', error: true);
  }
}

// ---------------------------------------------------------------------------------------
// Async list
// ---------------------------------------------------------------------------------------

String s(dynamic v) => v == null ? '' : '$v'.trim();
Map<String, dynamic> m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> rows(dynamic v) =>
    v is List ? [for (final r in v) if (r is Map) Map<String, dynamic>.from(r)] : const [];

String fmtDate(dynamic v, {String out = 'dd MMM yyyy'}) {
  final raw = s(v);
  if (raw.isEmpty) return '';
  final d = DateTime.tryParse(raw.length > 10 ? raw.substring(0, 19).replaceFirst(' ', 'T') : raw);
  return d == null ? raw : DateFormat(out).format(d);
}

/// Loads a list once, supports pull-to-refresh and renders loading / error / empty states.
class AsyncList extends StatefulWidget {
  const AsyncList({
    super.key,
    required this.load,
    required this.itemBuilder,
    this.emptyText = 'Nothing to show yet.',
    this.emptyIcon = Icons.inbox_outlined,
    this.header,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
    this.controller,
  });

  final Future<List<Map<String, dynamic>>> Function() load;
  final Widget Function(BuildContext, Map<String, dynamic>, int) itemBuilder;
  final String emptyText;
  final IconData emptyIcon;
  final Widget? header;
  final EdgeInsets padding;
  final AsyncListController? controller;

  @override
  State<AsyncList> createState() => _AsyncListState();
}

class AsyncListController {
  Future<void> Function()? _reload;
  Future<void> reload() async => _reload?.call();
}

class _AsyncListState extends State<AsyncList> {
  List<Map<String, dynamic>>? _items;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.controller?._reload = _run;
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.load();
      if (mounted) setState(() => _items = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items == null) return KitMessage(icon: Icons.cloud_off_outlined, text: _error!, action: 'Try again', onAction: _run);
    final items = _items ?? const [];
    return RefreshIndicator(
      onRefresh: _run,
      child: items.isEmpty
          ? ListView(children: [
              if (widget.header != null) Padding(padding: widget.padding, child: widget.header),
              const SizedBox(height: 60),
              KitMessage(icon: widget.emptyIcon, text: widget.emptyText),
            ])
          : ListView.separated(
              padding: widget.padding,
              itemCount: items.length + (widget.header == null ? 0 : 1),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (c, i) {
                if (widget.header != null) {
                  if (i == 0) return widget.header!;
                  i -= 1;
                }
                return widget.itemBuilder(c, items[i], i);
              },
            ),
    );
  }
}

class KitMessage extends StatelessWidget {
  const KitMessage({super.key, required this.icon, required this.text, this.action, this.onAction});
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 44, color: const Color(0xFFC9CDE3)),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Brand.muted)),
            if (action != null) ...[
              const SizedBox(height: 14),
              FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(140, 44)), onPressed: onAction, child: Text(action!)),
            ],
          ]),
        ),
      );
}

// ---------------------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------------------

class KitCard extends StatelessWidget {
  const KitCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Brand.line), boxShadow: Brand.softShadow),
          child: child,
        ),
      );
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = Brand.primary});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color == Brand.primary ? Brand.tint : color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(color: color == Brand.primary ? Brand.primaryDark : color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class KV extends StatelessWidget {
  const KV(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => value.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 104, child: Text(label, style: const TextStyle(color: Brand.muted, fontSize: 12.5))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13.5))),
          ]),
        );
}

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.url, required this.name, this.radius = 24});
  final String url;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty ? '?' : (parts.length == 1 ? parts.first[0] : parts.first[0] + parts.last[0]).toUpperCase();
    final d = radius * 2;
    final fallback = Center(child: Text(initials, style: TextStyle(color: Brand.primaryDark, fontWeight: FontWeight.w600, fontSize: radius * .7)));
    return Container(
      width: d,
      height: d,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: Brand.tint1, shape: BoxShape.circle),
      child: url.isEmpty ? fallback : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
    );
  }
}

// ---------------------------------------------------------------------------------------
// Form fields
// ---------------------------------------------------------------------------------------

class Opt {
  const Opt(this.id, this.label);
  final String id;
  final String label;
}

class DropdownField extends StatelessWidget {
  const DropdownField({super.key, required this.label, required this.options, required this.value, required this.onChanged, this.loading = false, this.enabled = true});
  final String label;
  final List<Opt> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        key: ValueKey('$label-${options.length}-$value'),
        initialValue: options.any((o) => o.id == value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: loading ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) : null,
        ),
        items: [for (final o in options) DropdownMenuItem(value: o.id, child: Text(o.label, overflow: TextOverflow.ellipsis))],
        onChanged: enabled && options.isNotEmpty ? onChanged : null,
      );
}

class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.first, this.last, this.format = 'yyyy-MM-dd'});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? first;
  final DateTime? last;
  final String format;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: first ?? DateTime(1950),
            lastDate: last ?? DateTime(2101),
          );
          if (d != null) onChanged(d);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20)),
          child: Text(value == null ? 'Select date' : DateFormat(format).format(value!), style: TextStyle(color: value == null ? Brand.muted : Brand.text)),
        ),
      );
}

class TimeField extends StatelessWidget {
  const TimeField({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final t = await showTimePicker(context: context, initialTime: value ?? TimeOfDay.now());
          if (t != null) onChanged(t);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.access_time, size: 20)),
          child: Text(value == null ? 'Select time' : value!.format(context), style: TextStyle(color: value == null ? Brand.muted : Brand.text)),
        ),
      );
}

class TextInput extends StatelessWidget {
  const TextInput({super.key, required this.label, required this.controller, this.lines = 1, this.keyboard, this.hint});
  final String label;
  final TextEditingController controller;
  final int lines;
  final TextInputType? keyboard;
  final String? hint;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboard ?? (lines > 1 ? TextInputType.multiline : TextInputType.text),
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 3,
        decoration: InputDecoration(labelText: label, hintText: hint, alignLabelWithHint: lines > 1),
      );
}

/// A single chosen file (path + display name).
class PickedFile {
  const PickedFile(this.path, this.name);
  final String path;
  final String name;
  UploadFile asUpload(String field) => UploadFile(field, path);
}

class FileField extends StatelessWidget {
  const FileField({super.key, required this.label, required this.file, required this.onChanged, this.extensions = const ['jpg', 'jpeg', 'png', 'pdf']});
  final String label;
  final PickedFile? file;
  final ValueChanged<PickedFile?> onChanged;
  final List<String> extensions;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: extensions);
          if (picked.isNotEmpty && picked.first.path != null) {
            onChanged(PickedFile(picked.first.path!, picked.first.name));
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: file == null
                ? const Icon(Icons.attach_file_rounded)
                : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => onChanged(null)),
          ),
          child: Text(file?.name ?? 'Choose file', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: file == null ? Brand.muted : Brand.text)),
        ),
      );
}

/// Bottom action button with a busy state.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.busy = false, this.color});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final Color? color;

  @override
  Widget build(BuildContext context) => FilledButton(
        style: FilledButton.styleFrom(backgroundColor: color, minimumSize: const Size.fromHeight(48)),
        onPressed: busy ? null : onPressed,
        child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(label),
      );
}

// ---------------------------------------------------------------------------------------
// Section > Standard > Division [> Subject] cascade
// ---------------------------------------------------------------------------------------

class CascadeSelection {
  String? sectionId, standardId, divisionId, subjectId;
  String? sectionName, standardName, divisionName, subjectName;
}

/// The old app's CASCADE-A: pick a section, then its standards, then divisions (and
/// optionally subjects). Each level loads when the one above it is chosen.
class CascadeFilter extends StatefulWidget {
  const CascadeFilter({super.key, required this.api, required this.onChanged, this.withSubject = false, this.withDivision = true});
  final LegacyApi api;
  final ValueChanged<CascadeSelection> onChanged;
  final bool withSubject;
  final bool withDivision;

  @override
  State<CascadeFilter> createState() => _CascadeFilterState();
}

class _CascadeFilterState extends State<CascadeFilter> {
  final sel = CascadeSelection();
  List<Opt> sections = [], standards = [], divisions = [], subjects = [];
  bool loadingSec = true, loadingStd = false, loadingDiv = false, loadingSub = false;

  @override
  void initState() {
    super.initState();
    _sections();
  }

  Future<List<Map<String, dynamic>>> _fetch(String path, [Map<String, dynamic> extra = const {}]) async {
    try {
      final res = await widget.api.post(path, body: extra);
      return LegacyApi.ok(res) ? rows(res['data']) : const [];
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
      return const [];
    }
  }

  Future<void> _sections() async {
    final r = await _fetch('/get_adminAcademicSection');
    if (!mounted) return;
    setState(() {
      sections = [for (final x in r) Opt(s(x['id']), s(x['short_name']).isEmpty ? s(x['title']) : s(x['short_name']))];
      loadingSec = false;
    });
  }

  void _notify() => widget.onChanged(sel);

  Future<void> _pickSection(String? id) async {
    sel
      ..sectionId = id
      ..sectionName = sections.where((o) => o.id == id).firstOrNull?.label
      ..standardId = null
      ..divisionId = null
      ..subjectId = null;
    setState(() {
      standards = [];
      divisions = [];
      subjects = [];
      loadingStd = true;
    });
    _notify();
    final r = await _fetch('/get_adminStandard', {'grade_id': id});
    if (!mounted) return;
    setState(() {
      standards = [for (final x in r) Opt(s(x['id']), s(x['name']))];
      loadingStd = false;
    });
  }

  Future<void> _pickStandard(String? id) async {
    sel
      ..standardId = id
      ..standardName = standards.where((o) => o.id == id).firstOrNull?.label
      ..divisionId = null
      ..subjectId = null;
    setState(() {
      divisions = [];
      subjects = [];
      loadingDiv = widget.withDivision;
      loadingSub = widget.withSubject;
    });
    _notify();
    final futures = <Future>[];
    if (widget.withDivision) {
      futures.add(_fetch('/get_adminDivision', {'standard_id': id}).then((r) {
        if (mounted) {
          setState(() {
            divisions = [for (final x in r) Opt(s(x['id']), s(x['name']))];
            loadingDiv = false;
          });
        }
      }));
    }
    if (widget.withSubject) {
      futures.add(_fetch('/get_adminSubject', {'standard_id': id}).then((r) {
        if (mounted) {
          setState(() {
            subjects = [for (final x in r) Opt(s(x['subject_id']), s(x['subject_name']))];
            loadingSub = false;
          });
        }
      }));
    }
    await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        DropdownField(label: 'Section', options: sections, value: sel.sectionId, loading: loadingSec, onChanged: _pickSection),
        const SizedBox(height: 12),
        DropdownField(label: 'Standard', options: standards, value: sel.standardId, loading: loadingStd, onChanged: _pickStandard),
        if (widget.withDivision) ...[
          const SizedBox(height: 12),
          DropdownField(
            label: 'Division',
            options: divisions,
            value: sel.divisionId,
            loading: loadingDiv,
            onChanged: (id) {
              sel
                ..divisionId = id
                ..divisionName = divisions.where((o) => o.id == id).firstOrNull?.label;
              setState(() {});
              _notify();
            },
          ),
        ],
        if (widget.withSubject) ...[
          const SizedBox(height: 12),
          DropdownField(
            label: 'Subject',
            options: subjects,
            value: sel.subjectId,
            loading: loadingSub,
            onChanged: (id) {
              sel
                ..subjectId = id
                ..subjectName = subjects.where((o) => o.id == id).firstOrNull?.label;
              setState(() {});
              _notify();
            },
          ),
        ],
      ]);
}

bool fileExists(String? path) => path != null && File(path).existsSync();
