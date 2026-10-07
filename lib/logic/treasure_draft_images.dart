import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class TreasureDraftImages {
  const TreasureDraftImages({this.web = kIsWeb});
  final bool web;

  Future<Map<String, dynamic>> encode(List<XFile> images) async {
    if (!web) {
      return {
        'imagePath': images.firstOrNull?.path,
        'imagePaths': images.map((image) => image.path).toList(),
      };
    }
    final stored = <Map<String, String>>[];
    for (final image in images) {
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) throw const FormatException('Empty draft photo');
      stored.add({
        'name': image.name,
        'mimeType': image.mimeType ?? '',
        'base64': base64Encode(bytes),
      });
    }
    return {'images': stored};
  }

  static void validate(dynamic images) {
    if (images is! List) throw const FormatException('Invalid draft photos');
    for (final image in images) {
      if (image is! Map<String, dynamic> ||
          image['name'] is! String ||
          image['mimeType'] is! String ||
          image['base64'] is! String ||
          base64Decode(image['base64'] as String).isEmpty) {
        throw const FormatException('Invalid stored draft photo');
      }
    }
  }

  List<XFile>? decode(Map<String, dynamic> draft) {
    final images = draft['images'];
    if (images == null) return null;
    validate(images);
    return (images as List).map((item) {
      final image = item as Map<String, dynamic>;
      return XFile.fromData(
        base64Decode(image['base64'] as String),
        name: image['name'] as String,
        mimeType: (image['mimeType'] as String).isEmpty ? null : image['mimeType'] as String,
      );
    }).toList();
  }
}
