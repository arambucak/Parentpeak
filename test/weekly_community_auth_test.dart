import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/weekly_impulse_service.dart';

const _base = '/api/weekly-impulse/community';
const _operations = [
  ('post', 'POST', 'posts'),
  ('like', 'POST', 'posts/post1/like'),
  ('comment', 'POST', 'posts/post1/comments'),
  ('report', 'POST', 'posts/post1/report'),
  ('status', 'GET', 'verification-status'),
  ('request', 'POST', 'verification-requests'),
  ('requests', 'GET', 'verification-requests'),
  ('approve', 'POST', 'verification-requests/request1/approve'),
  ('reports', 'GET', 'reports'),
  ('resolve', 'POST', 'reports/report1/resolve'),
  ('visibility', 'POST', 'posts/post1/moderation-visibility'),
];

Future<void> _call(String action, WeeklyImpulseService service) async {
  switch (action) {
    case 'post':
      await service.createCommunityPost(
        impulseId: 'imp1',
        title: 'Title',
        body: 'Body',
        authorName: 'Parent',
        authorUserId: 'parent',
        authorEmail: 'parent@example.org',
        role: 'Elternteil',
      );
    case 'like':
      await service.setCommunityLike(
        impulseId: 'imp1',
        postId: 'post1',
        userId: 'parent',
        isLiked: true,
      );
    case 'comment':
      await service.addCommunityComment(
        impulseId: 'imp1',
        postId: 'post1',
        authorName: 'Parent',
        role: 'Elternteil',
        comment: 'Comment',
      );
    case 'report':
      await service.reportCommunityPost(
        impulseId: 'imp1',
        postId: 'post1',
        reporterUserId: 'parent',
        reporterName: 'Parent',
        reason: 'Spam',
      );
    case 'status':
      await service.fetchVerificationStatus(
        userId: 'parent',
        email: 'parent@example.org',
      );
    case 'request':
      await service.createVerificationRequest(
        userId: 'parent',
        email: 'parent@example.org',
        displayName: 'Parent',
        roleTitle: 'Educator',
        organization: 'School',
        note: 'Request',
      );
    case 'requests':
      await service.fetchVerificationRequests(
        reviewerEmail: 'mod@parentpeak.de',
      );
    case 'approve':
      await service.approveVerificationRequest(
        requestId: 'request1',
        reviewerName: 'Moderator',
        reviewerEmail: 'mod@parentpeak.de',
        reviewNote: 'Checked',
        verificationLabel: 'Verified',
      );
    case 'reports':
      await service.fetchModerationReports(
        impulseId: 'imp1',
        moderatorEmail: 'mod@parentpeak.de',
      );
    case 'resolve':
      await service.resolveModerationReport(
        impulseId: 'imp1',
        reportId: 'report1',
        moderatorName: 'Moderator',
        moderatorEmail: 'mod@parentpeak.de',
      );
    case 'visibility':
      await service.setCommunityPostHidden(
        impulseId: 'imp1',
        postId: 'post1',
        moderatorName: 'Moderator',
        moderatorEmail: 'mod@parentpeak.de',
        hidden: true,
      );
    default:
      throw ArgumentError.value(action);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'production weekly service requires Firebase and has no static-token fallback',
    () {
      dotenv.loadFromString(
        envString:
            'BACKEND_BASE_URL=https://backend.example\nBACKEND_API_TOKEN=static-token',
      );
      addTearDown(dotenv.clean);
      final client =
          BackendServiceFactory.createWeeklyImpulseService().apiClient!;
      expect(client.requireAuthToken, isTrue);
      expect(client.authToken, isNull);
      expect(client.authTokenProvider, isNotNull);
      expect(client.forceRefreshTokenProvider, isNotNull);
    },
  );

  for (final (action, method, path) in _operations) {
    test('$action sends the current Firebase token to $method $path', () async {
      var requests = 0;
      final httpClient = MockClient((request) async {
        requests++;
        expect(request.method, method);
        expect(request.url.path, '$_base/$path');
        expect(
          request.headers['Authorization'],
          'Bearer current-firebase-token',
        );
        return http.Response('{"items":[]}', 200);
      });
      addTearDown(httpClient.close);
      final service = WeeklyImpulseService(
        apiClient: BackendApiClient(
          baseUrl: 'https://backend.example',
          requireAuthToken: true,
          authTokenProvider: () async => 'current-firebase-token',
          httpClient: httpClient,
        ),
      );
      await _call(action, service);
      expect(requests, 1);
    });

    for (final tokenThrows in [false, true]) {
      test(
        '$action propagates ${tokenThrows ? 'token failure' : 'missing token'} without HTTP',
        () async {
          var requests = 0;
          final httpClient = MockClient((request) async {
            requests++;
            return http.Response('{"items":[]}', 200);
          });
          addTearDown(httpClient.close);
          final service = WeeklyImpulseService(
            apiClient: BackendApiClient(
              baseUrl: 'https://backend.example',
              authToken: 'must-not-be-used',
              requireAuthToken: true,
              authTokenProvider: () async {
                if (tokenThrows) throw StateError('Token lookup failed');
                return null;
              },
              httpClient: httpClient,
            ),
          );
          await expectLater(_call(action, service), throwsStateError);
          expect(requests, 0);
        },
      );
    }

    test('$action retries 401 once with a force-refreshed token', () async {
      var requests = 0;
      var refreshes = 0;
      final httpClient = MockClient((request) async {
        requests++;
        expect(
          request.headers['Authorization'],
          requests == 1 ? 'Bearer cached-token' : 'Bearer refreshed-token',
        );
        return http.Response('{"items":[]}', requests == 1 ? 401 : 200);
      });
      addTearDown(httpClient.close);
      final service = WeeklyImpulseService(
        apiClient: BackendApiClient(
          baseUrl: 'https://backend.example',
          requireAuthToken: true,
          authTokenProvider: () async => 'cached-token',
          forceRefreshTokenProvider: () async {
            refreshes++;
            return 'refreshed-token';
          },
          httpClient: httpClient,
        ),
      );
      await _call(action, service);
      expect(requests, 2);
      expect(refreshes, 1);
    });

    for (final status in [401, 403, 503]) {
      test(
        '$action propagates HTTP $status instead of success or empty lists',
        () async {
          final httpClient = MockClient(
            (_) async => http.Response('{"error":"Denied"}', status),
          );
          addTearDown(httpClient.close);
          final service = WeeklyImpulseService(
            apiClient: BackendApiClient(
              baseUrl: 'https://backend.example',
              requireAuthToken: true,
              authTokenProvider: () async => 'firebase-token',
              httpClient: httpClient,
            ),
          );
          await expectLater(
            _call(action, service),
            throwsA(
              isA<BackendApiException>().having(
                (e) => e.statusCode,
                'status',
                status,
              ),
            ),
          );
        },
      );
    }
  }
}
