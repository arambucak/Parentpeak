import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Web-sichere Bildanzeige.
///
/// - http(s)-URLs → Image.network (funktioniert überall)
/// - Lokale Pfade auf Web (blob:) → Image.network (Web nutzt blob-URLs)
/// - Lokale Pfade auf Mobile → Image.file
///
/// Verhindert den dart:io File-Crash auf Flutter Web.
class SafeImage extends StatelessWidget {
  const SafeImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  bool get _isNetwork =>
      path.startsWith('http://') || path.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final Widget fallback = errorWidget ??
        Container(
          width: width,
          height: height,
          color: const Color(0xFFE8EDF3),
          child: const Icon(Icons.image_not_supported_rounded,
              color: Color(0xFF9AA7B5), size: 32),
        );

    // Auf Web: alles über Image.network (blob-URLs + echte URLs)
    if (kIsWeb || _isNetwork) {
      return Image.network(
        path,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    // Mobile: lokale Datei
    return Image.file(
      File(path),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

/// Zeigt ein frisch gewähltes XFile (aus image_picker) web-sicher an.
class SafeXFileImage extends StatelessWidget {
  const SafeXFileImage({
    super.key,
    required this.file,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final XFile file;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Auf Web: XFile.path ist eine blob-URL → Image.network
      return Image.network(
        file.path,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return Image.file(
      File(file.path),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() => Container(
        width: width,
        height: height,
        color: const Color(0xFFE8EDF3),
        child: const Icon(Icons.broken_image_rounded,
            color: Color(0xFF9AA7B5), size: 32),
      );
}
