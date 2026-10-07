import 'package:parentpeak/l10n/app_localizations.dart';

String? treasureHandoverLocation(AppLocalizations l10n, String? value) {
  const keys = {
    'sunday_morning': 'treasureSlotSunday',
    'monday_evening': 'treasureSlotMonday',
    'tuesday_morning': 'treasureSlotTuesday',
    'front_door_box': 'treasureDropRetterBox',
    'daycare_locker': 'treasureDropKitaLocker',
    'entrance_mailbox': 'treasureDropMailbox',
  };
  final key = keys[value];
  return key == null ? value : l10n.t(key);
}

String treasureHandoverNotes(AppLocalizations l10n, String value) {
  // The server prepends one mode label; everything after it is user text.
  const modes = {
    'Stiller Tausch': 'treasureHandoverFlyingSwap',
    'Kurz treffen': 'treasureHandoverCoffeeMode',
  };
  for (final entry in modes.entries) {
    if (value == entry.key) return l10n.t(entry.value);
    final prefix = '${entry.key} · ';
    if (value.startsWith(prefix)) {
      return '${l10n.t(entry.value)} · ${value.substring(prefix.length)}';
    }
  }
  return value;
}
