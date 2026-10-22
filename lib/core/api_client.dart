import 'dart:async';
import 'dart:convert';
import 'dart:io' show HandshakeException, SocketException, TlsException;

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Thin JSON client for the Laravel ERP. Authenticated calls send the JWT both
/// as a bearer header and as `token`, which is how the legacy `api.session`
/// middleware (GenTux JwtToken) looks for it.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 30);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic> body = const {},
    String? token,
  }) async {
    final payload = {...body, 'token': ?token};
    return _send(() => _client.post(
          Uri.parse('${AppConfig.apiBase}$path'),
          headers: _headers(token),
          body: jsonEncode(payload),
        ));
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> query = const {},
    String? token,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}$path').replace(queryParameters: {
      ...query,
      'token': ?token,
    });
    return _send(() => _client.get(uri, headers: _headers(token)));
  }

  /// Any method against a path on the ERP or an absolute URL. `query` is always sent in
  /// the URL (the ERP's `type=API&sub_institute_id=..` convention); `body`, when given,
  /// is sent as JSON.
  Future<Map<String, dynamic>> request(
    String method,
    String pathOrUrl, {
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    String? token,
  }) {
    final isAbsolute = RegExp(r'^https?://', caseSensitive: false).hasMatch(pathOrUrl);
    final base = Uri.parse(isAbsolute ? pathOrUrl : '${AppConfig.apiBase}$pathOrUrl');
    final uri = base.replace(queryParameters: {...base.queryParameters, ...query});
    final headers = _headers(token);
    final encoded = body == null ? null : jsonEncode(body);
    return _send(() {
      switch (method.toUpperCase()) {
        case 'GET':
          return _client.get(uri, headers: headers);
        case 'PUT':
          return _client.put(uri, headers: headers, body: encoded);
        case 'PATCH':
          return _client.patch(uri, headers: headers, body: encoded);
        case 'DELETE':
          return _client.delete(uri, headers: headers, body: encoded);
        default:
          return _client.post(uri, headers: headers, body: encoded ?? '{}');
      }
    });
  }

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': ?(token == null ? null : 'Bearer $token'),
      };

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    final http.Response res;
    try {
      res = await call().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Try again.');
    } catch (e, st) {
      throw transportError(e, st);
    }

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(res.body);
      data = decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    } catch (_) {
      throw ApiException('The server returned an unexpected response.', statusCode: res.statusCode);
    }

    if (res.statusCode >= 400) {
      throw ApiException(
        (data['message'] ?? 'Request failed (${res.statusCode}).').toString(),
        statusCode: res.statusCode,
      );
    }
    return data;
  }
}

/// Turns a transport-level failure into a message that says what went wrong, and logs the
/// raw error so it shows in `flutter run` / logcat. A real "no network" stays friendly;
/// anything else (TLS, DNS, a bug while building the request) is no longer disguised as one.
ApiException transportError(Object error, [StackTrace? stack]) {
  debugPrint('Network call failed: ${error.runtimeType}: $error');
  if (stack != null && kDebugMode) debugPrint('$stack');
  if (error is HandshakeException || error is TlsException) {
    return ApiException('A secure connection could not be made. Check the date and time on this device.');
  }
  if (error is SocketException) {
    final os = (error.osError?.message ?? error.message).toLowerCase();
    return ApiException(os.contains('lookup') || os.contains('resolve')
        ? 'The server address could not be found. Check your internet connection.'
        : 'Could not reach the server. Check your internet connection and try again.');
  }
  if (error is http.ClientException) {
    return ApiException('The connection was interrupted. Try again.');
  }
  return ApiException('Something went wrong while contacting the server (${error.runtimeType}).');
}
