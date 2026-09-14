import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/parent_coin_service.dart';

/// Sichert das Kernversprechen ab: der Freundes-Code ist deterministisch aus
/// der Firebase-UID abgeleitet -> gleiche UID = gleicher Code (App = Web),
/// verschiedene UIDs = verschiedene Codes, Format 'PP-XXXXXXX'.
void main() {
  group('ParentCoinService.referralCodeForUid', () {
    test('ist deterministisch (gleiche UID -> gleicher Code)', () {
      const uid = 'abc123DEF456ghi789JKL012mno';
      final a = ParentCoinService.referralCodeForUid(uid);
      final b = ParentCoinService.referralCodeForUid(uid);
      expect(a, b);
    });

    test('verschiedene UIDs geben (praktisch) verschiedene Codes', () {
      final a = ParentCoinService.referralCodeForUid('uid-eins');
      final b = ParentCoinService.referralCodeForUid('uid-zwei');
      expect(a, isNot(b));
    });

    test('Format ist PP- + 7 Zeichen aus verwechslungsarmem Alphabet', () {
      final code = ParentCoinService.referralCodeForUid('irgendeine-uid');
      expect(code.startsWith('PP-'), isTrue);
      final body = code.substring(3);
      expect(body.length, 7);
      // Keine verwechselbaren Zeichen 0, O, 1, I.
      expect(RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{7}$').hasMatch(body),
          isTrue);
    });
  });
}
