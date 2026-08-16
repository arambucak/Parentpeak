import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Uploads images to Firebase Storage and returns the download URL.
class ImageUploadService {
  static final ImageUploadService instance = ImageUploadService._();
  ImageUploadService._();

  final _storage = FirebaseStorage.instance;

  /// Upload an XFile (from image_picker) to Firebase Storage.
  /// Returns the public download URL or null on failure.
  Future<String?> uploadImage(XFile file, {String folder = 'treasures'}) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = _storage.ref().child('$folder/$fileName');

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        uploadTask = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        uploadTask = ref.putFile(File(file.path));
      }

      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      debugPrint('ImageUploadService: uploaded → $url');
      return url;
    } catch (e) {
      debugPrint('ImageUploadService: upload failed: $e');
      return null;
    }
  }

  /// Upload multiple images, returns list of URLs (skips failures).
  Future<List<String>> uploadImages(List<XFile> files,
      {String folder = 'treasures'}) async {
    final urls = <String>[];
    for (final file in files) {
      final url = await uploadImage(file, folder: folder);
      if (url != null) urls.add(url);
    }
    return urls;
  }
}
