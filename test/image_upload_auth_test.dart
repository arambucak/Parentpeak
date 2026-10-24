import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/event_backend_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File photo;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pp-upload-auth-');
    photo = await File('${directory.path}/camera.PNG').writeAsBytes([1, 2, 3]);
  });
  tearDown(() => directory.delete(recursive: true));

  EventBackendService service(
    Future<http.Response> Function(http.Request) handler, {
    Future<String?> Function()? token,
  }) {
    final client = MockClient(handler);
    addTearDown(client.close);
    return EventBackendService(
      apiClient: BackendApiClient(
        baseUrl: 'https://backend.example',
        authToken: 'shared-must-not-be-used',
        authTokenProvider: token ?? () async => 'firebase-token',
        httpClient: client,
      ),
    );
  }

  Future<String?> upload(EventBackendService api, bool native) => native
      ? api.uploadImage(photo)
      : api.uploadImageBytes([1, 2, 3], filename: 'camera.PNG');

  for (final native in [false, true]) {
    test('upload native=$native sends Firebase and actual image MIME',
        () async {
      final api = service((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/uploads/image');
        expect(request.headers['Authorization'], 'Bearer firebase-token');
        expect(request.body, contains('content-type: image/png'));
        expect(request.body, contains('filename="camera.PNG"'));
        return http.Response('{"url":"/uploads/sanitized.png"}', 201);
      });
      expect(await upload(api, native), '/uploads/sanitized.png');
      expect(api.lastSyncError, isNull);
    });
    for (final token in <String?>[null, '', ' ', 'throws']) {
      test('upload native=$native rejects token $token before HTTP', () async {
        var requests = 0;
        final api = service((_) async {
          requests++;
          return http.Response('{"url":"/uploads/incorrect.png"}', 201);
        }, token: () async {
          if (token == 'throws') throw StateError('Token unavailable');
          return token;
        });
        expect(await upload(api, native), isNull);
        expect(api.lastSyncError, isNotEmpty);
        expect(requests, 0);
      });
    }
    for (final status in [400, 401, 403, 500, 503]) {
      test('upload native=$native HTTP $status never returns an image URL',
          () async {
        final api = service((_) async => http.Response('{}', status));
        expect(await upload(api, native), isNull);
        expect(api.lastSyncError, contains('$status'));
      });
    }
    for (final body in ['{}', '{"url":""}', '{"url":7}']) {
      test('upload native=$native rejects missing/malformed URL: $body',
          () async {
        final api = service((_) async => http.Response(body, 201));
        expect(await upload(api, native), isNull);
        expect(api.lastSyncError, isNotEmpty);
      });
    }
  }
}
