import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Kind-Dossier — alle wichtigen Infos zu einem Kind an einem Ort.
/// NUR LOKAL gespeichert (sensible Daten verlassen nie das Geraet).
class KindDossier {
  final String childName;
  final int ageMonths;
  final String? clothingSize;
  final String? shoeSize;
  final List<String> allergies;
  final String? doctorName;
  final String? doctorPhone;
  final String? bloodType;
  final String? emergencyContact;
  final String? emergencyPhone;
  final String? kitaSchool;        // Name der Einrichtung
  final String? kitaGroup;         // Gruppe/Klasse
  final String? kitaTeacher;       // Erzieherin/Lehrerin
  final List<UExamination> uExams;
  final String? notes;

  const KindDossier({
    required this.childName,
    required this.ageMonths,
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
  });

  Map<String, dynamic> toJson() => {
        'childName': childName,
        'ageMonths': ageMonths,
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

  factory KindDossier.fromJson(Map<String, dynamic> j) => KindDossier(
        childName: j['childName'] as String? ?? '',
        ageMonths: j['ageMonths'] as int? ?? 0,
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

/// U-Untersuchung (Vorsorge) mit automatischer Faelligkeit.
class UExamination {
  final String id;       // "u1", "u2", ..., "u9", "j1", "j2"
  final String label;    // "U1 (direkt nach Geburt)"
  final int dueAtMonths; // Faellig ab diesem Alter (Monate)
  final bool isDone;
  final String? doneDate; // Wann gemacht (optional)

  const UExamination({
    required this.id,
    required this.label,
    required this.dueAtMonths,
    this.isDone = false,
    this.doneDate,
  });

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

/// Deutsche U-Untersuchungen (automatisch generiert nach Kind-Alter).
class UExaminationData {
  static List<UExamination> generateForChild(int ageMonths, {List<UExamination> existing = const []}) {
    final all = _allExams.map((e) {
      final done = existing.where((ex) => ex.id == e.id).firstOrNull;
      return UExamination(
        id: e.id,
        label: e.label,
        dueAtMonths: e.dueAtMonths,
        isDone: done?.isDone ?? false,
        doneDate: done?.doneDate,
      );
    }).toList();
    return all;
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

/// Persistenz fuer Kind-Dossiers (lokal, verschluesselt).
class KindDossierService {
  static final KindDossierService instance = KindDossierService._();
  KindDossierService._();

  static const _key = 'kinddossier.data';
  List<KindDossier> _dossiers = [];

  List<KindDossier> get dossiers => List.unmodifiable(_dossiers);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        _dossiers = (jsonDecode(raw) as List)
            .map((e) => KindDossier.fromJson(e))
            .toList();
      } catch (_) {}
    }
  }

  Future<void> save(List<KindDossier> dossiers) async {
    _dossiers = dossiers;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_dossiers.map((d) => d.toJson()).toList()));
  }

  Future<void> addOrUpdate(KindDossier dossier) async {
    final idx = _dossiers.indexWhere((d) => d.childName == dossier.childName);
    if (idx != -1) {
      _dossiers[idx] = dossier;
    } else {
      _dossiers.add(dossier);
    }
    await save(_dossiers);
  }
}
