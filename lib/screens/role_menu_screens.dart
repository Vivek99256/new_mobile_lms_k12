import 'package:flutter/material.dart';

import '../presentation/admin/fees_breakoff/fees_breakoff_screen.dart';
import '../presentation/admin/fees_master/fees_master_specs.dart';
import '../presentation/admin/fees_structure_report/fees_structure_report_screen.dart';
import '../presentation/admin/student_breakoff_report/student_breakoff_report_screen.dart';
import '../presentation/admin/document_standard_mapping/document_standard_mapping_screen.dart';
import '../presentation/admin/student_certificate/student_certificate_screen.dart';
import '../presentation/admin/student_documents/student_documents_screen.dart';
import '../presentation/admin/add_cast/add_cast_screen.dart';
import '../presentation/admin/add_house/add_house_screen.dart';
import '../presentation/admin/add_student/add_student_screen.dart';
import '../presentation/admin/bulk_student_update/bulk_student_update_screen.dart';
import '../presentation/admin/map_optional_subjects/map_optional_subjects_screen.dart';
import '../presentation/admin/student_request/student_request_screen.dart';
import '../presentation/admin/student_shuffling/student_shuffling_screen.dart';
import '../presentation/admin/subject_elective/subject_elective_screen.dart';
import '../presentation/admin/student_care/student_health_screen.dart';
import '../presentation/admin/student_care/student_hw_screen.dart';
import '../presentation/admin/student_care/student_vaccination_screen.dart';
import '../presentation/admin/student_icard/student_icard_screen.dart';
import '../presentation/admin/student_infirmary/student_infirmary_screen.dart';
import '../presentation/admin/student_search/student_search_screen.dart';
import '../presentation/admin/update_fees_breakoff/update_fees_breakoff_screen.dart';
import 'admin/records_report.dart';
import 'screen_registry.dart';
import 'admin/admission_list.dart';
import 'admin/capture_attendance.dart';
import 'admin/capture_photos.dart';
import 'admin/circular.dart';
import 'admin/discipline.dart';
import '../presentation/admin/fees_cancel_refund/fees_cancel_refund_screen.dart';
import '../presentation/admin/fees_circular/fees_circular_screen.dart';
import '../presentation/admin/fees_collect/fees_collect_screen.dart';
import '../presentation/admin/online_fees_collect/online_fees_collect_screen.dart';
import 'admin/fees_defaulters.dart';
import 'admin/homework.dart';
import 'admin/inward_outward.dart';
import 'admin/leave_requests.dart';
import 'admin/send_message.dart';
import 'admin/student_reports_a.dart';
import 'admin/student_reports_b.dart';
import 'admin/student_reports_c.dart';

/// Native screens for menus granted through web Roles & Access -> Mobile.
///
/// Those menus arrive as `role_menu` with the web page's link (see FeedRepository.mergeRoleMenu,
/// which puts the link in `FeedItem.screenName`). The link is the key here, and it applies to
/// EVERY role: a screen ported once opens for whichever role the admin ticked it for.
/// Adding a screen is one line in [roleMenuScreens].
String normalizeMenuLink(String link) {
  var l = link.trim().toLowerCase();
  while (l.startsWith('/')) {
    l = l.substring(1);
  }
  while (l.endsWith('/')) {
    l = l.substring(0, l.length - 1);
  }
  return l;
}

ScreenBuilder _stage(AdmissionStage st, {bool readOnly = false}) =>
    (a) => AdmissionListScreen(args: a, stage: st, readOnly: readOnly);

Widget _complaints(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/api/complaints',
  rowsKey: 'data.complaints',
  titleKeys: const ['TITLE'],
  subtitleKeys: const ['DESCRIPTION'],
  dateKey: 'DATE',
  icon: Icons.report_problem_outlined,
  emptyText: 'No complaints yet.',
  fields: const [
    RecField('Raised by', ['COMPLAINT_BY_NAME']),
    RecField('Solution', ['COMPLAINT_SOLUTION']),
    RecField('Solved by', ['COMPLAINT_SOLUTION_BY_NAME']),
  ],
);

Widget _frontDesk(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/api/front-desk/report',
  rowsKey: 'data.entries',
  titleKeys: const ['student_name', 'TITLE'],
  subtitleKeys: const ['TITLE', 'DESCRIPTION'],
  dateKey: 'DATE',
  badgeKeys: const ['VISITOR_TYPE'],
  icon: Icons.badge_outlined,
  emptyText: 'No visitors logged yet.',
  fields: const [
    RecField('To meet', ['user_name']),
    RecField('In time', ['IN_TIME']),
    RecField('Out time', ['OUT_TIME']),
  ],
);

Widget _pettyCash(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/api/petty-cash',
  rowsKey: 'data.entries',
  titleKeys: const ['title_name'],
  subtitleKeys: const ['description'],
  dateKey: 'bill_date',
  amountKey: 'amount',
  icon: Icons.payments_outlined,
  emptyText: 'No petty cash entries yet.',
  fields: const [
    RecField('Entered by', ['user_name']),
  ],
);

Widget _consents(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/api/consents',
  rowsKey: 'data.consents',
  titleKeys: const ['FULL_NAME'],
  subtitleKeys: const ['title'],
  dateKey: 'consent_date',
  badgeKeys: const ['account_status'],
  amountKey: 'amount',
  icon: Icons.fact_check_outlined,
  emptyText: 'No consents recorded yet.',
  fields: const [
    RecField('Class', ['STANDARD']),
    RecField('Enrollment', ['enrollment_no']),
    RecField('Mobile', ['SMS_NO']),
    RecField('Created by', ['created_by']),
  ],
);

Widget _transport(
  ScreenArgs a,
  String module,
  IconData icon,
  List<String> title, {
  List<String> sub = const [],
  List<String> badge = const [],
  List<RecField> fields = const [],
  String empty = 'Nothing here yet.',
}) => RecordsReportScreen(
  args: a,
  endpoint: '/api/transportation-setup/$module',
  rowsKey: 'data.records',
  titleKeys: title,
  subtitleKeys: sub,
  badgeKeys: badge,
  icon: icon,
  fields: fields,
  emptyText: empty,
);

Widget _drivers(ScreenArgs a) => _transport(
  a,
  'drivers',
  Icons.badge_outlined,
  ['first_name'],
  sub: ['mobile'],
  badge: ['type', 'status'],
  empty: 'No drivers or conductors yet.',
);

Widget _vehicles(ScreenArgs a) => _transport(
  a,
  'vehicles',
  Icons.directions_bus_outlined,
  ['title'],
  sub: ['vehicle_number'],
  badge: ['vehicle_type'],
  empty: 'No vehicles yet.',
  fields: const [
    RecField('Seats', ['sitting_capacity']),
    RecField('Shift', ['shift_title']),
    RecField('Driver', ['driver_name']),
    RecField('Conductor', ['conductor_name']),
  ],
);

Widget _routes(ScreenArgs a) => _transport(
  a,
  'routes',
  Icons.route_outlined,
  ['route_name'],
  empty: 'No routes yet.',
  fields: const [
    RecField('From', ['from_time']),
    RecField('To', ['to_time']),
  ],
);

Widget _stops(ScreenArgs a) => _transport(a, 'stops', Icons.place_outlined, [
  'stop_name',
], empty: 'No stops yet.');

Widget _shifts(ScreenArgs a) => _transport(
  a,
  'shifts',
  Icons.schedule_outlined,
  ['shift_title'],
  empty: 'No shifts yet.',
  fields: const [
    RecField('Shift rate', ['shift_rate']),
    RecField('Per km', ['km_amount']),
  ],
);

Widget _inventory(
  ScreenArgs a,
  String module,
  IconData icon,
  List<String> title, {
  List<String> sub = const [],
  List<String> badge = const [],
  List<RecField> fields = const [],
  String empty = 'Nothing here yet.',
}) => RecordsReportScreen(
  args: a,
  endpoint: '/api/inventory/$module',
  rowsKey: 'data.records',
  titleKeys: title,
  subtitleKeys: sub,
  badgeKeys: badge,
  icon: icon,
  fields: fields,
  emptyText: empty,
);

Widget _invCategories(ScreenArgs a) => _inventory(
  a,
  'item-categories',
  Icons.category_outlined,
  ['title'],
  sub: ['description'],
  badge: ['status'],
  empty: 'No item categories yet.',
);

Widget _invSubCategories(ScreenArgs a) => _inventory(
  a,
  'item-sub-categories',
  Icons.account_tree_outlined,
  ['title'],
  sub: ['category_name'],
  badge: ['status'],
  empty: 'No sub categories yet.',
  fields: const [
    RecField('Description', ['description']),
  ],
);

Widget _invItems(ScreenArgs a) => _inventory(
  a,
  'items',
  Icons.inventory_2_outlined,
  ['title'],
  sub: ['category_name'],
  badge: ['item_type_name', 'item_status'],
  empty: 'No items yet.',
  fields: const [
    RecField('Sub category', ['sub_category_name']),
    RecField('Opening stock', ['opening_stock']),
    RecField('Minimum stock', ['minimum_stock']),
    RecField('Direct purchase', ['direct_purchase_stock']),
  ],
);

Widget _invVendors(ScreenArgs a) => _inventory(
  a,
  'vendors',
  Icons.storefront_outlined,
  ['vendor_name', 'company_name'],
  sub: ['contact_number'],
  badge: ['business_type'],
  empty: 'No vendors yet.',
  fields: const [
    RecField('Email', ['email']),
    RecField('Address', ['address', 'office_address']),
    RecField('PAN', ['pan_no']),
    RecField('Bank', ['bank_name']),
  ],
);

Widget _invTaxes(ScreenArgs a) => _inventory(
  a,
  'taxes',
  Icons.percent_outlined,
  ['title'],
  sub: ['description_1'],
  badge: ['status'],
  empty: 'No taxes yet.',
  fields: const [
    RecField('Percentage', ['amount_percentage']),
  ],
);

Widget _leaveTypes(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/api/leave/leave-types',
  rowsKey: 'data',
  titleKeys: const ['leave_type'],
  subtitleKeys: const ['leave_type_id'],
  icon: Icons.event_available_outlined,
  emptyText: 'No leave types yet.',
  fields: const [
    RecField('Yearly quota', ['annual_quota']),
    RecField('Carry forward', ['carry_forward'], yesNo: true),
  ],
);

Widget _holidays(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/api/leave/holidays',
  rowsKey: 'data',
  titleKeys: const ['holiday_name'],
  subtitleKeys: const ['description'],
  dateKey: 'from_date',
  badgeKeys: const ['day'],
  icon: Icons.celebration_outlined,
  emptyText: 'No holidays yet.',
  fields: [
    const RecField('Until', ['to_date'], date: true),
    const RecField('Day type', ['day_type']),
  ],
);

Widget _leaveRequests(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/api/leave/requests',
  rowsKey: 'data',
  titleKeys: const ['employee_name'],
  subtitleKeys: const ['leave_type'],
  dateKey: 'from_date',
  badgeKeys: const ['status'],
  icon: Icons.beach_access_outlined,
  emptyText: 'No leave requests yet.',
  fields: const [
    RecField('Department', ['department']),
    RecField('Duration', ['duration']),
    RecField('Until', ['to_date'], date: true),
    RecField('Reason', ['reason']),
  ],
);

// Fees (Master) lists. Adding or editing a master stays on the web for now.
Widget _feesLateMaster(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/fees/fees_late_master',
  master: feesLateMasterSpec,
  rowsKey: 'data',
  titleKeys: const ['standard'],
  subtitleKeys: const ['fine_type'],
  dateKey: 'late_date',
  badgeKeys: const ['status'],
  icon: Icons.timer_outlined,
  emptyText: 'No late-fee rules yet.',
  fields: const [
    RecField('Month', ['month_id']),
    RecField('Created by', ['user']),
  ],
);

Widget _feesConfigMaster(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/fees/fees_config_master',
  master: feesConfigMasterSpec,
  rowsKey: 'data',
  titleKeys: const ['institute_name'],
  subtitleKeys: const ['account_to_be_credited'],
  icon: Icons.settings_suggest_outlined,
  emptyText: 'Fees config is not set up yet.',
  fields: const [
    RecField('PAN', ['pan_no']),
    RecField('Late fee', ['late_fees_amount']),
    RecField('Send SMS', ['send_sms'], yesNo: true),
    RecField('Send email', ['send_email'], yesNo: true),
    RecField('CMS code', ['cms_client_code']),
    RecField('Auto head counting', ['auto_head_counting'], yesNo: true),
  ],
);

Widget _feesReceiptBookMaster(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/fees/fees_receipt_book_master',
  master: feesReceiptBookMasterSpec,
  dedupeKey: 'receipt_id',
  rowsKey: 'data',
  titleKeys: const ['receipt_line_1'],
  subtitleKeys: const ['receipt_line_2'],
  badgeKeys: const ['status'],
  icon: Icons.menu_book_outlined,
  emptyText: 'No receipt books yet.',
  fields: const [
    RecField('Prefix', ['receipt_prefix']),
    RecField('Postfix', ['receipt_postfix']),
    RecField('Last receipt no', ['last_receipt_number']),
    RecField('Account no', ['account_number']),
    RecField('Branch', ['branch']),
    RecField('PAN', ['pan']),
  ],
);

Widget _feesCircularMaster(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/fees/fees_circular_master',
  master: feesCircularMasterSpec,
  rowsKey: 'data',
  titleKeys: const ['bank_name'],
  subtitleKeys: const ['branch'],
  icon: Icons.account_balance_outlined,
  emptyText: 'No circular master yet.',
  fields: const [
    RecField('Account no', ['account_no']),
    RecField('Address', ['address_line1']),
    RecField('', ['address_line2']),
    RecField('Form no', ['form_no']),
    RecField('Shift', ['shift']),
    RecField('Paid collection', ['paid_collection']),
  ],
);

Widget _feesTitle(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/fees/fees_title',
  master: feesTitleSpec,
  rowsKey: 'data',
  titleKeys: const ['fees_title'],
  subtitleKeys: const ['display_name'],
  badgeKeys: const ['mandatory'],
  icon: Icons.label_outline,
  emptyText: 'No fee titles yet.',
  fields: const [
    RecField('Sort order', ['sort_order']),
    RecField('Cumulative name', ['cumulative_name']),
  ],
);

Widget _otherFeesTitle(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/fees/other_fees_title',
  master: otherFeesTitleSpec,
  auto: true,
  icon: Icons.label_important_outline,
  emptyText: 'No other fee titles yet.',
);

Widget _feesBreakoff(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/fees/fees_breackoff',
  addLabel: 'Add fee structure',
  addScreen: () => FeesBreakoffAddScreen(args: a),
  auto: true,
  icon: Icons.call_split_outlined,
  emptyText: 'No fee breakoff yet.',
);

Widget _additionalFeesMapping(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/fees/other_fee_map',
  rowsKey: 'data.data.heads',
  titleKeys: const ['display_name', 'fees_title'],
  subtitleKeys: const ['fees_title'],
  badgeKeys: const ['mandatory'],
  icon: Icons.link_outlined,
  emptyText: 'No fee heads to map yet.',
);

// Fees reports: the same legacy endpoints the web proxies to (type=API), with a date range and class filter.
Widget _otherFeesReport(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/fees/otherNew_fees_report/create',
  rowsKey: 'other_feesData',
  dateRange: true,
  classFilter: true,
  titleKeys: const ['student_name'],
  subtitleKeys: const ['fees_head'],
  dateKey: 'deduction_date',
  badgeKeys: const ['payment_mode'],
  amountKey: 'deduction_amount',
  icon: Icons.receipt_outlined,
  emptyText: 'No other fees collected in this period.',
  fields: const [
    RecField('Class', ['standard_name']),
    RecField('Division', ['division_name']),
    RecField('GR no', ['enrollment_no']),
    RecField('Receipt', ['receipt_id']),
    RecField('Bank', ['bank_name']),
    RecField('Remarks', ['deduction_remarks']),
  ],
);

Widget _otherFeesCancelReport(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/fees/otherNew_cancel_fees_report/create',
  rowsKey: 'other_feesData',
  dateRange: true,
  classFilter: true,
  titleKeys: const ['student_name'],
  subtitleKeys: const ['fees_head'],
  dateKey: 'cancellation_date',
  amountKey: 'cancellation_amount',
  icon: Icons.cancel_presentation_outlined,
  emptyText: 'No other fees cancelled in this period.',
  fields: const [
    RecField('Class', ['standard_name']),
    RecField('Division', ['division_name']),
    RecField('GR no', ['enrollment_no']),
    RecField('Receipt', ['receipt_id']),
    RecField('Cancelled by', ['cancelled_by']),
    RecField('Remarks', ['cancellation_remarks']),
  ],
);

Widget _feesTypeWise(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/fees/fees_type_wise_report/create',
  rowsKey: 'fees_data',
  dateRange: true,
  classFilter: true,
  titleKeys: const ['student_name'],
  subtitleKeys: const ['section'],
  dateKey: 'receiptdate',
  badgeKeys: const ['payment_mode'],
  amountKey: 'amount',
  labelMapKey: 'fees_heads',
  headPrefix: 'total_',
  icon: Icons.category_outlined,
  emptyText: 'No fees collected in this period.',
  fields: const [
    RecField('GR no', ['enrollment_no']),
    RecField('Receipt', ['receipt_no']),
    RecField('Mobile', ['mobile']),
    RecField('Discount', ['tot_disc']),
    RecField('Batch', ['student_batch_name']),
  ],
);

Widget _studentBreakoff(ScreenArgs a) => StudentBreakoffReportScreen(args: a);

Widget _feesMonthly(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/fees/getfeesMonthlyReport',
  post: true,
  auto: true,
  labelMapKey: 'heading_arr',
  hideZero: true,
  dateRange: true,
  classFilter: true,
  icon: Icons.calendar_view_month_outlined,
  emptyText: 'No collection in this period.',
);
Widget _feesCollection(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/fees/fees_collection_report/create',
  rowsKey: 'fees_data',
  dateRange: true,
  titleKeys: const ['student_name'],
  subtitleKeys: const ['standard_name'],
  dateKey: 'receiptdate',
  badgeKeys: const ['payment_mode'],
  amountKey: 'actual_amountpaid',
  icon: Icons.receipt_long_outlined,
  emptyText: 'No fees collected in this period.',
  fields: const [
    RecField('Receipt no', ['receipt_no']),
    RecField('Class', ['division_name']),
    RecField('Enrollment', ['enrollment_no']),
    RecField('Collected by', ['user_name']),
    RecField('Remarks', ['remarks']),
  ],
);

Widget _feesCancel(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/fees/fees_cancel_report',
  post: true,
  auto: true,
  dateRange: true,
  icon: Icons.cancel_presentation_outlined,
  emptyText: 'No cancelled receipts in this period.',
);

Widget _feesDatewise(ScreenArgs a) => RecordsReportScreen(
  args: a,
  endpoint: '/fees/fees_report_datewise',
  query: const {'search': '1'},
  auto: true,
  dateRange: true,
  icon: Icons.calendar_month_outlined,
  emptyText: 'No collection in this period.',
);

final Map<String, ScreenBuilder> roleMenuScreens = {
  // Fees / students / communication / registers / leave / attendance: screens already ported
  // for the admin profile, now reachable from the Roles & Access link.
  'fees/collect': (a) => FeesCollectScreen(args: a),
  // Pay Now opens the web flow (mobile number -> select student -> gateway), signed in by a ticket.
  'fees/online_fees_collect': (a) => OnlineFeesCollectScreen(args: a),
  'students/search_student': (a) => StudentSearchScreen(args: a),
  'students/student_documents': (a) => StudentDocumentsScreen(args: a),
  'document_standard_mapping.index': (a) =>
      DocumentStandardMappingScreen(args: a),
  'student/student_certificate': (a) => StudentCertificateScreen(args: a),
  'student/add_student': (a) => AddStudentScreen(args: a),
  'student/bulk_student_update': (a) => BulkStudentUpdateScreen(args: a),
  'student/add_house': (a) => AddHouseScreen(args: a),
  'house_automation.index': (a) => StudentShufflingScreen(args: a),
  'student/student_optional_subject': (a) => MapOptionalSubjectsScreen(args: a),
  'subject_elective.index': (a) => SubjectElectiveScreen(args: a),
  'students/requests': (a) => StudentRequestScreen(args: a),
  'add_cast.index': (a) => AddCastScreen(args: a),
  'student/student_infirmary': (a) => StudentInfirmaryScreen(args: a),
  'student/student_vaccination': (a) => StudentVaccinationScreen(args: a),
  'student/student_hw': (a) => StudentHeightWeightScreen(args: a),
  'student/student_health': (a) => StudentHealthScreen(args: a),
  'student/student_icard': (a) => StudentIcardScreen(args: a),
  'easy_com/send_sms_parents': (a) =>
      SendMessageScreen(args: a, kind: MessageKind.sms),
  'easy_com/send_notification_parents': (a) =>
      SendMessageScreen(args: a, kind: MessageKind.notification),
  'easy_com/send_email_parents': (a) =>
      SendMessageScreen(args: a, kind: MessageKind.email),
  'inward_outward/add_inward': (a) =>
      RegisterListScreen(args: a, kind: RegisterKind.inward),
  'inward_outward/add_outward': (a) =>
      RegisterListScreen(args: a, kind: RegisterKind.outward),
  'inward_outward/show_inward_report': (a) =>
      RegisterListScreen(args: a, kind: RegisterKind.inward),
  'inward_outward/show_outward_report': (a) =>
      RegisterListScreen(args: a, kind: RegisterKind.outward),
  'leave-authorisation.index': (a) => LeaveRequestsScreen(args: a),
  'circular.index': (a) => AdminCircularScreen(args: a),
  'lms/homework': (a) => AdminHomeworkScreen(args: a),
  'student/report/student_discipline_report': (a) => DisciplineScreen(args: a),
  'student_face_attendance.index': (a) => CapturePhotosScreen(args: a),
  'class_face_attendance.index': (a) =>
      CaptureAttendanceScreen(args: a, isAdmin: true),
  // Fees (Master): the school's fee setup, read from the same legacy endpoints the web uses (type=API).
  'fees/master/fees-late-master': _feesLateMaster,
  'fees/master/fees-config-master': _feesConfigMaster,
  'fees/master/fees-receipt-book-master': _feesReceiptBookMaster,
  'fees/master/fees-circular-master': _feesCircularMaster,
  'fees/master/new-fees-title-master': _feesTitle,
  'fees/master/other-fees-title': _otherFeesTitle,
  'fees/master/fees-breakoff': _feesBreakoff,
  'fees/update-fees-breakoff': (a) => UpdateFeesBreakoffScreen(args: a),
  'fees/master/additional-fees-mapping': _additionalFeesMapping,
  'fees/cancel-refund': (a) => FeesCancelRefundScreen(args: a),
  'fees/circulars': (a) => FeesCircularScreen(args: a),
  'fees/reports/fees-defaulter': (a) => FeesDefaultersScreen(args: a),
  'fees/reports/fees-structure': (a) => FeesStructureReportScreen(args: a),
  'fees/reports/other-fees': _otherFeesReport,
  'fees/reports/other-fees-cancel': _otherFeesCancelReport,
  'fees/reports/fees-type-wise': _feesTypeWise,
  'fees/reports/student-breakoff': _studentBreakoff,
  'fees_monthly_report.index': _feesMonthly,
  'fees/reports/fees-collection': _feesCollection,
  'fees/reports/fees-cancel': _feesCancel,
  'fees/reports/datewise-summary': _feesDatewise,
  // Admin services (read-only for now; adding/editing stays on the web)
  'admin-services/complaint-report': _complaints,
  'admin-services/complaint-management': _complaints,
  'admin-services/front-desk': _frontDesk,
  'admin-services/front-desk-report': _frontDesk,
  'admin-services/visitor-report': _frontDesk,
  'admin-services/petty-cash': _pettyCash,
  'admin-services/petty-cash-report': _pettyCash,
  'admin-services/consent-report': _consents,
  // Transportation (read-only lists)
  'transportation/add_driver_conductor': _drivers,
  'transportation/add_vehicle': _vehicles,
  'transportation/add_route': _routes,
  'transportation/add_stop': _stops,
  'transport_shift.index': _shifts,
  // Inventory masters (read-only lists)
  'inventory/item_category_master': _invCategories,
  'inventory/item_sub_category_master': _invSubCategories,
  'inventory/inventory_item_master': _invItems,
  'inventory/vendor_master': _invVendors,
  'inventory/tax_master': _invTaxes,
  // HR leave (read-only lists)
  'leave-type.index': _leaveTypes,
  'holiday.index': _holidays,
  'hrit.leave.requests': _leaveRequests,
  'leave.report': _leaveRequests,
  // Admission
  'admissions/admission_enquiry': _stage(AdmissionStage.enquiry),
  'admissions/admission_registration': _stage(AdmissionStage.registration),
  'admissions/admission_confirmation': _stage(AdmissionStage.confirmation),
  // Admission reports: the same data, read-only.
  'admissions/admission_reports/admission-inquiry': _stage(
    AdmissionStage.enquiry,
    readOnly: true,
  ),
  'admissions/admission_reports/admission-registration': _stage(
    AdmissionStage.registration,
    readOnly: true,
  ),
  'admissions/admission_reports/admission-confirmation': _stage(
    AdmissionStage.confirmation,
    readOnly: true,
  ),
  'admissions/admission_reports/admission-without-confirmation': (a) =>
      AdmissionListScreen(
        args: a,
        stage: AdmissionStage.enquiry,
        readOnly: true,
        withoutConfirmation: true,
      ),
  ...studentReportsA,
  ...studentReportsB,
  ...studentReportsC,
};

ScreenBuilder? lookupRoleMenuScreen(String link) =>
    roleMenuScreens[normalizeMenuLink(link)];

/// Menus that make no sense as a native page, so the app never lists them: payment-gateway hand-offs,
/// gateway settings and spreadsheet import/export. They stay on the web.
const _webOnly = {
  'online_fees.index',
  'fees/nach_s1excel_export',
  'fees/nach_s2excel_import',
  'fees/nach_s3excel_export',
  'fees/nach_s4excel_import',
};

bool isWebOnlyMenu(String link) => _webOnly.contains(normalizeMenuLink(link));
