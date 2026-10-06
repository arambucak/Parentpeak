import 'package:parentpeak/logic/family_hub_store.dart';

/// Ein Einkaufslisten-Item mit Menge, Kategorie und Lerneffekt.
class ShoppingItem {
  final String id;
  final String name;
  final String? quantity; // "3x", "500g", "1L", null = keine Angabe
  final String emoji; // Kategorie-Emoji (auto-erkannt)
  final bool isDone;
  final DateTime createdAt;
  final DateTime? doneAt;

  const ShoppingItem({
    required this.id,
    required this.name,
    this.quantity,
    this.emoji = '\u{1F6D2}',
    this.isDone = false,
    required this.createdAt,
    this.doneAt,
  });

  ShoppingItem copyWith({
    bool? isDone,
    DateTime? doneAt,
    bool clearDoneAt = false,
  }) => ShoppingItem(
    id: id,
    name: name,
    quantity: quantity,
    emoji: emoji,
    isDone: isDone ?? this.isDone,
    createdAt: createdAt,
    doneAt: clearDoneAt ? null : doneAt ?? this.doneAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'emoji': emoji,
    'isDone': isDone,
    'createdAt': createdAt.toIso8601String(),
    'doneAt': doneAt?.toIso8601String(),
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> j) {
    if (j['name'] is! String) {
      throw const FormatException('Invalid shopping name');
    }
    for (final key in ['createdAt', 'doneAt']) {
      final value = j[key];
      if (value != null &&
          (value is! String || DateTime.tryParse(value) == null)) {
        throw FormatException('Invalid shopping date: $key');
      }
    }
    return ShoppingItem(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      quantity: j['quantity'] as String?,
      emoji: j['emoji'] as String? ?? '\u{1F6D2}',
      isDone: j['isDone'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      doneAt: j['doneAt'] != null
          ? DateTime.tryParse(j['doneAt'] as String)
          : null,
    );
  }

  static int _idCounter = 0;

  /// Parst Eingabe wie "3x Milch", "Milch 500g", "2 Butter" in Name + Menge.
  static ShoppingItem fromInput(String input) {
    final trimmed = input.trim();
    String name = trimmed;
    String? quantity;

    // Pattern: "3x Milch" oder "3 x Milch"
    final prefixMatch = RegExp(r'^(\d+)\s*[xX×]\s*(.+)$').firstMatch(trimmed);
    if (prefixMatch != null) {
      quantity = '${prefixMatch.group(1)}x';
      name = prefixMatch.group(2)!.trim();
    } else {
      // Pattern: "Milch 3x" oder "Nudeln 500g" oder "2 Butter"
      final suffixMatch = RegExp(
        r'^(.+?)\s+(\d+\s*(?:x|X|×|g|kg|ml|l|L|St|Stk|Pkg|Pckg)\.?)$',
      ).firstMatch(trimmed);
      if (suffixMatch != null) {
        name = suffixMatch.group(1)!.trim();
        quantity = suffixMatch.group(2)!.trim();
      } else {
        // Pattern: "2 Butter" (Zahl am Anfang ohne x)
        final numMatch = RegExp(r'^(\d+)\s+(.+)$').firstMatch(trimmed);
        if (numMatch != null) {
          quantity = '${numMatch.group(1)}x';
          name = numMatch.group(2)!.trim();
        }
      }
    }

    _idCounter++;
    return ShoppingItem(
      id: 'shop_${DateTime.now().millisecondsSinceEpoch}_$_idCounter',
      name: name,
      quantity: quantity,
      emoji: _guessEmoji(name),
      createdAt: DateTime.now(),
    );
  }

  static String _guessEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('milch') ||
        lower.contains('joghurt') ||
        lower.contains('kaese') ||
        lower.contains('butter') ||
        lower.contains('sahne') ||
        lower.contains('quark')) {
      return '\u{1F95B}';
    }
    if (lower.contains('brot') ||
        lower.contains('broetchen') ||
        lower.contains('toast')) {
      return '\u{1F35E}';
    }
    if (lower.contains('obst') ||
        lower.contains('apfel') ||
        lower.contains('banane') ||
        lower.contains('erdbeere') ||
        lower.contains('orange')) {
      return '\u{1F34E}';
    }
    if (lower.contains('gemuese') ||
        lower.contains('karotte') ||
        lower.contains('brokkoli') ||
        lower.contains('tomate') ||
        lower.contains('salat') ||
        lower.contains('gurke')) {
      return '\u{1F966}';
    }
    if (lower.contains('fleisch') ||
        lower.contains('wurst') ||
        lower.contains('schinken') ||
        lower.contains('hack')) {
      return '\u{1F356}';
    }
    if (lower.contains('nudel') ||
        lower.contains('reis') ||
        lower.contains('mehl') ||
        lower.contains('pasta')) {
      return '\u{1F35D}';
    }
    if (lower.contains('wasser') ||
        lower.contains('saft') ||
        lower.contains('cola') ||
        lower.contains('limo')) {
      return '\u{1F4A7}';
    }
    if (lower.contains('windel') ||
        lower.contains('feuchttuch') ||
        lower.contains('creme')) {
      return '\u{1F476}';
    }
    if (lower.contains('wasch') ||
        lower.contains('spuel') ||
        lower.contains('seife') ||
        lower.contains('shampoo')) {
      return '\u{1F9F4}';
    }
    if (lower.contains('toiletten') ||
        lower.contains('küchen') ||
        lower.contains('papier')) {
      return '\u{1F9FB}';
    }
    return '\u{1F6D2}';
  }
}

/// Persistenz-Service für die Einkaufsliste.
class ShoppingListService {
  static final ShoppingListService instance = ShoppingListService();
  ShoppingListService({FamilyHubStore? store})
    : _store = store ?? FamilyHubStore.instance;
  final FamilyHubStore _store;
  String? _loadedScope;
  int _loadRevision = 0;

  static const _activeKey = 'shopping.active';
  static const _doneKey = 'shopping.done';
  static const _frequentKey = 'shopping.frequent';

  List<ShoppingItem> _active = [];
  List<ShoppingItem> _done = [];
  List<String> _frequent = [];

  void _clearIfChanged() {
    if (_loadedScope == _store.scope) return;
    _active = [];
    _done = [];
    _frequent = [];
  }

  String _requireLoaded() {
    final scope = _loadedScope;
    if (scope == null) throw StateError('Load account shopping before editing');
    _store.requireScope(scope);
    return scope;
  }

  List<ShoppingItem> get activeItems {
    _clearIfChanged();
    return List.unmodifiable(_active);
  }

  List<ShoppingItem> get doneItems {
    _clearIfChanged();
    return List.unmodifiable(_done);
  }

  List<String> get frequentItems {
    _clearIfChanged();
    return List.unmodifiable(_frequent);
  }

  Future<void> load() async {
    final scope = _store.scope;
    final revision = ++_loadRevision;
    _active = [];
    _done = [];
    _frequent = [];
    _loadedScope = null;
    final data = await _store.read(expectedScope: scope);
    final active = _loadList(data, _activeKey);
    final done = _loadList(data, _doneKey);
    final frequent = List<String>.from(data[_frequentKey] as List? ?? []);
    _store.requireScope(scope);
    if (revision != _loadRevision) throw const FamilyHubAccountChanged();
    _active = active;
    _done = done;
    _frequent = frequent;
    _loadedScope = scope;
    // Erledigt-Items aelter als 7 Tage entfernen
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    _done.removeWhere(
      (item) => item.doneAt != null && item.doneAt!.isBefore(cutoff),
    );
  }

  Future<void> addItem(ShoppingItem item) => _mutate((active, done, frequent) {
    active.insert(0, item);
    _trackFrequent(frequent, item.name);
  });

  Future<void> addItemsFromRecipe(List<String> ingredients) =>
      _mutate((active, done, frequent) {
        for (final ing in ingredients) {
          // Duplikat-Check: nicht hinzufuegen wenn Name schon auf der Liste
          final parsed = ShoppingItem.fromInput(ing);
          final alreadyExists = active.any(
            (a) =>
                a.name.toLowerCase().trim() == parsed.name.toLowerCase().trim(),
          );
          if (!alreadyExists) {
            active.insert(0, parsed);
            _trackFrequent(frequent, parsed.name);
          }
        }
      });

  /// Prueft ob ein Item (nach Name) schon auf der aktiven Liste steht.
  bool isAlreadyOnList(String name) {
    final lower = name.toLowerCase().trim();
    return activeItems.any((a) => a.name.toLowerCase().trim() == lower);
  }

  /// Basis-Zutaten die fast jeder zuhause hat.
  static const Set<String> basicPantryItems = {
    'salz',
    'pfeffer',
    'zucker',
    'mehl',
    'olivenoel',
    'oel',
    'essig',
    'senf',
    'ketchup',
    'sojasauce',
    'backpulver',
    'vanillezucker',
    'zimt',
    'paprikapulver',
    'knoblauch',
  };

  /// Prueft ob eine Zutat eine Basis-Zutat ist (die man nicht kaufen muss).
  static bool isBasicItem(String ingredient) {
    final lower = ingredient
        .toLowerCase()
        .replaceAll(RegExp(r'\d+\s*(g|ml|l|el|tl|prise|stueck|stk)\s*'), '')
        .trim();
    return basicPantryItems.any((b) => lower.contains(b));
  }

  Future<void> toggleDone(String id) => _mutate((active, done, frequent) {
    final idx = active.indexWhere((i) => i.id == id);
    if (idx != -1) {
      final item = active.removeAt(idx);
      done.insert(0, item.copyWith(isDone: true, doneAt: DateTime.now()));
    } else {
      final dIdx = done.indexWhere((i) => i.id == id);
      if (dIdx != -1) {
        final item = done.removeAt(dIdx);
        active.insert(0, item.copyWith(isDone: false, clearDoneAt: true));
      } else {
        throw StateError('Unknown shopping item');
      }
    }
  });

  Future<void> removeItem(String id) => _mutate((active, done, frequent) {
    if (!active.any((i) => i.id == id) && !done.any((i) => i.id == id)) {
      throw StateError('Unknown shopping item');
    }
    active.removeWhere((i) => i.id == id);
    done.removeWhere((i) => i.id == id);
  });

  void _trackFrequent(List<String> frequent, String name) {
    final lower = name.toLowerCase().trim();
    if (!frequent.contains(lower)) {
      frequent.insert(0, lower);
      if (frequent.length > 20) frequent.removeRange(20, frequent.length);
    }
  }

  Future<void> _mutate(
    void Function(List<ShoppingItem>, List<ShoppingItem>, List<String>) mutate,
  ) async {
    final scope = _requireLoaded();
    final data = await _store.update((data) {
      final active = _loadList(data, _activeKey);
      final done = _loadList(data, _doneKey);
      final frequent = List<String>.from(data[_frequentKey] as List? ?? []);
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      done.removeWhere(
        (item) => item.doneAt != null && item.doneAt!.isBefore(cutoff),
      );
      mutate(active, done, frequent);
      data[_activeKey] = active.map((i) => i.toJson()).toList();
      data[_doneKey] = done.map((i) => i.toJson()).toList();
      data[_frequentKey] = frequent;
      return data;
    }, expectedScope: scope);
    _store.requireScope(scope);
    _active = _loadList(data, _activeKey);
    _done = _loadList(data, _doneKey);
    _frequent = List<String>.from(data[_frequentKey] as List? ?? []);
  }

  List<ShoppingItem> _loadList(Map<String, dynamic> data, String key) {
    return (data[key] as List? ?? [])
        .map((e) => ShoppingItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
