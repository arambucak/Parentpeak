import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/widgets/language_change_mixin.dart';

enum ContactCategory { emergency, family, medical, school, other }

extension ContactCategoryX on ContactCategory {
  String get label {
    switch (this) {
      case ContactCategory.emergency: return 'Notruf';
      case ContactCategory.family:   return 'Familie';
      case ContactCategory.medical:  return 'Medizin';
      case ContactCategory.school:   return 'Schule';
      case ContactCategory.other:    return 'Sonstige';
    }
  }
  IconData get icon {
    switch (this) {
      case ContactCategory.emergency: return Icons.emergency_rounded;
      case ContactCategory.family:    return Icons.family_restroom_rounded;
      case ContactCategory.medical:   return Icons.medical_services_rounded;
      case ContactCategory.school:    return Icons.school_rounded;
      case ContactCategory.other:     return Icons.person_rounded;
    }
  }
  Color get color {
    switch (this) {
      case ContactCategory.emergency: return const Color(0xFFDC2626);
      case ContactCategory.family:    return const Color(0xFF7C3AED);
      case ContactCategory.medical:   return const Color(0xFF059669);
      case ContactCategory.school:    return const Color(0xFF2563EB);
      case ContactCategory.other:     return const Color(0xFF0EA5E9);
    }
  }
  Color get bgColor {
    switch (this) {
      case ContactCategory.emergency: return const Color(0xFFFEE2E2);
      case ContactCategory.family:    return const Color(0xFFF3E8FF);
      case ContactCategory.medical:   return const Color(0xFFD1FAE5);
      case ContactCategory.school:    return const Color(0xFFDBEAFE);
      case ContactCategory.other:     return const Color(0xFFE0F2FE);
    }
  }
}

class EmergencyContact {
  String id, name, phone, note;
  ContactCategory category;
  bool isPinned;

  EmergencyContact({required this.id, required this.name, required this.phone,
      this.note = '', this.category = ContactCategory.family, this.isPinned = false});

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'phone': phone,
    'note': note, 'category': category.index, 'isPinned': isPinned,
  };

  factory EmergencyContact.fromMap(Map<String, dynamic> m) => EmergencyContact(
    id: m['id'] as String? ?? UniqueKey().toString(),
    name: m['name'] as String? ?? '',
    phone: m['phone'] as String? ?? '',
    note: m['note'] as String? ?? '',
    category: ContactCategory.values[(m['category'] as int?) ?? 1],
    isPinned: m['isPinned'] as bool? ?? false,
  );
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with LanguageChangeMixin<ContactsScreen> {
  static const _prefsKey = 'emergency_contacts.v2';
  List<EmergencyContact> _contacts = [];
  bool _loaded = false;

  static const List<Map<String, dynamic>> _quickDial = [
    {'label': 'Polizei',         'number': '110',        'icon': Icons.local_police_rounded,    'color': Color(0xFF1D4ED8)},
    {'label': 'Notruf',          'number': '112',        'icon': Icons.emergency_rounded,       'color': Color(0xFFDC2626)},
    {'label': 'Gift-Notfall',    'number': '0228 19240', 'icon': Icons.science_rounded,         'color': Color(0xFF7C3AED)},
    {'label': 'Aerztl. Bereit.', 'number': '116 117',   'icon': Icons.medical_services_rounded,'color': Color(0xFF059669)},
  ];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _contacts = list.map((e) => EmergencyContact.fromMap(e as Map<String, dynamic>)).toList();
    } else {
      _contacts = [
        EmergencyContact(id: 'c1', name: 'Dr. Schmidt', phone: '+49 123 456789',
            note: 'Kinderarzt - Terminvergabe Mo-Fr 8-12', category: ContactCategory.medical, isPinned: true),
        EmergencyContact(id: 'c2', name: 'Grundschule Nord', phone: '+49 123 987654',
            note: 'Sekretariat 7:30-13:00', category: ContactCategory.school),
        EmergencyContact(id: 'c3', name: 'Oma Martha', phone: '+49 123 111222',
            note: 'Vertrauensperson der Kinder', category: ContactCategory.family, isPinned: true),
      ];
      await _saveContacts();
    }
    setState(() => _loaded = true);
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_contacts.map((c) => c.toMap()).toList()));
  }

  void _copyNumber(String number) {
    Clipboard.setData(ClipboardData(text: number));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text('$number kopiert - in Telefon-App einfuegen')),
      ]),
      backgroundColor: const Color(0xFF1E293B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showAddOrEditDialog([EmergencyContact? existing]) {
    final nameCtrl  = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final noteCtrl  = TextEditingController(text: existing?.note ?? '');
    ContactCategory cat = existing?.category ?? ContactCategory.family;
    bool pinned = existing?.isPinned ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top: 24, left: 24, right: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99)))),
              const SizedBox(height: 20),
              Text(existing == null ? 'Kontakt hinzufuegen' : 'Kontakt bearbeiten',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: ContactCategory.values.map((c) {
                  final sel = cat == c;
                  return GestureDetector(
                    onTap: () => setSheet(() => cat = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? c.color : c.bgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? c.color : c.color.withValues(alpha: 0.2)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(c.icon, size: 14, color: sel ? Colors.white : c.color),
                        const SizedBox(width: 5),
                        Text(c.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : c.color)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              _field(nameCtrl, 'Name', Icons.person_rounded),
              const SizedBox(height: 10),
              _field(phoneCtrl, 'Telefonnummer', Icons.phone_rounded, keyboard: TextInputType.phone),
              const SizedBox(height: 10),
              _field(noteCtrl, 'Notiz (optional)', Icons.notes_rounded, maxLines: 2),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => setSheet(() => pinned = !pinned),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: pinned ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: pinned ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(children: [
                    Icon(pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                      color: pinned ? const Color(0xFFD97706) : Colors.black38, size: 20),
                    const SizedBox(width: 10),
                    Text(pinned ? 'Oben angepinnt' : 'Nicht angepinnt',
                      style: TextStyle(fontWeight: FontWeight.w600,
                        color: pinned ? const Color(0xFFD97706) : Colors.black45)),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                if (existing != null)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                    label: const Text('Löschen', style: TextStyle(color: Colors.red)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _contacts.removeWhere((c) => c.id == existing.id));
                      _saveContacts();
                    },
                  ),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: cat.color,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  ),
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    if (name.isEmpty || phone.isEmpty) return;
                    Navigator.pop(ctx);
                    setState(() {
                      if (existing != null) {
                        existing.name = name; existing.phone = phone;
                        existing.note = noteCtrl.text.trim();
                        existing.category = cat; existing.isPinned = pinned;
                      } else {
                        _contacts.add(EmergencyContact(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: name, phone: phone, note: noteCtrl.text.trim(),
                          category: cat, isPinned: pinned,
                        ));
                      }
                    });
                    _saveContacts();
                  },
                  child: Text(existing == null ? 'Speichern' : 'Aktualisieren',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType keyboard = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: ctrl, keyboardType: keyboard, maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true, fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final pinned = _contacts.where((c) => c.isPinned).toList();
    final rest   = _contacts.where((c) => !c.isPinned).toList();
    final Map<ContactCategory, List<EmergencyContact>> grouped = {};
    for (final c in rest) {
      grouped.putIfAbsent(c.category, () => []).add(c);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 175,
            pinned: true,
            backgroundColor: const Color(0xFFDC2626),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7F1D1D), Color(0xFFDC2626)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 46, 20, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Notfallkontakte',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                          Text('Im Ernstfall sofort erreichbar',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ]),
                      ]),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_contacts.length} Kontakte  ${pinned.length} angepinnt',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              title: const Text('Notfallkontakte',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
              titlePadding: const EdgeInsets.only(left: 54, bottom: 16),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                onPressed: _showAddOrEditDialog,
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Schnellwahl Notruf'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2, shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.5,
                  children: _quickDial.map((q) {
                    final color = q['color'] as Color;
                    return Material(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _copyNumber(q['number'] as String),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: color.withValues(alpha: 0.25)),
                          ),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(q['icon'] as IconData, color: color, size: 17),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(q['label'] as String,
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: color)),
                                Text(q['number'] as String,
                                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
                              ],
                            )),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),

                if (pinned.isNotEmpty) ...[
                  _label('Angepinnt'),
                  const SizedBox(height: 10),
                  ...pinned.map((c) => _contactCard(c, isPinned: true)),
                  const SizedBox(height: 20),
                ],

                ...ContactCategory.values.map((cat) {
                  final group = grouped[cat];
                  if (group == null || group.isEmpty) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(cat.icon, size: 15, color: cat.color),
                      const SizedBox(width: 6),
                      Text(cat.label,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cat.color)),
                    ]),
                    const SizedBox(height: 10),
                    ...group.map((c) => _contactCard(c)),
                    const SizedBox(height: 18),
                  ]);
                }),

                if (_contacts.isEmpty)
                  Center(child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(children: [
                      const Icon(Icons.contacts_rounded, size: 52, color: Colors.black26),
                      const SizedBox(height: 12),
                      const Text('Noch keine Kontakte',
                        style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      const Text('Tippe auf + um wichtige Kontakte hinzuzufuegen.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.black38)),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _showAddOrEditDialog,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Kontakt hinzufuegen'),
                      ),
                    ]),
                  )),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: _contacts.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showAddOrEditDialog,
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Kontakt', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  Widget _label(String text) => Text(text,
    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1E293B)));

  Widget _contactCard(EmergencyContact c, {bool isPinned = false}) {
    final cat = c.category;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _copyNumber(c.phone),
          onLongPress: () => _showAddOrEditDialog(c),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPinned
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.07),
              ),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: cat.bgColor, borderRadius: BorderRadius.circular(14)),
                  child: Icon(cat.icon, color: cat.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(c.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                    if (isPinned) const Icon(Icons.push_pin_rounded, size: 13, color: Color(0xFFD97706)),
                  ]),
                  const SizedBox(height: 2),
                  Text(c.phone,
                    style: TextStyle(color: cat.color, fontWeight: FontWeight.w600, fontSize: 13)),
                  if (c.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(c.note,
                        style: const TextStyle(color: Colors.black45, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ])),
                const SizedBox(width: 8),
                Column(children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: cat.bgColor, borderRadius: BorderRadius.circular(11)),
                    child: Icon(Icons.copy_rounded, color: cat.color, size: 16),
                  ),
                  const SizedBox(height: 3),
                  Text('kopieren',
                    style: TextStyle(fontSize: 9, color: cat.color, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
