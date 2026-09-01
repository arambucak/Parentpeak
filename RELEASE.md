# Release Guide — Parentpeak

So baust du sichere Release-Builds für Google Play und den iOS App Store.

> **Wichtigstes Prinzip:** Echte Secrets (API-Keys, Tokens) werden **niemals**
> in die App gebündelt. Sie kommen ausschließlich zur Build-Zeit über
> `--dart-define`. Die gebündelte `assets/env.template` enthält nur Platzhalter.

---

## 1. Secrets vorbereiten

Die App liest Secrets in dieser Priorität:
1. `--dart-define` (Build-Zeit) — **so machen wir es für Releases**
2. Laufzeit-Cache
3. Gebündelte `assets/env.template` (nur Platzhalter/Defaults)

Für einen Release-Build brauchst du diese Werte (aus deinem Passwort-Manager,
Render-Dashboard bzw. Google/Stripe-Konsole):

| Variable | Beschreibung |
|----------|-------------|
| `GEMINI_API_KEY` | Google Gemini API Key |
| `GEMINI_MODEL_NAME` | z.B. `gemini-3.5-flash-lite` |
| `BACKEND_BASE_URL` | z.B. `https://parentpeak.onrender.com` |
| `BACKEND_API_TOKEN` | Backend Auth Token |
| `STRIPE_PUBLISHABLE_KEY` | `pk_live_...` (kein Secret, aber via define) |
| `PRIVACY_POLICY_URL` | `https://parentpeak.de/privacy` |
| `TERMS_OF_SERVICE_URL` | `https://parentpeak.de/terms` |
| `CONTACT_EMAIL` | `support@parentpeak.com` |

Tipp: Lege die Werte einmalig in eine lokale, **nicht committete** Datei
`release.env` (steht in `.gitignore` durch `*.env.local` / `.env` Muster —
nenne sie z.B. `release.env.local`) und lade sie beim Build.

---

## 2. Android Keystore erstellen (einmalig)

Ohne signierten Keystore kann Google Play kein AAB annehmen.

```bash
# Keystore-Ordner anlegen (liegt außerhalb von android/app, nicht im Git)
mkdir -p android/keystores

# Upload-Keystore erzeugen (gültig 27 Jahre)
keytool -genkey -v \
  -keystore android/keystores/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Du wirst nach einem Passwort und ein paar Angaben (Name, Organisation) gefragt.
**Bewahre Keystore-Datei und Passwörter sicher auf** — ohne sie kannst du keine
App-Updates mehr veröffentlichen.

Dann `android/key.properties` anlegen (aus dem Template):

```properties
storePassword=DEIN_STORE_PASSWORT
keyPassword=DEIN_KEY_PASSWORT
keyAlias=upload
storeFile=../keystores/upload-keystore.jks
```

> `key.properties`, `*.jks` und `keystores/` sind bereits in `.gitignore` —
> sie landen also nie im Repo.

---

## 3. Android Release-Build (AAB für Play Store)

```bash
flutter build appbundle --release \
  --dart-define=GEMINI_API_KEY="$GEMINI_API_KEY" \
  --dart-define=GEMINI_MODEL_NAME="gemini-3.5-flash-lite" \
  --dart-define=BACKEND_BASE_URL="$BACKEND_BASE_URL" \
  --dart-define=BACKEND_API_TOKEN="$BACKEND_API_TOKEN" \
  --dart-define=STRIPE_PUBLISHABLE_KEY="$STRIPE_PUBLISHABLE_KEY" \
  --dart-define=PRIVACY_POLICY_URL="https://parentpeak.de/privacy" \
  --dart-define=TERMS_OF_SERVICE_URL="https://parentpeak.de/terms" \
  --dart-define=CONTACT_EMAIL="support@parentpeak.com"
```

Ergebnis: `build/app/outputs/bundle/release/app-release.aab`
→ Diese Datei lädst du in der Google Play Console hoch.

Vor jedem neuen Upload die Version in `pubspec.yaml` erhöhen
(`version: 1.0.0+1` → `1.0.1+2`, die Zahl nach `+` ist der versionCode).

---

## 4. iOS Release-Build (App Store)

Voraussetzung: Apple Developer Account (99 €/Jahr) + Signing in Xcode eingerichtet.

```bash
flutter build ipa --release \
  --dart-define=GEMINI_API_KEY="$GEMINI_API_KEY" \
  --dart-define=GEMINI_MODEL_NAME="gemini-3.5-flash-lite" \
  --dart-define=BACKEND_BASE_URL="$BACKEND_BASE_URL" \
  --dart-define=BACKEND_API_TOKEN="$BACKEND_API_TOKEN" \
  --dart-define=STRIPE_PUBLISHABLE_KEY="$STRIPE_PUBLISHABLE_KEY" \
  --dart-define=PRIVACY_POLICY_URL="https://parentpeak.de/privacy" \
  --dart-define=TERMS_OF_SERVICE_URL="https://parentpeak.de/terms" \
  --dart-define=CONTACT_EMAIL="support@parentpeak.com"
```

Ergebnis: `build/ios/ipa/*.ipa`
→ Upload über Xcode Organizer oder `xcrun altool` / Transporter zu App Store Connect.

---

## 5. Vor jedem Release prüfen

- [ ] `flutter analyze` → 0 Errors
- [ ] `flutter test` → alle grün
- [ ] Version in `pubspec.yaml` erhöht
- [ ] Alle `--dart-define` Werte gesetzt (kein leerer Key)
- [ ] Keine echten Secrets im Git (`git grep pp_live_` sollte leer sein)
- [ ] Datenschutz + AGB URLs erreichbar (parentpeak.de/privacy, /terms)

---

## 6. Sicherheits-Hinweise

- Die App startet auch ohne gesetzte Secrets (degradierter Modus), aber
  KI-Features und Backend-Sync brauchen die echten Keys.
- Der Node-Backend-Token (`BACKEND_API_TOKEN`) sollte regelmäßig rotiert werden.
  Falls der alte Token `pp_live_2026_...` je im Git war: **rotieren** (neuen im
  Render-Dashboard setzen, alten invalidieren).
- Firebase-`apiKey` in `lib/firebase_options.dart` ist per Design öffentlich und
  durch Firebase Security Rules geschützt — kein Geheimnis.
- Stripe Publishable Key (`pk_...`) ist ebenfalls kein Geheimnis. Der Stripe
  **Secret Key** darf nur im Backend liegen, nie in der Flutter-App.
