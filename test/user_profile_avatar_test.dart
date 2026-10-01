import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/user_profile_service.dart';

class _AvatarApi extends BackendApiClient {
  _AvatarApi() : super(baseUrl: 'https://example.invalid');

  final calls = <Map<String, dynamic>>[];

  @override
  Future<dynamic> postJsonAny(String path, Map<String, dynamic> body) async {
    calls.add({'path': path, 'body': body});
    return {'ok': true};
  }

  @override
  Future<dynamic> getJson(String path) async => {
        'exists': true,
        'avatarUrl': 'https://cdn.example/avatar.jpg',
      };
}

void main() {
  test('avatar profile data is persisted and loaded through the profile API', () async {
    final api = _AvatarApi();
    final service = UserProfileService.forTesting(api);

    await service.setAvatarUrl('https://cdn.example/avatar.jpg');
    final avatar = await service.avatarUrlFor('parent-1');

    expect(avatar, 'https://cdn.example/avatar.jpg');
    expect(api.calls.single['path'], '/api/profile');
    expect((api.calls.single['body'] as Map<String, dynamic>)['avatarUrl'],
        'https://cdn.example/avatar.jpg');
  });
}
