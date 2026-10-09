import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/services/chat_moderation_service.dart';
import 'package:parentpeak/services/ai_rate_limiter.dart';

/// Security tests — verifies security measures are in place.
void main() {
  group('Security Checks', () {
    test('.env file is NOT committed to git', () {
      // .env should be in .gitignore
      final gitignore = File('.gitignore').readAsStringSync();
      expect(gitignore.contains('.env'), isTrue);
    });

    test('storage.rules file exists', () {
      expect(File('storage.rules').existsSync(), isTrue);
    });

    test('storage.rules blocks default access', () {
      final rules = File('storage.rules').readAsStringSync();
      // Should have a catch-all deny rule
      expect(rules.contains('allow read, write: if false'), isTrue);
    });

    test('storage.rules requires auth for uploads', () {
      final rules = File('storage.rules').readAsStringSync();
      expect(rules.contains('request.auth != null'), isTrue);
    });

    test('storage.rules limits file size', () {
      final rules = File('storage.rules').readAsStringSync();
      expect(rules.contains('request.resource.size'), isTrue);
    });

    test('storage.rules only allows images', () {
      final rules = File('storage.rules').readAsStringSync();
      expect(rules.contains("contentType.matches('image/.*')"), isTrue);
    });

    test(
      'treasure rules bind writes and deletes to UID and exclude flat objects',
      () {
        final rules = File('storage.rules').readAsStringSync();
        final scoped = rules
            .split('match /treasures/{userId}/{allPaths=**} {')[1]
            .split('match /treasures/{fileName}')[0];
        expect(scoped, contains('request.auth.uid == userId'));
        expect(scoped, contains('allow delete:'));
        expect(
          scoped,
          contains("request.resource.name.matches('treasures/[^/]+/.+')"),
        );
        expect(scoped, contains("resource.name.matches('treasures/[^/]+/.+')"));
        final legacy = rules
            .split('match /treasures/{fileName} {')[1]
            .split('match /profiles/')[0];
        expect(legacy, contains('allow read: if true'));
        expect(legacy, contains('allow write, delete: if false'));
      },
    );

    test('unused Firebase events rule is absent', () {
      final rules = File('storage.rules').readAsStringSync();
      expect(rules, isNot(contains('match /events/')));
    });

    test('no hardcoded passwords in integration tests', () {
      final dir = Directory('integration_test');
      if (!dir.existsSync()) return;
      final files = dir.listSync(recursive: true).whereType<File>();
      for (final file in files) {
        if (!file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync();
        expect(
          content.contains('Fth.951753'),
          isFalse,
          reason: 'Hardcoded password found in ${file.path}',
        );
        expect(
          content.contains('password123'),
          isFalse,
          reason: 'Test password found in ${file.path}',
        );
      }
    });

    test('chat moderation is active', () {
      final svc = ChatModerationService.instance;
      // Verify moderation catches critical content
      expect(svc.isSafe('bring dich um'), isFalse);
      expect(svc.isSafe('Hallo zusammen'), isTrue);
    });

    test('rate limiter has reasonable limit', () {
      expect(AIRateLimiter.dailyLimit, greaterThanOrEqualTo(10));
      expect(AIRateLimiter.dailyLimit, lessThanOrEqualTo(100));
    });
  });
}
