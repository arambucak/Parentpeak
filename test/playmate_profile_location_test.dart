import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';
import 'package:parentpeak/logic/playmate_profile_service.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

FamilyMatchProfile profile({String? city, double? lat, double? lon}) =>
    FamilyMatchProfile(
      displayName: 'Family',
      district: 'Munich district',
      city: city,
      latitude: lat,
      longitude: lon,
      children: [],
      languages: ['en'],
      familyForm: 'kernfamilie',
      values: [],
      lookingFor: [],
      createdAt: DateTime(2026, 10, 6),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Map<String, dynamic>> publish(FamilyMatchProfile p) async {
    Map<String, dynamic>? payload;
    final service = PlaymateProfileService(
      matchingService: ParentMatchingBackendService(
        apiClient: BackendApiClient(
          baseUrl: 'https://backend.example',
          httpClient: MockClient((request) async {
            payload = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'item': {
                  'id': 'self-owner',
                  'ownerUserId': 'owner',
                  'name': payload!['name'],
                  'city': payload!['city'],
                },
              }),
              201,
            );
          }),
        ),
      ),
    );
    expect(
      await service.publishProfile(
        p,
        'owner',
        confirmPublication: () async => true,
      ),
      PlaymatePublicationResult.published,
    );
    return payload!;
  }

  test(
    'selected profile location overrides a different global location',
    () async {
      await LocationService.instance.setCoordinates(
        52.520008,
        13.404954,
        city: 'Berlin',
      );
      final payload = await publish(
        profile(city: 'Munich', lat: 48.137154, lon: 11.576124),
      );
      expect(payload['city'], 'Munich');
      expect(payload['latitude'], 48.14);
      expect(payload['longitude'], 11.58);
      expect(LocationService.instance.city, 'Berlin');
      expect(LocationService.instance.latitude, 52.520008);
      await LocationService.instance.clear();
    },
  );

  test(
    'legacy profile without coordinates does not reuse global GPS',
    () async {
      await LocationService.instance.setCoordinates(
        52.520008,
        13.404954,
        city: 'Berlin',
      );
      final legacy = FamilyMatchProfile.fromJson(
        {...profile().toJson()}
          ..remove('city')
          ..remove('latitude')
          ..remove('longitude'),
      );
      final payload = await publish(legacy);
      expect(payload['city'], 'Munich district');
      expect(payload['latitude'], isNull);
      expect(payload['longitude'], isNull);
      await LocationService.instance.clear();
    },
  );

  test('profile coordinates survive local round-trip', () async {
    final selected = profile(city: 'Munich', lat: 48.14, lon: 11.58);
    await selected.save();
    final loaded = await FamilyMatchProfile.load();
    expect(loaded!.city, 'Munich');
    expect(loaded.latitude, 48.14);
    expect(loaded.longitude, 11.58);
  });
}
