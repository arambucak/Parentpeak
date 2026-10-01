import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/services/image_upload_service.dart';

void main() {
  test('web image uploads retain their image content type', () {
    expect(ImageUploadService.contentTypeFor('logo.png'), 'image/png');
    expect(ImageUploadService.contentTypeFor('portrait.JPG'), 'image/jpeg');
    expect(ImageUploadService.contentTypeFor('avatar.webp'), 'image/webp');
    expect(ImageUploadService.contentTypeFor('document.pdf'), isNull);
  });
}