# Parentpeak

**Nicht perfekt sein müssen. Einfach da sein.**

Die App für Eltern die alles geben — und selbst Halt brauchen. Kalender, KI-Beratung, Rezepte, Netzwerk. Alles an einem Ort.

## Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) — iOS, Android, Web |
| Backend | Node.js / Express / Prisma / PostgreSQL |
| AI | Google Gemini (integrativer pädagogischer Ansatz) |
| Auth | Firebase Authentication |
| Hosting | Render (Backend), GitHub Pages (Web) |

## Features

- **Familienkalender** — Termine, Feiertage, Schulferien (DE/AT/CH/TR/GB)
- **KI-Elternberatung** — 8 pädagogische Ansätze (GfK, Hüther, Montessori, Reggio, Freinet, Fröbel, Situationsansatz, Juul)
- **Familien-Küche** — Altersgerechte Rezepte per 1-Tap
- **Eltern-Netzwerk** — Spielfreunde finden, Kontakte knüpfen
- **Familien-Geld** — Leistungs-Wegweiser (6 Länder)
- **Familien-Zentrale** — Einkaufsliste, To-do, Kind-Dossier
- **Wochenrückblick** — 5-Fragen Reflexion mit KI-Feedback
- **28 Sprachen** — DE, EN, TR, KU und mehr

## Quick Start

```bash
flutter pub get
flutter run -d chrome          # Web
flutter run -d <simulator-id>  # iOS
```

## Environment

Copy `.env.example` to `.env` and fill in your keys:
- `GEMINI_API_KEY` — Google Gemini
- `BACKEND_BASE_URL` — Render backend URL

## Deployment

- **Web:** GitHub Actions → GitHub Pages (parentpeak.de)
- **Backend:** Render auto-deploy from main
- **Keep-alive:** GitHub Actions pings /health every 14 min

## Links

- Website: https://parentpeak.com
- Web-App: https://parentpeak.de
- Instagram: [@parentpeak.app](https://instagram.com/parentpeak.app)
- Support: support@parentpeak.com

## License

All rights reserved. © 2026 Fatih Bucak – Parentpeak.
