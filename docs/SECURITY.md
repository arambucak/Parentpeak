# Security Policy

## Reporting a vulnerability

Please do not publish credentials, personal data or exploitable details in a
public issue. Contact the repository owner privately through GitHub or the
project contact channel and include the affected component, impact and a
minimal reproduction when safe to share.

## Secrets policy

Production credentials must remain in the deployment provider or a local
ignored environment file. Never commit Stripe signing secrets, Gemini keys,
Firebase service credentials, database passwords or backend bearer tokens.

If a credential is exposed, treat it as compromised immediately:

1. Revoke or rotate it at the provider.
2. Update the deployment environment.
3. Remove the value from files and commit history where appropriate.
4. Run the security smoke tests before the next release.

## Supported versions

The current `main` branch is the supported development line. Security fixes
are evaluated there before release deployment.