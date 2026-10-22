import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../kit/kit.dart';

/// Shared plumbing for the staff screens that moved from legacy mobile endpoints to the newer
/// `/api/*` (or web-proven) endpoints. See docs/api-migration-staff.md.
///
/// Two rules drive everything here:
///  * READS try the new endpoint first and fall back ONCE to the legacy call on any failure.
///  * WRITES fall back to legacy only when the server definitely refused before processing
///    (HTTP 401/403/404/405/419 or a body that says so). A 422/500 shows the server message.
///
/// [LegacyApi] hides the HTTP status for JSON bodies, so a "definite refusal" is recognised from
/// the body: no `errors` payload (a validation failure always carries one) and a message that
/// names an authentication / permission / routing problem. Non-JSON bodies (the HTML 419 page)
/// arrive as an [ApiException] with the status code attached.

/// HTTP statuses that mean "refused before the request was processed".
const _refusalStatuses = {401, 403, 404, 405, 419};

final _refusalText = RegExp(
  r'unauthori[sz]ed|unauthenticated|forbidden|permission|not found|could not be found|csrf|page expired|not allowed|not supported|denied|token|rights',
  caseSensitive: false,
);

bool refusedByStatus(int? code) => code != null && _refusalStatuses.contains(code);

bool hasErrors(Map<String, dynamic> res) {
  final e = res['errors'];
  return (e is Map && e.isNotEmpty) || (e is List && e.isNotEmpty);
}

/// True when [res] is a failure body that says the request was refused outright.
bool refusedByBody(Map<String, dynamic> res) =>
    !LegacyApi.ok(res) && !hasErrors(res) && _refusalText.hasMatch('${res['message'] ?? ''}');

/// The first human readable validation message inside `errors` (`{field: [msg]}`), if any.
String? firstErrorText(Map<String, dynamic> res) {
  final e = res['errors'];
  if (e is Map) {
    for (final v in e.values) {
      if (v is List && v.isNotEmpty && v.first is String) return v.first as String;
      if (v is String && v.isNotEmpty) return v;
    }
  }
  return null;
}

/// A response with a uniform `status` ('1' / '0') and a useful `message`, so existing screens
/// (which test `status`/`status_code`) work unchanged with `{success: true}` style bodies.
Map<String, dynamic> normalized(Map<String, dynamic> res) {
  final good = LegacyApi.ok(res);
  var message = '${res['message'] ?? ''}'.trim();
  if (!good && (message.isEmpty || message == 'Validation failed.' || message == 'Invalid record details.')) {
    message = firstErrorText(res) ?? (message.isEmpty ? 'Something went wrong.' : message);
  }
  return {...res, 'status': good ? '1' : '0', 'message': message};
}

void logFallback(String screen, Object reason) => debugPrint('api-migration: $screen fell back to legacy: $reason');

/// READ: try [fresh]; on ANY failure (HTTP error, refusal, unparsable) call [legacy] once.
Future<T> readNewThenLegacy<T>(String screen, Future<T> Function() fresh, Future<T> Function() legacy) async {
  try {
    return await fresh();
  } catch (e) {
    logFallback(screen, e);
    return legacy();
  }
}

/// WRITE: call [fresh]. Fall back to [legacy] only for a definite pre-processing refusal;
/// otherwise return the (normalised) response so the caller shows the server message.
/// Network/timeouts and 5xx errors propagate as [ApiException] - the request may have been
/// accepted, so it is never replayed on the legacy endpoint.
Future<Map<String, dynamic>> writeNewThenLegacy(
  String screen,
  Future<Map<String, dynamic>> Function() fresh,
  Future<Map<String, dynamic>> Function() legacy,
) async {
  final Map<String, dynamic> res;
  try {
    res = await fresh();
  } on ApiException catch (e) {
    if (refusedByStatus(e.statusCode)) {
      logFallback(screen, 'HTTP ${e.statusCode}: ${e.message}');
      return legacy();
    }
    rethrow;
  }
  if (refusedByBody(res)) {
    logFallback(screen, LegacyApi.messageOf(res));
    return legacy();
  }
  return normalized(res);
}

/// GET [url] and require success, throwing so [readNewThenLegacy] can fall back.
Future<Map<String, dynamic>> getNew(LegacyApi api, String url, {Map<String, dynamic> query = const {}}) async {
  final res = await api.get(url, query: query);
  if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res, 'Request refused.'));
  return res;
}

// ---------------------------------------------------------------------------------------
// Parent messages (rows 22-26): api/easy_com/send-*
// ---------------------------------------------------------------------------------------

enum ParentSend { sms, notification, email }

/// Sends an SMS / notification / email to parents through `api/easy_com/send-*`.
///
/// [chosen] are the student rows the user ticked (`mobile`, `email` keys). The new endpoints are
/// keyed by the parent's mobile number and need the academic section (`grade`), standard and
/// division. When any of those is missing, or a notification recipient has no mobile number
/// (the new endpoint addresses parents by mobile), the legacy call is used directly.
Future<Map<String, dynamic>> sendParentMessage({
  required LegacyApi api,
  required String screen,
  required ParentSend kind,
  required String? grade,
  required String? standard,
  required String? division,
  required String text,
  String subject = '',
  required List<Map<String, dynamic>> chosen,
  required Future<Map<String, dynamic>> Function() legacy,
}) {
  final cls = {
    'grade': grade ?? '',
    'standard': standard ?? '',
    'division': division ?? '',
  };
  if (cls.values.any((v) => v.isEmpty)) {
    logFallback(screen, 'class selection has no section/standard/division id');
    return legacy();
  }
  final mobiles = <String>{
    for (final st in chosen)
      if (s(st['mobile']).isNotEmpty) s(st['mobile']),
  };
  final emails = <String>{
    for (final st in chosen)
      if (s(st['email']).isNotEmpty) s(st['email']),
  };

  late final String url;
  late final Map<String, dynamic> body;
  switch (kind) {
    case ParentSend.sms:
      url = '/api/easy_com/send-sms-parents';
      body = {...cls, 'smsText': text, for (final m in mobiles) 'sendsms[$m]': 'on'};
    case ParentSend.notification:
      if (chosen.any((st) => s(st['mobile']).isEmpty)) {
        logFallback(screen, 'a selected student has no mobile number');
        return legacy();
      }
      url = '/api/easy_com/send-notification-parents';
      body = {...cls, 'notificationText': text, for (final m in mobiles) 'sendNotification[$m]': 'on'};
    case ParentSend.email:
      url = '/api/easy_com/send-email-parents';
      body = {...cls, 'subject': subject, 'content': text, 'all_email': emails.join(',')};
  }
  return writeNewThenLegacy(screen, () => api.post(url, body: body), legacy);
}

// ---------------------------------------------------------------------------------------
// Notification report (row 67)
// ---------------------------------------------------------------------------------------

/// `api/easy_com/reports/notification` rows -> the keys the report card already reads.
List<Map<String, dynamic>> adaptNotificationRows(List<Map<String, dynamic>> list) => [
      for (final r in list)
        {
          ...r,
          'stu_name': r['student_name'],
          'std_name': r['standard_name'],
          'div_name': r['division_name'],
          'aca_sec': r['grade_name'],
          'NOTIFICATION_TYPE': r['notification_type'],
          'NOTIFICATION_DESCRIPTION': r['notification_text'],
          'NOTOFICATION_DATE': r['notification_date'],
        }
    ];

// ---------------------------------------------------------------------------------------
// My leave balance (row 40)
// ---------------------------------------------------------------------------------------

/// `GET api/hrms/leaves` data -> the `leave_summary` / `leave_types` shape `MyLeaveScreen` reads.
Map<String, dynamic> adaptLeaveBalance(Map<String, dynamic> data) {
  final sum = data['summary'] is Map ? Map<String, dynamic>.from(data['summary'] as Map) : <String, dynamic>{};
  return {
    'leave_summary': {
      'total_leaves': sum['total'],
      'used_leaves': sum['used'],
      'remaining_leaves': sum['remaining'],
    },
    'leave_types': rows(data['leave_types']),
  };
}

// ---------------------------------------------------------------------------------------
// Leave requests (rows 41, 85)
// ---------------------------------------------------------------------------------------

/// `api/leave/requests` row -> adds the legacy `comment` key (the new API calls it `reason`).
Map<String, dynamic> adaptLeaveRow(Map<String, dynamic> r) => {
      ...r,
      'comment': r['reason'],
      'user_id': r['employee_id'],
    };

/// All pages of `GET api/leave/requests` (200 per page, at most 10 pages), adapted.
Future<List<Map<String, dynamic>>> fetchLeaveRequests(LegacyApi api, Map<String, dynamic> filters) async {
  final out = <Map<String, dynamic>>[];
  var page = 1;
  var last = 1;
  do {
    final res = await getNew(api, '/api/leave/requests', query: {...filters, 'per_page': 200, 'page': page});
    out.addAll(apiRows(res).map(adaptLeaveRow));
    final pg = res['pagination'];
    last = pg is Map ? (int.tryParse('${pg['last_page']}') ?? 1) : 1;
    page++;
  } while (page <= last && page <= 10);
  return out;
}

/// Same as [rows] but for a `data` that may be a map keyed by anything.
List<Map<String, dynamic>> apiRows(Map<String, dynamic> res, [String key = 'data']) {
  final d = res[key];
  if (d is Map) return rows(d.values.toList());
  return rows(d);
}
