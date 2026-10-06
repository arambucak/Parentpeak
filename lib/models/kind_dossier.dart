import 'package:parentpeak/logic/family_hub_store.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';

/// Kind-Dossier — alle wichtigen Infos zu einem Kind an einem Ort.
/// NUR LOKAL gespeichert (sensible Daten verlassen nie das Geraet).
class KindDossier {
  /// Stabile ID eines Dossiers. Entkoppelt die Identität vom (editierbaren)
  /// Kindnamen — so können Kinder umbenannt werden und gleichnamige Kinder
  /// kollidieren nicht mehr. Wird automatisch vergeben, wenn leer übergeben.
  final String id;
  final String childName;
  final DateTime birthDate;
  final String? clothingSize;
  final String? shoeSize;
  final List<String> allergies;
  final String? doctorName;
  final String? doctorPhone;
  final String? bloodType;
  final String? emergencyContact;
  final String? emergencyPhone;
  final String? kitaSchool; // Name der Einrichtung
  final String? kitaGroup; // Gruppe/Klasse
  final String? kitaTeacher; // Erzieherin/Lehrerin
  final List<UExamination> uExams;
  final String? notes;

  KindDossier({
    String? id,
    required this.childName,
    DateTime? birthDate,
    int? ageMonths,
    this.clothingSize,
    this.shoeSize,
    this.allergies = const [],
    this.doctorName,
    this.doctorPhone,
    this.bloodType,
    this.emergencyContact,
    this.emergencyPhone,
    this.kitaSchool,
    this.kitaGroup,
    this.kitaTeacher,
    this.uExams = const [],
    this.notes,
  })  : id = (id == null || id.isEmpty) ? _generateId() : id,
        birthDate = birthDate ?? _birthDateFromAgeMonths(ageMonths ?? 0);

  static int _idCounter = 0;
  static String _generateId() =>
      'kd_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  int get ageMonths => _ageMonthsFromBirthDate(birthDate);
  int get ageYears => (ageMonths / 12).floor();

  KindDossier copyWith({
    String? id,
    String? childName,
    DateTime? birthDate,
    String? clothingSize,
    String? shoeSize,
    List<String>? allergies,
    String? doctorName,
    String? doctorPhone,
    String? bloodType,
    String? emergencyContact,
    String? emergencyPhone,
    String? kitaSchool,
    String? kitaGroup,
    String? kitaTeacher,
    List<UExamination>? uExams,
    String? notes,
  }) =>
      KindDossier(
        id: id ?? this.id,
        childName: childName ?? this.childName,
        birthDate: birthDate ?? this.birthDate,
        clothingSize: clothingSize ?? this.clothingSize,
        shoeSize: shoeSize ?? this.shoeSize,
        allergies: allergies ?? this.allergies,
        doctorName: doctorName ?? this.doctorName,
        doctorPhone: doctorPhone ?? this.doctorPhone,
        bloodType: bloodType ?? this.bloodType,
        emergencyContact: emergencyContact ?? this.emergencyContact,
        emergencyPhone: emergencyPhone ?? this.emergencyPhone,
        kitaSchool: kitaSchool ?? this.kitaSchool,
        kitaGroup: kitaGroup ?? this.kitaGroup,
        kitaTeacher: kitaTeacher ?? this.kitaTeacher,
        uExams: uExams ?? this.uExams,
        notes: notes ?? this.notes,
      );

  static DateTime _birthDateFromAgeMonths(int months) {
    final now = DateTime.now();
    final safeMonths = months.clamp(0, 240);
    return DateTime(now.year, now.month - safeMonths, now.day);
  }

  static int _ageMonthsFromBirthDate(DateTime date) {
    final now = DateTime.now();
    var months = (now.year - date.year) * 12 + now.month - date.month;
    if (now.day < date.day) months--;
    return months.clamp(0, 240);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'childName': childName,
        'ageMonths': ageMonths,
        'birthDate': birthDate.toIso8601String(),
        'clothingSize': clothingSize,
        'shoeSize': shoeSize,
        'allergies': allergies,
        'doctorName': doctorName,
        'doctorPhone': doctorPhone,
        'bloodType': bloodType,
        'emergencyContact': emergencyContact,
        'emergencyPhone': emergencyPhone,
        'kitaSchool': kitaSchool,
        'kitaGroup': kitaGroup,
        'kitaTeacher': kitaTeacher,
        'uExams': uExams.map((u) => u.toJson()).toList(),
        'notes': notes,
      };

  factory KindDossier.fromJson(Map<String, dynamic> j) {
    if (j['childName'] is! String) throw const FormatException('Invalid child name');
    final birthDate = j['birthDate'];
    if (birthDate != null &&
        (birthDate is! String || DateTime.tryParse(birthDate) == null)) {
      throw const FormatException('Invalid child birth date');
    }
    return KindDossier(
        // Alt-Daten ohne 'id' bekommen beim Laden automatisch eine neue ID
        // (Konstruktor-Default) und werden einmalig migriert zurückgeschrieben.
        id: j['id'] as String?,
        childName: j['childName'] as String? ?? '',
        birthDate: DateTime.tryParse(j['birthDate']?.toString() ?? ''),
        ageMonths: (j['ageMonths'] as num?)?.round() ?? 0,
        clothingSize: j['clothingSize'] as String?,
        shoeSize: j['shoeSize'] as String?,
        allergies: List<String>.from(j['allergies'] ?? []),
        doctorName: j['doctorName'] as String?,
        doctorPhone: j['doctorPhone'] as String?,
        bloodType: j['bloodType'] as String?,
        emergencyContact: j['emergencyContact'] as String?,
        emergencyPhone: j['emergencyPhone'] as String?,
        kitaSchool: j['kitaSchool'] as String?,
        kitaGroup: j['kitaGroup'] as String?,
        kitaTeacher: j['kitaTeacher'] as String?,
        uExams: ((j['uExams'] as List?) ?? [])
            .map((e) => UExamination.fromJson(e))
            .toList(),
        notes: j['notes'] as String?,
      );
  }
}

/// U-Untersuchung (Vorsorge) mit automatischer Faelligkeit.
class UExamination {
  final String id; // "u1", "u2", ..., "u9", "j1", "j2"
  final String label; // Rohes (deutsches) Label — nur noch Fallback/Alt-Daten.
  final int dueAtMonths; // Faellig ab diesem Alter (Monate)
  final bool isDone;
  final String? doneDate; // Wann gemacht (ISO-8601, optional)

  const UExamination({
    required this.id,
    this.label = '',
    required this.dueAtMonths,
    this.isDone = false,
    this.doneDate,
  });

  UExamination copyWith({bool? isDone, String? doneDate}) => UExamination(
        id: id,
        label: label,
        dueAtMonths: dueAtMonths,
        isDone: isDone ?? this.isDone,
        // doneDate darf bewusst auf null gesetzt werden (Haken entfernen),
        // daher kein `?? this.doneDate`.
        doneDate: isDone == false ? null : (doneDate ?? this.doneDate),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'dueAtMonths': dueAtMonths,
        'isDone': isDone,
        'doneDate': doneDate,
      };

  factory UExamination.fromJson(Map<String, dynamic> j) => UExamination(
        id: j['id'] as String? ?? '',
        label: j['label'] as String? ?? '',
        dueAtMonths: j['dueAtMonths'] as int? ?? 0,
        isDone: j['isDone'] as bool? ?? false,
        doneDate: j['doneDate'] as String?,
      );
}

/// Deutsche U-Untersuchungen (U-Heft-Schema). Die sichtbaren Labels werden zur
/// Anzeigezeit über [UExaminationData.localizedLabel] in der App-Sprache gebaut
/// (DE/EN/TR/KU), nicht als fester String persistiert.
class UExaminationData {
  /// Erzeugt für ein Kind die vollständige U-Untersuchungs-Liste und übernimmt
  /// den Erledigt-Status aus [existing] (z. B. bereits abgehakte Einträge).
  ///
  /// Hinweis: [ageMonths] wird NICHT zum Filtern verwendet — es werden bewusst
  /// IMMER alle Untersuchungen erzeugt, damit Eltern auch bereits vergangene
  /// Untersuchungen rückwirkend abhaken können. Der Parameter bleibt für
  /// zukünftige alters-/länderspezifische Varianten erhalten.
  static List<UExamination> generateForChild(int ageMonths,
      {List<UExamination> existing = const []}) {
    return _allExams.map((e) {
      final done = existing.where((ex) => ex.id == e.id).firstOrNull;
      return UExamination(
        id: e.id,
        label: e.label,
        dueAtMonths: e.dueAtMonths,
        isDone: done?.isDone ?? false,
        doneDate: done?.doneDate,
      );
    }).toList();
  }

  /// Baut das sichtbare Label einer U-Untersuchung in der aktiven App-Sprache:
  /// die ID bleibt sprachneutral (U1, U7a, J1), das Zeitfenster wird übersetzt.
  /// Fällt auf das rohe [UExamination.label] (bzw. die ID) zurück, wenn kein
  /// l10n-Zeitfenster hinterlegt ist.
  static String localizedLabel(UExamination exam, String languageCode) {
    final displayId = _displayId(exam.id);
    final window =
        AppStringsManager.getString(languageCode, 'uexam_window_${exam.id}');
    // getString gibt bei fehlendem Key den Key selbst zurück.
    if (window == 'uexam_window_${exam.id}') {
      return exam.label.isNotEmpty ? exam.label : displayId;
    }
    return '$displayId — $window';
  }

  /// Sprachneutraler Anzeigename der ID (z. B. 'u7a' -> 'U7a', 'j1' -> 'J1').
  /// Nur der erste Buchstabe wird großgeschrieben, damit Suffixe wie das 'a'
  /// in 'U7a' korrekt klein bleiben.
  static String _displayId(String id) {
    if (id.isEmpty) return id;
    return id[0].toUpperCase() + id.substring(1);
  }

  static const _allExams = [
    UExamination(id: 'u1', label: 'U1 — direkt nach Geburt', dueAtMonths: 0),
    UExamination(id: 'u2', label: 'U2 — 3.-10. Lebenstag', dueAtMonths: 0),
    UExamination(id: 'u3', label: 'U3 — 4.-5. Woche', dueAtMonths: 1),
    UExamination(id: 'u4', label: 'U4 — 3.-4. Monat', dueAtMonths: 3),
    UExamination(id: 'u5', label: 'U5 — 6.-7. Monat', dueAtMonths: 6),
    UExamination(id: 'u6', label: 'U6 — 10.-12. Monat', dueAtMonths: 10),
    UExamination(id: 'u7', label: 'U7 — 21.-24. Monat', dueAtMonths: 21),
    UExamination(id: 'u7a', label: 'U7a — 34.-36. Monat', dueAtMonths: 34),
    UExamination(id: 'u8', label: 'U8 — 46.-48. Monat', dueAtMonths: 46),
    UExamination(id: 'u9', label: 'U9 — 60.-64. Monat', dueAtMonths: 60),
    UExamination(id: 'j1', label: 'J1 — 12.-14. Lebensjahr', dueAtMonths: 144),
    UExamination(id: 'j2', label: 'J2 — 16.-17. Lebensjahr', dueAtMonths: 192),
  ];
}

/// Lokale, kontogetrennte Persistenz (keine appseitige Verschluesselung).
class KindDossierService {
  static final KindDossierService instance = KindDossierService();
  KindDossierService({FamilyHubStore? store})
      : _store = store ?? FamilyHubStore.instance;

  final FamilyHubStore _store;
  String? _loadedScope;
  int _loadRevision = 0;
  List<KindDossier> _dossiers = [];

  List<KindDossier> get dossiers {
    if (_loadedScope != _store.scope) _dossiers = [];
    return List.unmodifiable(_dossiers);
  }

  Future<void> load() async {
    final scope = _store.scope;
    final revision = ++_loadRevision;
    _dossiers = [];
    _loadedScope = null;
    try {
        final data = await _store.read(expectedScope: scope);
        final decoded = data[FamilyHubStore.dossierKey] ?? [];
        if (decoded is! List) {
          throw const FormatException('Invalid account dossier list');
        }
        var migrated = false;
        final dossiers = decoded.map((entry) {
          if (entry is! Map) {
            throw const FormatException('Invalid account dossier entry');
          }
          final data = Map<String, dynamic>.from(entry);
          final birthDate =
              DateTime.tryParse(data['birthDate']?.toString() ?? '');
          if (birthDate == null) migrated = true;
          // Alt-Daten ohne stabile ID: einmalig migrieren (fromJson vergibt
          // dann eine neue ID über den Konstruktor-Default).
          final idRaw = data['id'];
          if (idRaw == null || (idRaw is String && idRaw.isEmpty)) {
            migrated = true;
          }
          return KindDossier.fromJson(data);
        }).toList();
        if (migrated) {
          await _store.write({
            FamilyHubStore.dossierKey:
                dossiers.map((dossier) => dossier.toJson()).toList(),
          }, expectedScope: scope);
        }
        _store.requireScope(scope);
        if (revision != _loadRevision) throw const FamilyHubAccountChanged();
        _dossiers = dossiers;
        _loadedScope = scope;
    } catch (error) {
      if (revision == _loadRevision) _dossiers = [];
      rethrow;
    }
  }

  Future<void> save(List<KindDossier> dossiers, {String? expectedScope}) async {
    final scope = expectedScope ?? _loadedScope ?? _store.scope;
    _store.requireScope(scope);
    await _store.write({
      FamilyHubStore.dossierKey: dossiers.map((d) => d.toJson()).toList(),
    }, expectedScope: scope);
    _store.requireScope(scope);
    _dossiers = List.of(dossiers);
    _loadedScope = scope;
  }

  /// Fügt ein Dossier hinzu oder aktualisiert ein bestehendes. Die Zuordnung
  /// erfolgt über die stabile [KindDossier.id] — so bleibt ein Kind auch nach
  /// einer Umbenennung dasselbe Dossier, und gleichnamige Kinder kollidieren
  /// nicht mehr.
  Future<void> addOrUpdate(KindDossier dossier, {String? expectedScope}) async {
    final scope = expectedScope ?? _loadedScope;
    if (scope == null) throw StateError('Load account dossiers before editing');
    _store.requireScope(scope);
    final data = await _store.update((data) {
      final current = _decodeList(data);
      final idx = current.indexWhere((d) => d.id == dossier.id);
      if (idx != -1) {
        current[idx] = dossier;
      } else {
        current.add(dossier);
      }
      data[FamilyHubStore.dossierKey] = current.map((d) => d.toJson()).toList();
      return data;
    }, expectedScope: scope);
    _store.requireScope(scope);
    _dossiers = _decodeList(data);
  }

  /// Findet ein Dossier anhand des Kindnamens (für das Nachziehen aus dem
  /// Eltern-Netzwerk-Profil, das keine Dossier-IDs kennt). Gibt null zurück,
  /// wenn kein Dossier mit diesem Namen existiert.
  KindDossier? findByName(String childName) {
    final name = childName.trim();
    for (final d in dossiers) {
      if (d.childName.trim() == name) return d;
    }
    return null;
  }

  /// Hakt eine U-Untersuchung eines Kindes (per Dossier-[id]) ab bzw. entfernt
  /// den Haken wieder. Beim Abhaken wird das aktuelle Datum (ISO-8601) als
  /// [doneDate] gesetzt. Gibt das aktualisierte Dossier zurück oder null, wenn
  /// kein passendes Dossier/keine passende Untersuchung gefunden wurde.
  Future<KindDossier?> setUExamDone(
    String dossierId,
    String examId,
    bool done,
  ) async {
    final scope = _loadedScope;
    if (scope == null) throw StateError('Load account dossiers before editing');
    _store.requireScope(scope);
    KindDossier? updated;
    final data = await _store.update((data) {
    final current = _decodeList(data);
    final idx = current.indexWhere((d) => d.id == dossierId);
    if (idx == -1) throw StateError('Unknown child dossier');
    final dossier = current[idx];
    var found = false;
    final updatedExams = dossier.uExams.map((e) {
      if (e.id != examId) return e;
      found = true;
      return e.copyWith(
        isDone: done,
        doneDate: done ? DateTime.now().toIso8601String() : null,
      );
    }).toList();
    if (!found) throw StateError('Unknown child examination');
    updated = dossier.copyWith(uExams: updatedExams);
    current[idx] = updated!;
    data[FamilyHubStore.dossierKey] = current.map((d) => d.toJson()).toList();
    return data;
    }, expectedScope: scope);
    _store.requireScope(scope);
    _dossiers = _decodeList(data);
    return updated;
  }

  List<KindDossier> _decodeList(Map<String, dynamic> data) =>
      (data[FamilyHubStore.dossierKey] as List? ?? [])
          .map((entry) => KindDossier.fromJson(Map<String, dynamic>.from(entry as Map)))
          .toList();
}
