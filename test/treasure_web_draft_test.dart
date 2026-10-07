import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parentpeak/logic/treasure_account_store.dart';
import 'package:parentpeak/logic/treasure_draft_images.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'durable web photo storage creates readable files again after reopening preferences',
    () async {
      SharedPreferences.setMockInitialValues({});
      const codec = TreasureDraftImages(web: true);
      final expected = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);
      final photo = XFile.fromData(
        expected,
        name: 'draft.png',
        mimeType: 'image/png',
      );
      final store = TreasureAccountStore(userIdProvider: () => 'web-a');
      final encoded = await codec.encode([photo]);
      await store.update(
        (data) => data[TreasureAccountStore.draftKey] = encoded,
        expectedScope: store.scope,
      );
      await (await SharedPreferences.getInstance()).reload();
      final reopened = TreasureAccountStore(userIdProvider: () => 'web-a');
      final draft =
          (await reopened.read(
                expectedScope: reopened.scope,
              ))[TreasureAccountStore.draftKey]
              as Map<String, dynamic>;
      final restored = codec.decode(draft)!.single;
      expect(await restored.readAsBytes(), expected);
      expect(restored.mimeType, 'image/png');
      expect(draft.containsKey('imagePaths'), isFalse);
      final other = TreasureAccountStore(userIdProvider: () => 'web-b');
      expect(await other.read(expectedScope: other.scope), isEmpty);
    },
  );
}
