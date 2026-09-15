import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/models/kind_dossier.dart';

void main() {
  test('migrates legacy KindDossier ageMonths to a live birthDate', () {
    final dossier = KindDossier.fromJson({
      'childName': 'Mia',
      'ageMonths': 60,
    });

    expect(dossier.ageMonths, closeTo(60, 1));
    expect(dossier.toJson()['birthDate'], isA<String>());
  });

  test('ChildEntry keeps ageMonths compatible while storing birthDate', () {
    final child = ChildEntry(name: 'Sam', ageMonths: 72);

    expect(child.ageMonths, closeTo(72, 1));
    expect(child.ageYears, 6);
    expect(child.toJson()['birthDate'], isA<String>());

    child.ageMonths = 84;
    expect(child.ageYears, 7);
  });
}
