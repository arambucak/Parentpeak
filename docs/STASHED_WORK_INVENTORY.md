# Gesicherter Arbeitsstrang: Inventar

- **Stash:** `stash@{0}`, Commit `61f28f56fb13b6201fcc56e9a5fa1b980ef2f3d1`
- **Fundort:** Branch `backup/local-unsynced-2026-10-21`
- **Gesichert am:** 24. Oktober 2026, 12:28:36 Uhr (Europe/Berlin)
- **Sicherung:** Uncommittete und ungetrackte Dateien gemeinsam mit `git stash push --include-untracked` gesichert; der Stash wurde nicht angewendet oder gelöscht.

## Dateien

| Pfad | Inhalt |
|---|---|
| `docs/MONETIZATION_ADS_PLAN.md` | Snapshot des Monetarisierungsplans aus dem ursprünglichen Arbeitsbaum; die aktuelle, separat gepflegte Planfassung liegt im Monetarisierungs-Branch und dieser Snapshot gehört nicht in den unabhängigen Feature-Arbeitsstrang. |
| `lib/l10n/app_localizations_all.dart` | Ergänzt lokalisierte Benachrichtigungs-/Berechtigungstexte, einen englischen Core-String-Fallback und aktualisierte DDG-Bezeichnungen. |
| `lib/models/family_place.dart` | Modelliert Familienorte mit Kategorie, Koordinaten, Öffnungszeiten, Eigenschaften und JSON-Konvertierung. |
| `lib/models/kind_dossier.dart` | Ergänzt das Entfernen eines Kind-Dossiers einschließlich Persistierung. |
| `lib/services/family_place_service.dart` | Ergänzt Laden, Zwischenspeichern, Sortieren und Öffnungszeitenprüfung für Familienorte. |
| `lib/ui/profile_safety_screen.dart` | Ergänzt Anzeige und Verwaltung des Benachrichtigungsstatus samt Berechtigungsabfrage/-anfrage im Profil-/Sicherheitsbereich. |
| `lib/ui/widgets/native_ad_slot.dart` | Benennt den Slot-Parameter von `context_hint` zu `contextHint` um und formatiert den bestehenden Widget-Code. |
| `lib/ui/widgets/treasure_mine_offer_card.dart` | Ergänzt eine Löschaktion für ein Angebot auf der Karte. |
| `test/family_place_service_test.dart` | Testet Nähe-Sortierung und Öffnungszeitenprüfung für Familienorte. |
| `test/ritual_ruhe_models_test.dart` | Ergänzt einen Test für das Entfernen und Persistieren eines Kind-Dossiers. |
| `test/supported_languages_test.dart` | Ergänzt Prüfungen für Benachrichtigungs-Strings und deren Sprach-Fallback. |

## Weiteres Vorgehen

Der unabhängige Feature-Arbeitsstrang wird später separat gesichtet und auf einem eigenen Branch direkt von `origin/main` aufgebaut. Er erhält einen eigenen PR, getrennt von allen Monetarisierungs-/Werbe-PRs. Der gesicherte Stash bleibt bis zu einer ausdrücklich abgestimmten Wiederaufnahme unangetastet.
