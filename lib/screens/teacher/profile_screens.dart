import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'tk.dart';

Widget _infoTile(IconData icon, String label, String value) => value.isEmpty
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: KitCard(
          child: Row(children: [
            IconBubble(icon: icon, accent: Brand.accent(label.length)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              ]),
            ),
          ]),
        ),
      );

class OwnProfileScreen extends StatelessWidget {
  const OwnProfileScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) {
    final se = args.session;
    final raw = se.raw;
    final name = [s(raw['first_name']), s(raw['last_name'])].where((e) => e.isNotEmpty).join(' ');
    return KitPage(
      title: args.title.isEmpty ? 'My profile' : args.title,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: PersonAvatar(url: s(raw['image']).isNotEmpty ? s(raw['image']) : (se.imageUrl ?? ''), name: se.name, radius: 46)),
        gap(10),
        Center(child: Text(name.isEmpty ? se.name : name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
        Center(child: Text(se.userProfileName, style: const TextStyle(color: Brand.muted))),
        gap(18),
        _infoTile(Icons.cake_outlined, 'Birthdate', s(raw['birthdate'])),
        _infoTile(Icons.phone_outlined, 'Contact details', s(raw['mobile'])),
        _infoTile(Icons.mail_outline_rounded, 'Email', s(raw['email']).isEmpty ? se.email : s(raw['email'])),
        _infoTile(Icons.event_outlined, 'Joining year', s(raw['join_year'])),
        _infoTile(Icons.home_outlined, 'Address', s(raw['address'])),
      ]),
    );
  }
}

class StudentProfileListScreen extends StatefulWidget {
  const StudentProfileListScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<StudentProfileListScreen> createState() => _StudentProfileListScreenState();
}

class _StudentProfileListScreenState extends State<StudentProfileListScreen> {
  ClassSel sel = ClassSel();
  List<Map<String, dynamic>>? students;
  bool loading = false;
  String? error;

  Future<void> _search() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await loadStudents(widget.args.api, sel);
      if (mounted) setState(() => students = r);
    } catch (e) {
      if (mounted) {
        setState(() {
          students = null;
          error = '$e';
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    return KitPage(
      title: a.title.isEmpty ? 'Student profile' : a.title,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        FormCard(children: [
          ClassPicker(api: a.api, admin: isAdmin(a), onChanged: (c) => setState(() => sel = c)),
          PrimaryButton(label: 'Search', busy: loading, onPressed: sel.divId == null ? null : _search),
        ]),
        gap(),
        if (error != null) KitMessage(icon: Icons.search_off_rounded, text: error!, action: 'Try again', onAction: _search),
        if (students != null && students!.isEmpty) const KitMessage(icon: Icons.groups_outlined, text: 'No students found in this class.'),
        for (final st in students ?? const <Map<String, dynamic>>[]) ...[
          StudentTile(st: st, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentProfileDetail(st: st)))),
          gap(8),
        ],
      ]),
    );
  }
}

class StudentProfileDetail extends StatelessWidget {
  const StudentProfileDetail({super.key, required this.st});
  final Map<String, dynamic> st;

  @override
  Widget build(BuildContext context) => KitPage(
        title: 'Student profile',
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Center(child: PersonAvatar(url: s(st['student_image']), name: s(st['student_name']), radius: 46)),
          gap(10),
          Center(child: Text(s(st['student_name']), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
          Center(
            child: Text('Roll No. ${s(st['roll_no'])}  |  ${s(st['standard_name'])} - ${s(st['division_name'])}', style: const TextStyle(color: Brand.muted)),
          ),
          gap(18),
          _infoTile(Icons.badge_outlined, 'GR number', s(st['enrollment_no'])),
          _infoTile(Icons.cake_outlined, 'Birthdate', s(st['dob'])),
          _infoTile(Icons.phone_outlined, 'Contact details', s(st['mobile'])),
          _infoTile(Icons.mail_outline_rounded, 'Email', s(st['email'])),
          _infoTile(Icons.home_outlined, 'Address', s(st['address'])),
        ]),
      );
}
