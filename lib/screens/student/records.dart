import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'student_common.dart';

/// Health, hostel, transport and consent screens: label/value cards over one endpoint.

Widget _records(ScreenArgs a, String title, String url, List<(String, String)> Function(Map<String, dynamic>) rowsOf,
        {String empty = 'No records yet.', IconData icon = Icons.inbox_outlined, Widget Function(Map<String, dynamic>)? extra}) =>
    SimpleList(
      args: a,
      title: title,
      url: url,
      emptyText: empty,
      emptyIcon: icon,
      itemBuilder: (c, r, i) => InfoRows(rowsOf(r), trailing: extra?.call(r)),
    );

Widget heightWeightScreen(ScreenArgs a) => _records(
      a,
      'Height and weight',
      '/studentHWAPI',
      (r) => [
        ('Doctor name', s(r['doctor_name'])),
        ('Doctor contact', s(r['doctor_contact'])),
        ('Date', s(r['date'])),
        ('Height', s(r['height'])),
        ('Weight', s(r['weight'])),
      ],
      empty: 'No height or weight records yet.',
      icon: Icons.monitor_weight_outlined,
    );

Widget infirmaryScreen(ScreenArgs a) => _records(
      a,
      'Infirmary',
      '/studentInfirmaryAPI',
      (r) => [
        ('Medical case no', s(r['medical_case_no'])),
        ('Doctor name', s(r['doctor_name'])),
        ('Doctor contact', s(r['doctor_contact'])),
        ('Open date', s(r['date'])),
        ('Complaint', s(r['complaint'])),
        ('Symptoms', s(r['symptoms'])),
        ('Disease', s(r['disease'])),
        ('Treatment', s(r['treatments'])),
        ('Medical case date', s(r['medical_close_date'])),
        ('Health center', s(r['health_center'])),
      ],
      empty: 'No infirmary visits recorded.',
      icon: Icons.medical_services_outlined,
    );

Widget vaccinationScreen(ScreenArgs a) => _records(
      a,
      'Vaccination',
      '/studentVaccinationAPI',
      (r) => [
        ('Doctor name', s(r['doctor_name'])),
        ('Doctor contact', s(r['doctor_contact'])),
        ('Date', s(r['date'])),
        ('Vaccination type', s(r['vaccination_type'])),
        ('Note', s(r['note'])),
      ],
      empty: 'No vaccinations recorded.',
      icon: Icons.vaccines_outlined,
    );

Widget consentScreen(ScreenArgs a) => _records(
      a,
      'Consent',
      '/consentListAPI',
      (r) => [
        ('Title', s(r['title'])),
        ('Consent date', s(r['consent_date'])),
        ('Accountable status', s(r['accountable_status'])),
        ('Consent status', s(r['consent_status'])),
        ('Amount', s(r['amount'])),
      ],
      empty: 'No consent requests.',
      icon: Icons.verified_user_outlined,
    );

Widget transportScreen(ScreenArgs a) => _records(
      a,
      'Transport',
      '/studentTransportAPI',
      (r) => [
        ('From shift', s(r['from_shift'])),
        ('From bus', s(r['from_bus'])),
        ('From stop', s(r['from_stop_name'])),
        ('To shift', s(r['to_shift'])),
        ('To bus', s(r['to_bus'])),
        ('To stop', s(r['to_stop_name'])),
      ],
      empty: 'No transport has been assigned.',
      icon: Icons.directions_bus_outlined,
      extra: (r) => s(r['gps_link']).isEmpty
          ? const SizedBox.shrink()
          : Builder(
              builder: (c) => OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                onPressed: () => openUrl(c, s(r['gps_link'])),
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Track bus'),
              ),
            ),
    );

Widget healthDetailsScreen(ScreenArgs a) => SimpleList(
      args: a,
      title: titleOf(a, 'Health details'),
      url: Sx.url(a, '/studentHealthAPI'),
      emptyText: 'No health records yet.',
      emptyIcon: Icons.health_and_safety_outlined,
      itemBuilder: (c, r, i) {
        final file = s(r['file']);
        return KitCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (file.isNotEmpty && looksLikeImage(file))
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(file, width: 64, height: 64, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(width: 64, height: 64, child: Icon(Icons.image_not_supported_outlined, color: Brand.muted))),
                ),
              ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s(r['doctor_name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text('Date: ${s(r['date'])}', style: const TextStyle(color: Brand.muted, fontSize: 13)),
                Text('Mobile: ${s(r['doctor_contact'])}', style: const TextStyle(color: Brand.muted, fontSize: 13)),
                if (s(r['remarks']).isNotEmpty) Text('Remarks: ${s(r['remarks'])}', style: const TextStyle(fontSize: 13)),
                AttachmentButton(file),
              ]),
            ),
          ]),
        );
      },
    );

/// Hostel allocation is a single record (`data.first`).
Widget hostelScreen(ScreenArgs a) => KitPage(
      title: 'Hostel details',
      child: AsyncBody<Map<String, dynamic>?>(
        emptyText: 'No hostel has been allocated.',
        isEmpty: (d) => d == null || d.isEmpty,
        load: () async {
          final res = await Sx.call(a, '/studentHostelAllocationAPI');
          if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res));
          final d = res['data'];
          final list = d is List ? rows(d) : (d is Map ? [m(d)] : <Map<String, dynamic>>[]);
          return list.isEmpty ? null : list.first;
        },
        builder: (c, r, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            InfoRows([
              ('Hostel', s(r!['hostel_name'])),
              ('Room no', s(r['room_name'])),
              ('Bed no', s(r['bed_no'])),
              ('Locker no', s(r['locker_no'])),
              ('Table no', s(r['table_no'])),
              ('Bedsheet no', s(r['bedsheet_no'])),
              ('Warden', s(r['warden'])),
              ('Warden contact', s(r['warden_contact'])),
            ]),
          ]),
        ),
      ),
    );

/// Achievement certificates (the old screen was unfinished): a list of documents.
Widget achievementCertificateScreen(ScreenArgs a) => SimpleList(
      args: a,
      title: titleOf(a, 'Achievement certificates'),
      url: Sx.url(a, '/document_details'),
      get: true,
      body: const {'document_type': '59'},
      emptyText: 'No achievement certificates yet.',
      emptyIcon: Icons.workspace_premium_outlined,
      itemBuilder: (c, r, i) => KitCard(
        child: Row(children: [
          IconBubble(icon: Icons.workspace_premium_outlined, accent: Brand.accent(i + 2), size: 46),
          const SizedBox(width: 12),
          Expanded(child: Text(s(r['document_title']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          AttachmentButton(s(r['file_name']), label: 'Open'),
        ]),
      ),
    );
