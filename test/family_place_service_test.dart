import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/models/family_place.dart';
import 'package:parentpeak/services/family_place_service.dart';

void main() {
  test('sorts family places by proximity and keeps real categories', () {
    const far = FamilyPlace(
      id: 'far',
      name: 'Ferner Park',
      category: FamilyPlaceCategory.playground,
      lat: 52.5400,
      lng: 13.5000,
      isIndoor: false,
    );
    const near = FamilyPlace(
      id: 'near',
      name: 'Naher Spielplatz',
      category: FamilyPlaceCategory.playground,
      lat: 52.5220,
      lng: 13.4020,
      isIndoor: false,
    );

    final sorted = FamilyPlaceService.sortPlaces([far, near], 52.52, 13.40);

    expect(sorted.first.id, 'near');
    expect(sorted.map((place) => place.category).toSet().contains(FamilyPlaceCategory.playground), isTrue);
  });

  test('open status is detected from opening_hours and indoor flag', () {
    const place = FamilyPlace(
      id: 'open',
      name: 'Indoor Spielplatz',
      category: FamilyPlaceCategory.indoorPlayground,
      lat: 52.52,
      lng: 13.40,
      isIndoor: true,
      openingHours: 'Mo-Fr 09:00-18:00; Sa 09:00-14:00',
    );

    final isOpen = FamilyPlaceService.isOpenNow(place, DateTime(2026, 9, 16, 10, 0));
    expect(isOpen, isTrue);
  });
}
