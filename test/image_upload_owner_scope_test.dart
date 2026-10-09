import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentpeak/services/image_upload_service.dart';

class _Storage extends Mock implements FirebaseStorage {}

class _Reference extends Mock implements Reference {}

class _Snapshot extends Mock implements TaskSnapshot {}

class _UploadTask extends Fake implements UploadTask {
  @override
  Future<T> then<T>(
    FutureOr<T> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) => Future<TaskSnapshot>.value(_Snapshot()).then(onValue, onError: onError);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? uid;
  late _Storage storage;
  late _Reference root;
  late _Reference object;
  late ImageUploadService service;
  late List<String> paths;
  final file = XFile.fromData(
    Uint8List.fromList([1, 2]),
    name: 'photo.jpg',
    path: 'photo.jpg',
  );
  const url = 'https://example.invalid/own-photo';

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(SettableMetadata());
  });
  setUp(() {
    uid = 'owner-a';
    storage = _Storage();
    root = _Reference();
    object = _Reference();
    paths = [];
    when(() => storage.ref()).thenReturn(root);
    when(() => root.child(any())).thenAnswer((invocation) {
      paths.add(invocation.positionalArguments.single as String);
      return object;
    });
    when(() => object.putData(any(), any())).thenAnswer((_) => _UploadTask());
    when(() => object.getDownloadURL()).thenAnswer((_) async => url);
    when(() => object.delete()).thenAnswer((_) async {});
    when(() => storage.refFromURL(url)).thenReturn(object);
    when(() => object.fullPath).thenAnswer((_) => paths.single);
    service = ImageUploadService(storage: storage, userIdProvider: () => uid);
  });

  test(
    'default treasure upload uses exact UID folder and filename shape',
    () async {
      expect(await service.uploadImages([file]), [url]);
      expect(paths.single, matches(r'^treasures/owner-a/[0-9]+_photo\.jpg$'));
      verify(() => object.putData(any(), any())).called(1);
    },
  );

  test(
    'missing Firebase session refuses upload without touching Storage',
    () async {
      uid = null;
      await expectLater(
        service.uploadImages([file]),
        throwsA(isA<ImageBatchUploadException>()),
      );
      expect(paths, isEmpty);
      verifyNever(() => storage.ref());
    },
  );

  test('explicit foreign UID folder is refused', () async {
    await expectLater(
      service.uploadImages([file], folder: 'treasures/owner-b'),
      throwsA(isA<ImageBatchUploadException>()),
    );
    verifyNever(() => storage.ref());
  });

  test('profile upload retains its existing UID path', () async {
    expect(await service.uploadImage(file, folder: 'profiles/owner-a'), url);
    expect(paths.single, matches(r'^profiles/owner-a/[0-9]+_photo\.jpg$'));
  });

  test(
    'failed URL acquisition deletes only the uploaded own reference',
    () async {
      when(
        () => object.getDownloadURL(),
      ).thenThrow(StateError('URL unavailable'));
      await expectLater(
        service.uploadImages([file]),
        throwsA(
          isA<ImageBatchUploadException>().having(
            (e) => e.remainingUploads,
            'remaining',
            0,
          ),
        ),
      );
      expect(paths.single, startsWith('treasures/owner-a/'));
      verify(() => object.delete()).called(1);
      verifyNever(() => storage.refFromURL(any()));
    },
  );

  test('batch failure removes successful own object via its URL', () async {
    var requests = 0;
    when(() => object.putData(any(), any())).thenAnswer((_) {
      if (++requests == 2) throw StateError('second upload failed');
      return _UploadTask();
    });
    when(() => object.fullPath).thenAnswer((_) => paths.first);
    await expectLater(
      service.uploadImages([file, file]),
      throwsA(
        isA<ImageBatchUploadException>().having(
          (e) => e.remainingUploads,
          'remaining',
          0,
        ),
      ),
    );
    expect(
      paths.every((path) => path.startsWith('treasures/owner-a/')),
      isTrue,
    );
    verify(() => storage.refFromURL(url)).called(1);
    verify(() => object.delete()).called(2);
  });

  test(
    'changed Firebase UID stops batch and does not delete as new owner',
    () async {
      when(() => object.getDownloadURL()).thenAnswer((_) async {
        uid = 'owner-b';
        return url;
      });
      await expectLater(
        service.uploadImages([file, file]),
        throwsA(
          isA<ImageBatchUploadException>().having(
            (e) => e.remainingUploads,
            'remaining',
            1,
          ),
        ),
      );
      expect(paths, hasLength(1));
      verifyNever(() => object.delete());
    },
  );

  test('cleanup refuses a URL resolved to a foreign object', () async {
    var requests = 0;
    when(() => object.putData(any(), any())).thenAnswer((_) {
      if (++requests == 2) throw StateError('second upload failed');
      return _UploadTask();
    });
    when(() => object.fullPath).thenReturn('treasures/owner-b/foreign.jpg');
    await expectLater(
      service.uploadImages([file, file]),
      throwsA(
        isA<ImageBatchUploadException>().having(
          (e) => e.remainingUploads,
          'remaining',
          1,
        ),
      ),
    );
    // Only the second upload's own reference is cleaned; not the foreign URL.
    verify(() => object.delete()).called(1);
  });
}
