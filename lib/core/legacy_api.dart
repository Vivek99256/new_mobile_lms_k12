import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'config.dart';
import 'session.dart';

/// A file to upload with a form.
class UploadFile {
  const UploadFile(this.field, this.path);
  final String field;
  final String path;
}

/// Calls the ERP's legacy mobile endpoints the way the old app did: `multipart/form-data`
/// POST (or GET with a query), with the user's `token` and identity in the body.
///
/// Responses keep the old envelope: `status` `"1"` is success, `"0"` an error with a
/// `message`, `"2"` an authentication failure.
class LegacyApi {
  LegacyApi(this.session, {http.Client? client}) : _client = client ?? http.Client();

  final Session session;
  final http.Client _client;
  static const _timeout = Duration(seconds: 45);

  /// Identity fields almost every legacy endpoint expects. Student endpoints read
  /// `student_id`; staff endpoints read `user_id`.
  Map<String, String> get identity => {
        'token': session.token,
        'sub_institute_id': '${session.subInstituteId}',
        if (session.mobileSyear != null) 'syear': session.mobileSyear!,
        'user_id': '${session.userId}',
        'teacher_id': '${session.userId}',
        'admin_id': '${session.userId}',
        'student_id': '${session.userId}',
        'user_profile_id': '${session.userProfileId}',
        'user_profile_name': session.userProfileName,
        'type': 'API',
      };

  Uri _uri(String url, [Map<String, String>? query]) {
    final isAbsolute = RegExp(r'^https?://', caseSensitive: false).hasMatch(url);
    final base = Uri.parse(isAbsolute ? url : '${AppConfig.apiBase}$url');
    return query == null || query.isEmpty
        ? base
        : base.replace(queryParameters: {...base.queryParameters, ...query});
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${session.token}',
      };

  Future<Map<String, dynamic>> post(
    String url, {
    Map<String, dynamic> body = const {},
    List<UploadFile> files = const [],
    bool withIdentity = true,
  }) async {
    final req = http.MultipartRequest('POST', _uri(url))
      ..headers.addAll(_headers)
      ..fields.addAll({
        if (withIdentity) ...identity,
        for (final e in body.entries)
          if (e.value != null) e.key: '${e.value}',
      });
    for (final f in files) {
      if (File(f.path).existsSync()) {
        req.files.add(await http.MultipartFile.fromPath(f.field, f.path));
      }
    }
    return _finish(() async => http.Response.fromStream(await _client.send(req)));
  }

  Future<Map<String, dynamic>> get(
    String url, {
    Map<String, dynamic> query = const {},
    bool withIdentity = true,
  }) {
    final q = <String, String>{
      if (withIdentity) ...identity,
      for (final e in query.entries)
        if (e.value != null) e.key: '${e.value}',
    };
    return _finish(() => _client.get(_uri(url, q), headers: _headers));
  }

  Future<Map<String, dynamic>> _finish(Future<http.Response> Function() send) async {
    final http.Response res;
    try {
      res = await send().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Try again.');
    } catch (e, st) {
      throw transportError(e, st);
    }
    if (res.statusCode >= 500) throw ApiException('The server had a problem. Try again shortly.');
    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      throw ApiException('The server returned an unexpected response.', statusCode: res.statusCode);
    }
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{'data': decoded};
    final status = '${map['status'] ?? map['status_code'] ?? ''}';
    if (status == '2') {
      throw ApiException('${map['message'] ?? 'Your session has expired. Sign in again.'}', statusCode: 401);
    }
    return map;
  }

  /// True when the envelope says success. Understands the legacy `status`/`status_code`
  /// "1", the newer `success: true`, and flat bodies that carry data without any status key
  /// (the web-proven `front_desk/*` routes).
  static bool ok(Map<String, dynamic> res) {
    final s = '${res['status'] ?? res['status_code'] ?? ''}'.toUpperCase();
    if (s == '1' || s == 'SUCCESS' || s == 'TRUE') return true;
    if (s.isNotEmpty) return false;
    if (res['success'] != null) return res['success'] == true || '${res['success']}' == '1';
    return res['data'] != null || res.keys.any((k) => k != 'message' && k != 'errors');
  }

  static String messageOf(Map<String, dynamic> res, [String fallback = 'Something went wrong.']) {
    final m = '${res['message'] ?? ''}'.trim();
    return m.isEmpty ? fallback : m;
  }
}
