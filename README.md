# Parentpeak

> One calm place for family planning, connection and everyday support.

Parentpeak is a Flutter-based family companion app that brings planning,
communication, community and wellbeing into one focused experience.

## Product

Parentpeak helps families stay connected and organized without turning daily
life into another project-management tool.

- **Family hub** for trusted contacts and shared context
- **Calendar and organization** for appointments, tasks and shopping
- **Community features** for local activities, parent matching and sharing
- **Impulse and development** for practical, recurring family support
- **AI parent guidance** with dedicated safety guardrails

The app is currently in active product and release development.

## Tech Stack

| Area | Technology |
| --- | --- |
| Mobile and web app | Flutter, Dart, Material 3 |
| Authentication | Firebase Authentication |
| Monitoring | Firebase Crashlytics |
| Backend integration | REST APIs, Node.js services |
| Data and security | Secure storage, token-based writes, rate limiting, CORS allowlists |
| Payments | Stripe integration |
| Platforms | Android, iOS, macOS and web |

## Repository Structure

```text
lib/                 Flutter application and feature modules
backend/             Node.js backend, Prisma schema and API tests
integration_test/    End-to-end Flutter checks
test/                Unit and widget tests
docs/                Deployment, security and release documentation
scripts/             Repository-safe build, analysis and smoke-test commands
artifacts/           Review screenshots and test evidence
```

## Quick Start

### Prerequisites

- Flutter SDK
- Android emulator/device or an Apple development environment
- Node.js for backend work

### Run the app

```bash
bash scripts/flutter_repo.sh pub get
bash scripts/flutter_repo.sh run
```

For local configuration, create `.env` from `.env.example` and provide only
the values required for your environment. Never ship backend service tokens or
provider secrets in a mobile or web bundle.

## Quality Gates

Run the repository-safe checks before opening a release or deployment PR:

```bash
bash scripts/flutter_repo.sh analyze
bash scripts/verify_backend_security_baseline.sh
bash scripts/sync_guard.sh check
```

For production verification, use the documented security and webhook smoke
tests in the [release documentation](docs/APP_GO_LIVE_OPERATIONS_CHECKLIST.md).

## Documentation

- [Backend deployment guide](docs/BACKEND_DEPLOY_BEGINNER_GUIDE.md)
- [Authentication hardening runbook](docs/AUTH_HARDENING_RUNBOOK.md)
- [Go-live operations checklist](docs/APP_GO_LIVE_OPERATIONS_CHECKLIST.md)
- [Release priority board](docs/APP_RELEASE_PRIORITY_BOARD.md)
- [Family profile implementation guide](docs/FAMILY_PROFILE_README.md)
- [Testing guide](TESTING_GUIDE.md)

## Security

Please do not commit API keys, Firebase credentials, signing files or backend
service tokens. Report security concerns privately rather than opening a
public issue with sensitive details.

## Project Status

Parentpeak is actively being refined across product, accessibility, testing
and production operations. Release decisions and operational checks are kept
in the `docs/` directory so the public project overview stays concise.

## License

The project is currently maintained as a private product codebase. Licensing
and contribution terms will be published with the public release policy.