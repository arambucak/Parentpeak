import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

  ShoppingItem copyWith({bool? isDone, DateTime? doneAt}) => ShoppingItem(
        id: id,
        name: name,
        quantity: quantity,
        emoji: emoji,
        isDone: isDone ?? this.isDone,
        createdAt: createdAt,
        doneAt: doneAt ?? this.doneAt,
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

  factory ShoppingItem.fromJson(Map<String, dynamic> j) => ShoppingItem(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        quantity: j['quantity'] as String?,
        emoji: j['emoji'] as String? ?? '\u{1F6D2}',
        isDone: j['isDone'] as bool? ?? false,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
        doneAt: j['doneAt'] != null
            ? DateTime.tryParse(j['doneAt'] as String)
            : null,
      );

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
      final suffixMatch =
          RegExp(r'^(.+?)\s+(\d+\s*(?:x|X|×|g|kg|ml|l|L|St|Stk|Pkg|Pckg)\.?)$')
              .firstMatch(trimmed);
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
        lower.contains('quark')) return '\u{1F95B}';
    if (lower.contains('brot') ||
        lower.contains('broetchen') ||
        lower.contains('toast')) return '\u{1F35E}';
    if (lower.contains('obst') ||
        lower.contains('apfel') ||
        lower.contains('banane') ||
        lower.contains('erdbeere') ||
        lower.contains('orange')) return '\u{1F34E}';
    if (lower.contains('gemuese') ||
        lower.contains('karotte') ||
        lower.contains('brokkoli') ||
        lower.contains('tomate') ||
        lower.contains('salat') ||
        lower.contains('gurke')) return '\u{1F966}';
    if (lower.contains('fleisch') ||
        lower.contains('wurst') ||
        lower.contains('schinken') ||
        lower.contains('hack')) return '\u{1F356}';
    if (lower.contains('nudel') ||
        lower.contains('reis') ||
        lower.contains('mehl') ||
        lower.contains('pasta')) return '\u{1F35D}';
    if (lower.contains('wasser') ||
        lower.contains('saft') ||
        lower.contains('cola') ||
        lower.contains('limo')) return '\u{1F4A7}';
    if (lower.contains('windel') ||
        lower.contains('feuchttuch') ||
        lower.contains('creme')) return '\u{1F476}';
    if (lower.contains('wasch') ||
        lower.contains('spuel') ||
        lower.contains('seife') ||
        lower.contains('shampoo')) return '\u{1F9F4}';
    if (lower.contains('toiletten') ||
        lower.contains('küchen') ||
        lower.contains('papier')) return '\u{1F9FB}';
    return '\u{1F6D2}';
  }
}

/// Persistenz-Service für die Einkaufsliste.
class ShoppingListService {
  static final ShoppingListService instance = ShoppingListService._();
  ShoppingListService._();

  static const _activeKey = 'shopping.active';
  static const _doneKey = 'shopping.done';
  static const _frequentKey = 'shopping.frequent';

  List<ShoppingItem> _active = [];
  List<ShoppingItem> _done = [];
  List<String> _frequent = [];

  List<ShoppingItem> get activeItems => List.unmodifiable(_active);
  List<ShoppingItem> get doneItems => List.unmodifiable(_done);
  List<String> get frequentItems => List.unmodifiable(_frequent);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _active = _loadList(prefs, _activeKey);
    _done = _loadList(prefs, _doneKey);
    _frequent = prefs.getStringList(_frequentKey) ?? [];
    // Erledigt-Items aelter als 7 Tage entfernen
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    _done.removeWhere(
        (item) => item.doneAt != null && item.doneAt!.isBefore(cutoff));
  }

  Future<void> addItem(ShoppingItem item) async {
    _active.insert(0, item);
    _trackFrequent(item.name);
    await _persist();
  }

  Future<void> addItemsFromRecipe(List<String> ingredients) async {
    for (final ing in ingredients) {
      // Duplikat-Check: nicht hinzufuegen wenn Name schon auf der Liste
      final parsed = ShoppingItem.fromInput(ing);
      final alreadyExists = _active.any((a) =>
          a.name.toLowerCase().trim() == parsed.name.toLowerCase().trim());
      if (!alreadyExists) {
        _active.insert(0, parsed);
        _trackFrequent(parsed.name);
      }
    }
    await _persist();
  }

  /// Prueft ob ein Item (nach Name) schon auf der aktiven Liste steht.
  bool isAlreadyOnList(String name) {
    final lower = name.toLowerCase().trim();
    return _active.any((a) => a.name.toLowerCase().trim() == lower);
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

  Future<void> toggleDone(String id) async {
    final idx = _active.indexWhere((i) => i.id == id);
    if (idx != -1) {
      final item = _active.removeAt(idx);
      _done.insert(0, item.copyWith(isDone: true, doneAt: DateTime.now()));
    } else {
      final dIdx = _done.indexWhere((i) => i.id == id);
      if (dIdx != -1) {
        final item = _done.removeAt(dIdx);
        _active.insert(0, item.copyWith(isDone: false));
      }
    }
    await _persist();
  }

  Future<void> removeItem(String id) async {
    _active.removeWhere((i) => i.id == id);
    _done.removeWhere((i) => i.id == id);
    await _persist();
  }

  void _trackFrequent(String name) {
    final lower = name.toLowerCase().trim();
    if (!_frequent.contains(lower)) {
      _frequent.insert(0, lower);
      if (_frequent.length > 20) _frequent = _frequent.take(20).toList();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _activeKey, jsonEncode(_active.map((i) => i.toJson()).toList()));
    await prefs.setString(
        _doneKey, jsonEncode(_done.map((i) => i.toJson()).toList()));
    await prefs.setStringList(_frequentKey, _frequent);
  }

  List<ShoppingItem> _loadList(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => ShoppingItem.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
