import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/user_profile_service.dart';
import 'package:parentpeak/ui/widgets/user_avatar.dart';

void main() {
  test('resolves legacy relative avatar paths without changing Firebase URLs', () {
    expect(
      UserProfileService.resolveAvatarUrl(
        '/uploads/avatar.jpg',
        apiBaseUrl: 'https://parentpeak.onrender.com/',
      ),
      'https://parentpeak.onrender.com/uploads/avatar.jpg',
    );
    const firebaseUrl = 'https://firebasestorage.googleapis.com/image?token=abc';
    expect(UserProfileService.resolveAvatarUrl(firebaseUrl), firebaseUrl);
    expect(UserProfileService.resolveAvatarUrl('javascript:alert(1)'), isNull);
  });

  testWidgets('shows initials when avatar image cannot load', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: UserAvatar(
          name: 'Cheeee',
          photoUrl: 'https://example.invalid/missing-avatar.jpg',
        ),
      ),
    ));
    final avatarImage = tester.widget<Image>(find.byType(Image));
    expect(
      (avatarImage.image as NetworkImage).webHtmlElementStrategy,
      WebHtmlElementStrategy.prefer,
    );
    expect(find.text('C'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('C'), findsOneWidget);
  });
}