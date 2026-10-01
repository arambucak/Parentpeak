import 'package:flutter/material.dart';

/// Wiederverwendbarer Avatar: zeigt ein Foto, wenn vorhanden, sonst die
/// Initiale des Namens auf einer stabil aus dem Namen abgeleiteten Farbe.
///
/// Einheitlich für die Chats-Liste, Freundeskarten und Gruppen. Gruppen
/// bekommen ein Gruppen-Icon statt einer Initiale ([isGroup]).
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 24,
    this.isGroup = false,
  });

  final String name;
  final String? photoUrl;
  final double radius;
  final bool isGroup;

  static const List<Color> _palette = [
    Color(0xFF7C3AED),
    Color(0xFF0EA5E9),
    Color(0xFF059669),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF6366F1),
  ];

  Color get _color {
    if (name.isEmpty) return _palette.first;
    return _palette[name.codeUnitAt(0) % _palette.length];
  }

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;

    if (hasPhoto) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: _color,
        backgroundImage: NetworkImage(photoUrl!.trim()),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: _color,
      child: isGroup
          ? Icon(Icons.groups_rounded, color: Colors.white, size: radius)
          : Text(
              _initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}
