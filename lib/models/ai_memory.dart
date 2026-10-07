/// Datenmodelle für das optionale KI-Gedächtnis der Elternberatung.
///
/// Das Gedächtnis ist standardmäßig AUS (opt-in) und speichert nur, was Eltern
/// bewusst bestätigt haben. Die Daten liegen im Backend und werden serverseitig
/// — nur bei aktiviertem Gedächtnis — in den KI-Prompt eingespeist.
class AiMemorySettings {
  const AiMemorySettings({required this.enabled});
  final bool enabled;
  factory AiMemorySettings.fromJson(Map<String, dynamic> json) {
    return AiMemorySettings(
      enabled: json['enabled'] == true &&
          json['consentVersion'] == 'chat-memory-v1',
    );
  }
}

class AiMemoryItem {
  const AiMemoryItem({
    required this.id,
    required this.childId,
    required this.category,
    required this.key,
    required this.value,
    required this.status,
    this.userConfirmedAt,
  });
  final String id;
  final String childId;
  final String category;
  final String key;
  final String value;
  final String status;
  final DateTime? userConfirmedAt;
  factory AiMemoryItem.fromJson(Map<String, dynamic> json) {
    return AiMemoryItem(
      id: '${json['id'] ?? ''}',
      childId: '${json['childId'] ?? ''}',
      category: '${json['category'] ?? ''}',
      key: '${json['key'] ?? ''}',
      value: '${json['value'] ?? ''}',
      status: '${json['status'] ?? 'confirmed'}',
      userConfirmedAt: DateTime.tryParse('${json['userConfirmedAt'] ?? ''}'),
    );
  }
}

class AiChildProfile {
  const AiChildProfile({
    required this.id,
    required this.userId,
    required this.name,
    this.birthDate,
    this.gender,
    this.memoryItems = const [],
  });
  final String id;
  final String userId;
  final String name;
  final DateTime? birthDate;
  final String? gender;
  final List<AiMemoryItem> memoryItems;
  factory AiChildProfile.fromJson(Map<String, dynamic> json) {
    final rawItems = json['memoryItems'];
    return AiChildProfile(
      id: '${json['id'] ?? ''}',
      userId: '${json['userId'] ?? ''}',
      name: '${json['name'] ?? ''}',
      birthDate: DateTime.tryParse('${json['birthDate'] ?? ''}'),
      gender: json['gender']?.toString(),
      memoryItems: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((item) => AiMemoryItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
          : const [],
    );
  }
}
