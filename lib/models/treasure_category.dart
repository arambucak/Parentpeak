class TreasureCategory {
  static const ids = ['vehicles', 'clothing', 'toys', 'books', 'equipment', 'other'];

  static String normalize(String value) {
    final key = value.trim().toLowerCase();
    if (ids.contains(key)) return key;
    const legacy = {
      'fahrzeuge': 'vehicles', 'wesayît': 'vehicles', 'araçlar': 'vehicles',
      'kleidung': 'clothing', 'cil': 'clothing', 'giysiler': 'clothing',
      'spielzeug': 'toys', 'lîstok': 'toys', 'oyuncaklar': 'toys',
      'bücher': 'books', 'buecher': 'books', 'pirtûk': 'books', 'kitaplar': 'books',
      'ausstattung': 'equipment', 'amûr': 'equipment', 'ekipman': 'equipment',
    };
    return legacy[key] ?? 'other';
  }
}
