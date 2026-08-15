# Beta access and public launch

## Current beta

Parentpeak is free during beta. No trial countdown is shown and beta users have
full access.

- Flutter: `PP_BETA_FREE_ACCESS=true` (default)
- Backend: `BETA_FREE_ACCESS=1` (default)

## Public launch

At public launch, existing beta users receive 30 free days from the launch
date. Users who register later receive 30 free days from registration.

Configure the same UTC launch date in both runtimes:

```text
PP_BETA_FREE_ACCESS=false
PP_PUBLIC_LAUNCH_DATE=2027-01-15T00:00:00Z

BETA_FREE_ACCESS=0
PUBLIC_LAUNCH_DATE=2027-01-15T00:00:00Z
```

The Flutter values are build-time `dart-define` values. The backend values are
runtime environment variables. Do not switch one side without the other.

## Customer-facing wording

- During beta: `Aktuell kostenlos in der Beta.`
- Launch explanation: `Nach dem offiziellen Start: 1 Monat kostenlos testen.`
- CTA: `Beta kostenlos starten`

Payment methods are explained only when a user actively selects a paid plan.