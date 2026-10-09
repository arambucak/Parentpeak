import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ImageBatchUploadException implements Exception {
  const ImageBatchUploadException({
    required this.remainingUploads,
    required this.cause,
  });
  final int remainingUploads;
  final Object cause;
}

/// Uploads images to Firebase Storage and returns the download URL.
class ImageUploadService {
  static final ImageUploadService instance = ImageUploadService._();
  ImageUploadService._()
      : _upload = null,
        _remove = null,
        _storage = null,
        _userIdProvider = (() => FirebaseAuth.instance.currentUser?.uid);

  ImageUploadService({
    Future<String> Function(XFile file, String folder)? upload,
    Future<void> Function(String url)? remove,
    FirebaseStorage? storage,
    String? Function()? userIdProvider,
  }) : _upload = upload,
       _remove = remove,
       _storage = storage,
       _userIdProvider = userIdProvider ??
           (() => FirebaseAuth.instance.currentUser?.uid);

  final Future<String> Function(XFile file, String folder)? _upload;
  final Future<void> Function(String url)? _remove;
  final FirebaseStorage? _storage;
  final String? Function() _userIdProvider;

  String _resolveFolder(String folder) {
    if (folder != 'treasures' && !folder.startsWith('treasures/')) return folder;
    final uid = _userIdProvider();
    if (uid == null || uid.trim().isEmpty || uid.contains('/')) {
      throw StateError('Sign in to upload treasure photos');
    }
    final ownedFolder = 'treasures/$uid';
    if (folder != 'treasures' && folder != ownedFolder) {
      throw StateError('Cannot upload treasure photos for another account');
    }
    return ownedFolder;
  }

  void _requireFolder(String folder) {
    if (folder.startsWith('treasures/')) _resolveFolder(folder);
  }

  static String? contentTypeFor(String fileName) {
    switch (fileName.toLowerCase().split('.').last) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'avif':
        return 'image/avif';
      case 'bmp':
        return 'image/bmp';
      case 'tif':
      case 'tiff':
        return 'image/tiff';
      default:
        return null;
    }
  }

  /// Upload an XFile (from image_picker) to Firebase Storage.
  /// Returns the public download URL or null on failure.
  Future<String?> uploadImage(XFile file, {String folder = 'treasures'}) async {
    try {
      return await _uploadStrict(file, folder);
    } catch (e) {
      debugPrint('ImageUploadService: upload failed: $e');
      return null;
    }
  }

  Future<String> _uploadStrict(XFile file, String folder) async {
    folder = _resolveFolder(folder);
    final upload = _upload;
    if (upload != null) return upload(file, folder);
    final contentType = file.mimeType ?? contentTypeFor(file.name);
    if ((kIsWeb && contentType == null) ||
        (contentType != null && !contentType.startsWith('image/'))) {
      throw StateError('Unsupported image type');
    }
    final bytes = await file.readAsBytes();
    _requireFolder(folder);
    if (file.name.isEmpty || file.name.contains('/') || file.name.contains(r'\')) {
      throw StateError('Invalid image file name');
    }
    final ref = (_storage ?? FirebaseStorage.instance).ref().child(
      '$folder/${DateTime.now().microsecondsSinceEpoch}_${file.name}',
    );
    try {
      await ref.putData(bytes, SettableMetadata(contentType: contentType));
      _requireFolder(folder);
      final url = await ref.getDownloadURL();
      _requireFolder(folder);
      return url;
    } catch (error) {
      try {
        _requireFolder(folder);
        await ref.delete();
      } catch (cleanupError) {
        if (cleanupError is! FirebaseException ||
            cleanupError.code != 'object-not-found') {
          debugPrint(
            'ImageUploadService: failed upload cleanup failed: $cleanupError',
          );
          throw ImageBatchUploadException(remainingUploads: 1, cause: error);
        }
      }
      rethrow;
    }
  }

  Future<void> _delete(String url, String folder) async {
    _requireFolder(folder);
    final remove = _remove;
    if (remove != null) return remove(url);
    final ref = (_storage ?? FirebaseStorage.instance).refFromURL(url);
    if (!ref.fullPath.startsWith('$folder/')) {
      throw StateError('Cleanup object does not belong to the upload folder');
    }
    await ref.delete();
  }

  /// A failed batch never returns a partial success. Cleanup is best-effort and reported.
  Future<List<String>> uploadImages(
    List<XFile> files, {
    String folder = 'treasures',
    void Function()? requireCurrent,
  }) async {
    final urls = <String>[];
    try {
      folder = _resolveFolder(folder);
      for (final file in files) {
        requireCurrent?.call();
        _requireFolder(folder);
        urls.add(await _uploadStrict(file, folder));
        _requireFolder(folder);
        requireCurrent?.call();
      }
      return urls;
    } catch (error) {
      var remaining = error is ImageBatchUploadException
          ? error.remainingUploads
          : 0;
      for (final url in urls) {
        try {
          await _delete(url, folder);
        } catch (cleanupError) {
          remaining++;
          debugPrint('ImageUploadService: cleanup failed: $cleanupError');
        }
      }
      debugPrint('ImageUploadService: batch failed: $error');
      throw ImageBatchUploadException(
        remainingUploads: remaining,
        cause: error,
      );
    }
  }
}
