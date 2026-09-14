import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Wird geworfen, wenn der Server ein gesperrtes Konto meldet (403 mit
/// code 'account_suspended'). Erlaubt der UI, einen ruhigen Hinweis zu zeigen.
class SuspendedAccountException implements Exception {
  final String message;
  const SuspendedAccountException(
      [this.message =
          'Dein Konto wurde vorübergehend eingeschränkt. Bei Fragen wende dich an unseren Support.']);
  @override
  String toString() => message;
}

class BackendApiClient {
  BackendApiClient({
    required this.baseUrl,
    this.authToken,
    this.authTokenProvider,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String? authToken;
  final Future<String?> Function()? authTokenProvider;
  final http.Client _httpClient;

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

  Future<Map<String, String>> _headers({bool includeContentType = true}) async {
    final headers = <String, String>{
      if (includeContentType) 'Content-Type': 'application/json',
    };

    final resolvedToken = await _resolveAuthToken();
    if (resolvedToken != null && resolvedToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $resolvedToken';
    }

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
        throw SuspendedAccountException(msg is String && msg.isNotEmpty
            ? msg
            : const SuspendedAccountException().message);
      }
    } on SuspendedAccountException {
      rethrow;
    } catch (_) {
      // Kein JSON / kein Suspend-Code: normal weiterbehandeln.
    }
  }

  Future<dynamic> getJson(String path) async {
    final headers = await _headers();
    final response = await _httpClient
        .get(_uri(path), headers: headers)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('GET $path failed: ${response.statusCode}');
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
    Map<String, dynamic> body,
  ) async {
    final decoded = await postJsonAny(path, body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception('Unexpected map response for $path');
  }

  Future<dynamic> postJsonAny(
    String path,
    Map<String, dynamic> body,
  ) async {
    final headers = await _headers();
    final response = await _httpClient
        .post(
          _uri(path),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwIfSuspended(response);
      throw Exception('POST $path failed: ${response.statusCode}');
    }

    return _decodeResponse(response.body);
  }

  Future<dynamic> putJson(String path, Map<String, dynamic> body) async {
    final headers = await _headers();
    final response = await _httpClient
        .put(
          _uri(path),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwIfSuspended(response);
      throw Exception('PUT $path failed: ${response.statusCode}');
    }

    return _decodeResponse(response.body);
  }

  Future<void> delete(String path) async {
    final headers = await _headers();
    final response = await _httpClient
        .delete(
          _uri(path),
          headers: headers,
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('DELETE $path failed: ${response.statusCode}');
    }
  }

  Future<dynamic> deleteJson(String path, Map<String, dynamic> body) async {
    final headers = await _headers();
    final response = await _httpClient
        .delete(
          _uri(path),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('DELETE $path failed: ${response.statusCode}');
    }

    return _decodeResponse(response.body);
  }

  /// Uploads an image file via multipart POST to [path] (field name: 'image').
  /// Returns the decoded JSON response or throws on failure.
  Future<Map<String, dynamic>> uploadImageFile(
    String path,
    File file,
  ) async {
    final uri = _uri(path);
    final request = http.MultipartRequest('POST', uri);
    final uploadHeaders = await _headers(includeContentType: false);
    request.headers.addAll(uploadHeaders);
    request.files.add(await http.MultipartFile.fromPath('image', file.path));
    final streamed =
        await _httpClient.send(request).timeout(const Duration(seconds: 30));
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
    request.files.add(http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: filename,
    ));
    final streamed =
        await _httpClient.send(request).timeout(const Duration(seconds: 30));
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
    await postJsonAny(
      '/devices/register-token',
      {'userId': userId, 'token': token, 'platform': platform},
    );
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
          'DELETE /devices/register-token failed: ${response.statusCode}');
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
          'BackendApiClient._decodeResponse(): non-JSON response fallback: $e');
      return <String, dynamic>{'raw': rawBody};
    }
  }
}
