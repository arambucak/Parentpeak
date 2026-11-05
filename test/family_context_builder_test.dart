import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/family_context_builder.dart';
import 'package:parentpeak/models/family_profile_model.dart';

void main() {
  const builder = FamilyContextBuilder();
  final now = DateTime(2026, 11, 5);

  FamilyMatchProfile profile({
    List<ChildEntry> children = const [],
    List<String> values = const [],
    String? valuesCustom,
  }) =>
      FamilyMatchProfile(
        displayName: 'Test',
        district: 'Mitte',
        children: children,
        languages: const ['de'],
        familyForm: 'kernfamilie',
        values: values,
        valuesCustom: valuesCustom,
        lookingFor: const [],
        createdAt: now,
      );

  ChildEntry child(int years) =>
      ChildEntry(name: 'X', birthDate: DateTime(now.year - years, 1, 1));

  test('returns empty string when there is nothing to say', () {
    expect(builder.build(profile: null, languageCode: 'de', now: now), '');
    expect(builder.build(profile: profile(), languageCode: 'de', now: now), '');
  });

  test('includes a single child age', () {
    final out = builder.build(
      profile: profile(children: [child(4)]),
      languageCode: 'de',
      now: now,
    );
    expect(out, contains('4'));
    expect(out.toLowerCase(), contains('kind'));
  });

  test('includes multiple children with ages', () {
    final out = builder.build(
      profile: profile(children: [child(10), child(4)]),
      languageCode: 'de',
      now: now,
    );
    expect(out, contains('2'));
    expect(out, contains('4'));
    expect(out, contains('10'));
  });

  test('includes parenting values as readable labels without emoji', () {
    final out = builder.build(
      profile: profile(values: ['gfk', 'bedürfnisorientiert']),
      languageCode: 'de',
      now: now,
    );
    expect(out, contains('Gewaltfreie Kommunikation'));
    expect(out, contains('Bedürfnisorientiert'));
    // Kein führendes Emoji im Kontext
    expect(out.contains('\u{1F49A}'), isFalse);
  });

  test('never leaks a child name', () {
    final out = builder.build(
      profile: profile(children: [
        ChildEntry(name: 'Geheim', birthDate: DateTime(now.year - 3, 1, 1))
      ]),
      languageCode: 'de',
      now: now,
    );
    expect(out.contains('Geheim'), isFalse);
  });

  test('includes recurring topics when provided', () {
    final out = builder.build(
      profile: profile(children: [child(5)]),
      languageCode: 'de',
      topTopics: ['Schlaf', 'Medien'],
      now: now,
    );
    expect(out, contains('Schlaf'));
    expect(out, contains('Medien'));
  });

  test('works in English', () {
    final out = builder.build(
      profile: profile(children: [child(6)], values: ['gfk']),
      languageCode: 'en',
      now: now,
    );
    expect(out, contains('6'));
    expect(out.toLowerCase(), contains('child'));
  });
}
