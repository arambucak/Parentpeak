# Events & Activities Quality Audit

Date: 2026-10-03. Scope: local `/tmp/pp-main` worktree. No deployment or production database changes in this audit.

## Confirmed Findings And Local Fixes

| Finding | Fix |
| --- | --- |
| Creation stored the same Berlin coordinates for unrelated venues | Address geocoder, bounded cache, request deduplication, invalid coordinate rejection; unknown coordinates stay null |
| Viewer location could silently become a fixed city origin | Resolve actual city/location or leave origin unknown; no fake distance or proximity qualification |
| Legacy placeholder coordinates produced misleading nearby badges | Resolve venue address where needed without rewriting production records |
| Filter/pagination order could hide matching results | Radius, visibility, date/price filters and ranking precede backend pagination |
| Missing price was interpreted as free, cent values rounded | Explicit zero only is free; paid, zero and null persist; cent values retained |
| Flyer price was shown but not persisted | Editable confirmed price flows through costPerPerson to database |
| Manual creation could bypass date confirmation | Date/time selection policy for manual and scanned forms; future date validation before side effects |
| Permanent required-state text overwhelmed date controls | Compact icon controls with selection feedback; errors only after submit and cleared after correction |
| Async scan/upload completion could touch disposed widgets | Mounted checks and processing guards; retain draft on save failure |
| Invitation dialog could use temporary client event ID | Use acknowledged server event ID |
| Missing creator identity and inconsistent event images | Shared EventHostIdentity using UserAvatar, stable photo loading/error states, stale identity response guards |
| Event strings incomplete outside launch locales | Explicit event translations and placeholder parity across all 16 registered locales, including all requested languages |
| Narrow/large-text category overlapped photo | Separate normal-flow category layout; fixed photo dimensions |
| Old RadioListTile API and parameter naming lints | RadioGroup and consistent lowerCamelCase API in secondary event UI |

## Validation

- Full Flutter suite: 332 passed, 1 skipped. The full run followed the feed-navigation regression repair.
- Backend unit suite: 61 passed; server syntax check passed.
- Follow-up Geocoder tests: 10 passed.
- Follow-up secondary event UI tests: 18 passed.
- Scoped analyzer: 20 event-related items, no issues.
- Full analyzer: unrelated informational diagnostics remain outside Events. No events warning/error suppressed.
- Diff whitespace check passed.
- Includes controlled location permission denial, missing coordinates, stale requests, concurrent participation capacity, ownership, local timezone, scanner parsing, price confirmation, photo failure, RTL and large-text tests.

## Remaining Boundaries

1. Event ageGroups are not persisted in the current Event database schema. Unknown age data must not be presented as known; real persistence requires a separate additive migration and schema approval.
2. Real address geocoding depends on the external Nominatim service, its usage policy, browser network/CORS and availability. Failed resolution remains unknown, not a fabricated number. No production geocoding SLA or browser/device network was certified.
3. Existing bad prices/coordinates are not bulk repaired. No event record was edited by the audit.
4. Tests use deterministic image, identity and scanner fixtures. Native camera/gallery, real Firebase sessions, live OCR quality and push delivery require device checks.
5. Network images use Flutter/platform HTTP and image caching, not guaranteed durable offline photo storage.
6. Explicit translation coverage and placeholder checks do not replace native-speaker linguistic review.
7. Two Event abstractions (MeetupEvent and CommunityEvent) remain. Shared identity/photo widgets reduce UI duplication; consolidation needs a separately scoped API/data migration rather than an audit-time rewrite.
8. No claim of universal error freedom. Changes are local pending review, CI and explicit publication approval.