import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'admin_common.dart';

/// A generic profile page: avatar header plus label/value tiles.
class ProfileDetailScreen extends StatelessWidget {
  const ProfileDetailScreen({super.key, required this.title, required this.name, required this.image, required this.subtitle, required this.fields});
  final String title;
  final String name;
  final String image;
  final String subtitle;
  final List<(IconData, String, String)> fields;

  @override
  Widget build(BuildContext context) {
    final shown = fields.where((f) => f.$3.isNotEmpty).toList();
    return KitPage(
      title: title,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        KitCard(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            PersonAvatar(url: image, name: name, radius: 44),
            gap(10),
            Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: Brand.muted)),
          ]),
        ),
        gap(),
        if (shown.isEmpty) const KitMessage(icon: Icons.person_outline, text: 'No profile details are available.'),
        for (final f in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: KitCard(
              child: Row(children: [
                IconBubble(icon: f.$1, accent: Brand.accent(0), size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.$2, style: const TextStyle(color: Brand.muted, fontSize: 12)),
                    Text(f.$3, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

String _fullName(Map<String, dynamic> t) {
  final full = s(t['user_full_name']);
  if (full.isNotEmpty) return full;
  return [t['first_name'], t['middle_name'], t['last_name']].map(s).where((e) => e.isNotEmpty).join(' ');
}

/// t_teacher_profile: staff list.
class TeacherProfileListScreen extends StatefulWidget {
  const TeacherProfileListScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<TeacherProfileListScreen> createState() => _TeacherProfileListScreenState();
}

class _TeacherProfileListScreenState extends State<TeacherProfileListScreen> {
  final search = TextEditingController();
  String q = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await widget.args.api.post('/get_adminTeacherList');
    if (!LegacyApi.ok(res) && statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res));
    return rows(res['data']);
  }

  @override
  Widget build(BuildContext context) => KitPage(
        title: widget.args.item.label.isEmpty ? 'Teacher profile' : widget.args.item.label,
        child: AsyncList(
          load: _load,
          emptyText: 'No teachers found.',
          emptyIcon: Icons.badge_outlined,
          header: TextField(
            controller: search,
            decoration: const InputDecoration(labelText: 'Search by name or mobile', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
          ),
          itemBuilder: (c, t, i) {
            final name = _fullName(t);
            final hit = q.isEmpty || name.toLowerCase().contains(q) || s(t['mobile']).contains(q);
            if (!hit) return const SizedBox.shrink();
            return KitCard(
              onTap: () => push(c, TeacherProfileDetailScreen(teacher: t)),
              child: Row(children: [
                PersonAvatar(url: s(t['image']), name: name, radius: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (s(t['user_profile_name']).isNotEmpty) Text(s(t['user_profile_name']), style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                    if (s(t['mobile']).isNotEmpty) Text(s(t['mobile']), style: const TextStyle(color: Brand.primary, fontSize: 12.5)),
                    if (s(t['birthdate']).isNotEmpty) Text('D.O.B: ${fmtDate(t['birthdate'])}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: Brand.muted),
              ]),
            );
          },
        ),
      );
}

class TeacherProfileDetailScreen extends StatelessWidget {
  const TeacherProfileDetailScreen({super.key, required this.teacher});
  final Map<String, dynamic> teacher;

  @override
  Widget build(BuildContext context) => ProfileDetailScreen(
        title: 'Teacher profile',
        name: _fullName(teacher),
        image: s(teacher['image']),
        subtitle: s(teacher['user_profile_name']),
        fields: profileFields(teacher),
      );
}

List<(IconData, String, String)> profileFields(Map<String, dynamic> t) => [
      (Icons.cake_outlined, 'Birthdate', fmtDate(t['birthdate'])),
      (Icons.phone_outlined, 'Contact details', s(t['mobile'])),
      (Icons.mail_outline, 'Email', s(t['email'])),
      (Icons.event_outlined, 'Joining year', s(t['join_year'])),
      (Icons.home_outlined, 'Address', s(t['address'])),
    ];

/// t_own_profile: the signed-in admin, from the session only (no API).
class OwnProfileScreen extends StatelessWidget {
  const OwnProfileScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) {
    final raw = args.session.raw;
    final merged = {...raw, 'email': s(raw['email']).isEmpty ? args.session.email : raw['email']};
    return ProfileDetailScreen(
      title: 'Own profile',
      name: args.session.name,
      image: args.session.imageUrl ?? '',
      subtitle: args.session.userProfileName,
      fields: profileFields(merged),
    );
  }
}

/// t_student_profile: filter, search, open a student.
class StudentProfileListScreen extends StatelessWidget {
  const StudentProfileListScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) => KitPage(
        title: args.item.label.isEmpty ? 'Student profile' : args.item.label,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          StudentPicker(
            api: args.api,
            endpoint: '/allStudentListAPI',
            selectable: false,
            onChanged: (_, _, _) {},
            onOpen: (st, _) => push(context, StudentProfileDetailScreen(student: st)),
          ),
        ]),
      );
}

class StudentProfileDetailScreen extends StatelessWidget {
  const StudentProfileDetailScreen({super.key, required this.student});
  final Map<String, dynamic> student;

  @override
  Widget build(BuildContext context) {
    final st = student;
    final cls = [s(st['standard_name']), s(st['division_name'])].where((e) => e.isNotEmpty).join(' - ');
    return ProfileDetailScreen(
      title: 'Student profile',
      name: s(st['student_name']),
      image: s(st['student_image']),
      subtitle: cls,
      fields: [
        (Icons.tag, 'Roll no.', s(st['roll_no'])),
        (Icons.badge_outlined, 'GR no.', s(st['enrollment_no'])),
        (Icons.class_outlined, 'Standard', cls),
        (Icons.wc_outlined, 'Gender', s(st['gender'])),
        (Icons.cake_outlined, 'Birthdate', fmtDate(st['dob'])),
        (Icons.phone_outlined, 'Mobile', s(st['mobile'])),
        (Icons.mail_outline, 'Email', s(st['email'])),
        (Icons.person_outline, 'Father', s(st['father_name'])),
        (Icons.person_outline, 'Mother', s(st['mother_name'])),
        (Icons.home_outlined, 'Address', s(st['address'])),
      ],
    );
  }
}
