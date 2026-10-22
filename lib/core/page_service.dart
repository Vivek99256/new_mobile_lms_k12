import 'api_client.dart';
import 'session.dart';

/// Authenticated calls the native screens make. Mirrors lms_k12's `/api/proxy` usage:
/// `type=API&sub_institute_id=..&syear=..` in the query and the JWT as a bearer token.
class PageService {
  PageService(this._api, this.session);

  final ApiClient _api;
  final Session session;

  Map<String, String> get _common => {
        'type': 'API',
        'sub_institute_id': '${session.subInstituteId}',
        if (session.mobileSyear != null) 'syear': session.mobileSyear!,
      };

  /// `endpoint` is relative to /api/ ("student-registration") or an absolute URL.
  Future<Map<String, dynamic>> call(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final isAbsolute = RegExp(r'^https?://', caseSensitive: false).hasMatch(endpoint);
    final path = isAbsolute ? endpoint : '/api/${endpoint.replaceFirst(RegExp(r'^/+'), '')}';
    final isRead = method.toUpperCase() == 'GET';
    final res = await _api.request(
      method,
      path,
      query: _common,
      // Legacy controllers read identity from the body on POST as well as the query.
      body: isRead ? null : {..._common, 'user_id': session.userId, ...?body},
      token: session.token,
    );
    final status = '${res['status'] ?? res['status_code'] ?? ''}';
    if (status == '0' || status == '2') {
      throw ApiException((res['message'] ?? "Couldn't complete that request. Try again.").toString());
    }
    return res;
  }

  /// Reads an endpoint whose HTTP method is not recorded (a dynamic page's data endpoint,
  /// a drill-down): the ERP's summary routes are POST, a few are GET. Tries POST first (or
  /// GET first when [preferPost] is false) and retries the other on 405/404.
  Future<Map<String, dynamic>> callAuto(String endpoint, {bool preferPost = true}) async {
    final order = preferPost ? ['POST', 'GET'] : ['GET', 'POST'];
    try {
      return await call(endpoint, method: order[0]);
    } on ApiException catch (e) {
      if (e.statusCode == 405 || e.statusCode == 404) {
        return call(endpoint, method: order[1]);
      }
      rethrow;
    }
  }

  /// The published layout of a Mobile Page Builder page.
  Future<Map<String, dynamic>> builderPage(String slug) async {
    final res = await call('mobile-page-builder/runtime/${Uri.encodeComponent(slug)}');
    final data = res['data'];
    if (data is! Map || data['layout'] is! Map) {
      throw ApiException('This page is not available.');
    }
    return Map<String, dynamic>.from(data);
  }

  /// A native_dynamic page: title, data endpoint and the tiles to read from it.
  Future<Map<String, dynamic>> dynamicPage(String key) async {
    final res = await call('mobile/dynamic-page/${Uri.encodeComponent(key)}');
    final data = res['data'];
    if (data is! Map) throw ApiException('This page is not configured.');
    return Map<String, dynamic>.from(data);
  }

  /// Which role dashboard this user gets.
  String get dashboardEndpoint {
    final p = session.userProfileName.trim().toLowerCase();
    if (p == 'student') return 'student-dashboard/summary';
    if (p == 'teacher') return 'teacher-dashboard/summary';
    return 'admin-dashboard/summary';
  }
}

/// Dotted-path read ("student.name") that never throws; null if any level is missing.
dynamic resolveField(dynamic data, String? path) {
  if (path == null || path.isEmpty) return null;
  dynamic cur = data;
  for (final key in path.split('.')) {
    if (cur is Map && cur.containsKey(key)) {
      cur = cur[key];
    } else if (cur is List && int.tryParse(key) != null && int.parse(key) < cur.length) {
      cur = cur[int.parse(key)];
    } else {
      return null;
    }
  }
  return cur;
}

/// `{{token}}` substitution against form values (button bodies, endpoints).
String resolveTemplate(String template, Map<String, String> values) =>
    template.replaceAllMapped(RegExp(r'\{\{\s*([\w.]+)\s*\}\}'), (m) => values[m[1]] ?? '');
