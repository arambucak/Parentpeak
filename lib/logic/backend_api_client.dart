import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Wird geworfen, wenn der Server ein gesperrtes Konto meldet (403 mit
/// code 'account_suspended'). Erlaubt der UI, einen ruhigen Hinweis zu zeigen.
class SuspendedAccountException implements Exception {
  final String message;
  const SuspendedAccountException([
    this.message =
        'Dein Konto wurde vorübergehend eingeschränkt. Bei Fragen wende dich an unseren Support.',
  ]);
  @override
  String toString() => message;
}

/// Fehlgeschlagene Backend-Antwort mit HTTP-Status und (falls vorhanden) der
/// Server-Fehlermeldung. Erlaubt Aufrufern, Auth-Fehler (401) von Server-/
/// Upstream-Fehlern (z.B. 502) zu unterscheiden, statt nur eine generische
/// Exception zu sehen. Implementiert [Exception], ist also abwärtskompatibel
/// zu bestehenden `catch`/`throwsException`-Stellen.
class BackendApiException implements Exception {
  BackendApiException({
    required this.method,
    required this.path,
    required this.statusCode,
    this.serverMessage,
  });

  final String method;
  final String path;
  final int statusCode;
  final String? serverMessage;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() {
    final detail = serverMessage != null && serverMessage!.isNotEmpty
        ? ' — $serverMessage'
        : '';
    return '$method $path failed: $statusCode$detail';
  }
}

/// Extrahiert die 'error'-Nachricht aus einem JSON-Fehlerbody, falls vorhanden.
String? _extractServerError(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return null;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map && decoded['error'] is String) {
      return decoded['error'] as String;
    }
  } catch (_) {
    // Kein JSON — rohen (gekürzten) Text zurückgeben.
    return trimmed.length > 200 ? '${trimmed.substring(0, 200)}…' : trimmed;
  }
  return null;
}

class BackendApiClient {
  BackendApiClient({
    required this.baseUrl,
    this.authToken,
    this.authTokenProvider,
    this.forceRefreshTokenProvider,
    this.requestGuard,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String? authToken;
  final Future<String?> Function()? authTokenProvider;

  /// Liefert einen frisch erzwungenen Token (Force-Refresh). Wird nur nach einem
  /// 401 genutzt, um einmal mit frischem Token zu wiederholen — ohne jeden Call
  /// zu verlangsamen.
  final Future<String?> Function()? forceRefreshTokenProvider;
  final http.Client _httpClient;
  final void Function()? requestGuard;

  BackendApiClient withRequestGuard(void Function() guard) => BackendApiClient(
    baseUrl: baseUrl,
    authToken: authToken,
    authTokenProvider: authTokenProvider,
    forceRefreshTokenProvider: forceRefreshTokenProvider,
    httpClient: _httpClient,
    requestGuard: () {
      requestGuard?.call();
      guard();
    },
  );

  Future<String?> _resolveAuthToken() async {
    // Prefer per-user Firebase token. Static fallback tokens are shared secrets
    // and may become stale, which can break authenticated requests.
    if (authTokenProvider != null) {
      try {
        final dynamicToken = await authTokenProvider!();
        final normalized = dynamicToken?.trim();
        if (normalized != null && normalized.isNotEmpty) {
          return normalized;
        }
      } catch (e) {
        debugPrint(
          'BackendApiClient._resolveAuthToken(): token provider failed: $e',
        );
      }
    }

    final staticToken = authToken?.trim();
    if (staticToken != null && staticToken.isNotEmpty) {
      return staticToken;
    }

    return null;
  }

  Future<Map<String, String>> _headers({
    bool includeContentType = true,
    bool forceRefresh = false,
  }) async {
    requestGuard?.call();
    final headers = <String, String>{
      if (includeContentType) 'Content-Type': 'application/json',
    };

    String? token;
    if (forceRefresh && forceRefreshTokenProvider != null) {
      token = (await forceRefreshTokenProvider!())?.trim();
    }
    token ??= await _resolveAuthToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    requestGuard?.call();
    return headers;
  }

  Uri _uri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }

  /// Wirft [SuspendedAccountException], falls die Antwort ein gesperrtes Konto
  /// signalisiert (403 + code 'account_suspended').
  void _throwIfSuspended(http.Response response) {
    if (response.statusCode != 403) return;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['code'] == 'account_suspended') {
        final msg = decoded['error'];
        throw SuspendedAccountException(
          msg is String && msg.isNotEmpty
              ? msg
              : const SuspendedAccountException().message,
        );
      }
    } on SuspendedAccountException {
      rethrow;
    } catch (_) {
      // Kein JSON / kein Suspend-Code: normal weiterbehandeln.
    }
  }

  Future<dynamic> getJson(String path) async {
    var headers = await _headers();
    requestGuard?.call();
    var response = await _httpClient
        .get(_uri(path), headers: headers)
        .timeout(const Duration(seconds: 20));
    requestGuard?.call();

    // Bei 401 einmal mit frisch erzwungenem Token wiederholen (abgelaufener
    // gecachter Token). Vermeidet Force-Refresh auf jedem normalen Call.
    if (response.statusCode == 401 && forceRefreshTokenProvider != null) {
      headers = await _headers(forceRefresh: true);
      requestGuard?.call();
      response = await _httpClient
          .get(_uri(path), headers: headers)
          .timeout(const Duration(seconds: 20));
      requestGuard?.call();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        method: 'GET',
        path: path,
        statusCode: response.statusCode,
        serverMessage: _extractServerError(response.body),
      );
    }

    return _decodeResponse(response.body);
  }

  Future<List<dynamic>> getList(String path) async {
    final decoded = await getJson(path);
    if (decoded is List<dynamic>) {
      return decoded;
    }
    throw Exception('Unexpected list response for $path');
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) async {
    final decoded = await postJsonAny(path, body, timeout: timeout);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception('Unexpected map response for $path');
  }

  Future<dynamic> postJsonAny(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? const Duration(seconds: 30);
    final encoded = jsonEncode(body);
    var headers = await _headers();
    requestGuard?.call();
    var response = await _httpClient
        .post(_uri(path), headers: headers, body: encoded)
        .timeout(effectiveTimeout);
    requestGuard?.call();

    // Bei 401 einmal mit frisch erzwungenem Token wiederholen.
    if (response.statusCode == 401 && forceRefreshTokenProvider != null) {
      headers = await _headers(forceRefresh: true);
      requestGuard?.call();
      response = await _httpClient
          .post(_uri(path), headers: headers, body: encoded)
          .timeout(effectiveTimeout);
      requestGuard?.call();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwIfSuspended(response);
      throw BackendApiException(
        method: 'POST',
        path: path,
        statusCode: response.statusCode,
        serverMessage: _extractServerError(response.body),
      );
    }

    return _decodeResponse(response.body);
  }

  Future<dynamic> putJson(String path, Map<String, dynamic> body) async {
    final headers = await _headers();
    requestGuard?.call();
    final response = await _httpClient
        .put(_uri(path), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 8));
    requestGuard?.call();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwIfSuspended(response);
      throw Exception('PUT $path failed: ${response.statusCode}');
    }

    return _decodeResponse(response.body);
  }

  Future<void> delete(String path) async {
    final headers = await _headers();
    requestGuard?.call();
    final response = await _httpClient
        .delete(_uri(path), headers: headers)
        .timeout(const Duration(seconds: 8));
    requestGuard?.call();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('DELETE $path failed: ${response.statusCode}');
    }
  }

  Future<dynamic> deleteJson(String path, Map<String, dynamic> body) async {
    final headers = await _headers();
    final response = await _httpClient
        .delete(_uri(path), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('DELETE $path failed: ${response.statusCode}');
    }

    return _decodeResponse(response.body);
  }

  /// Uploads an image file via multipart POST to [path] (field name: 'image').
  /// Returns the decoded JSON response or throws on failure.
  Future<Map<String, dynamic>> uploadImageFile(String path, File file) async {
    final uri = _uri(path);
    final request = http.MultipartRequest('POST', uri);
    final uploadHeaders = await _headers(includeContentType: false);
    request.headers.addAll(uploadHeaders);
    request.files.add(await http.MultipartFile.fromPath('image', file.path));
    final streamed = await _httpClient
        .send(request)
        .timeout(const Duration(seconds: 30));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('POST $path (multipart) failed: ${streamed.statusCode}');
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'raw': body};
  }

  /// Uploads image bytes via multipart POST. Used by Flutter web, where a
  /// stable local file path is unavailable.
  Future<Map<String, dynamic>> uploadImageBytes(
    String path,
    List<int> bytes, {
    required String filename,
  }) async {
    final uri = _uri(path);
    final request = http.MultipartRequest('POST', uri);
    final uploadHeaders = await _headers(includeContentType: false);
    request.headers.addAll(uploadHeaders);
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: filename),
    );
    final streamed = await _httpClient
        .send(request)
        .timeout(const Duration(seconds: 30));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('POST $path (multipart) failed: ${streamed.statusCode}');
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'raw': body};
  }

  /// Registers a Firebase Cloud Messaging device token for [userId].
  Future<void> registerFcmToken({
    required String userId,
    required String token,
    String platform = 'flutter',
  }) async {
    await postJsonAny('/devices/register-token', {
      'userId': userId,
      'token': token,
      'platform': platform,
    });
  }

  /// Unregisters an FCM token (e.g. on logout).
  Future<void> unregisterFcmToken({
    required String userId,
    required String token,
  }) async {
    final headers = await _headers();
    final response = await _httpClient
        .delete(
          _uri('/devices/register-token'),
          headers: headers,
          body: jsonEncode({'userId': userId, 'token': token}),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode >= 400) {
      throw Exception(
        'DELETE /devices/register-token failed: ${response.statusCode}',
      );
    }
  }

  dynamic _decodeResponse(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      return jsonDecode(rawBody);
    } catch (e) {
      debugPrint(
        'BackendApiClient._decodeResponse(): non-JSON response fallback: $e',
      );
      return <String, dynamic>{'raw': rawBody};
    }
  }
}
