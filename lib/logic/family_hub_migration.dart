import 'package:parentpeak/logic/family_hub_store.dart';
import 'package:parentpeak/models/kind_dossier.dart';
import 'package:parentpeak/models/shopping_item.dart';

Future<void> claimFamilyHubLegacy({
  required String expectedScope,
  FamilyHubStore? store,
}) =>
    (store ?? FamilyHubStore.instance).claimLegacy(
      expectedScope: expectedScope,
      normalize: (legacy) {
        final result = <String, dynamic>{};
        for (final entry in legacy.entries) {
          if (entry.value is! List) {
            throw const FormatException('Invalid legacy family hub list');
          }
          final list = entry.value as List;
          result[entry.key] = switch (entry.key) {
            FamilyHubStore.dossierKey => list.map((item) {
                if (item is! Map<String, dynamic> ||
                    item['childName'] is! String) {
                  throw const FormatException('Invalid legacy child dossier');
                }
                return KindDossier.fromJson(item).toJson();
              }).toList(),
            FamilyHubStore.activeKey || FamilyHubStore.doneKey =>
              list.map((item) {
                if (item is! Map<String, dynamic> || item['name'] is! String) {
                  throw const FormatException('Invalid legacy shopping item');
                }
                return ShoppingItem.fromJson(item).toJson();
              }).toList(),
            FamilyHubStore.todoKey => list.asMap().entries.map((entry) {
                final item = entry.value;
                if (item is! Map<String, dynamic> ||
                    item['text'] is! String ||
                    (item['done'] != null && item['done'] is! bool)) {
                  throw const FormatException('Invalid legacy todo');
                }
                return Map<String, dynamic>.from(item)
                  ..putIfAbsent('id', () => 'legacy_todo_${entry.key}');
              }).toList(),
            _ => List<String>.from(list),
          };
        }
        return result;
      },
    );
