# Security Policy

## Supported Versions

Security fixes are focused on the latest public release of DompetKu.

| Version | Supported |
| --- | --- |
| Latest release | Yes |
| Older releases | Best effort |

## Security Model

DompetKu's product direction is connected personal finance tracking on Android and web, using Google sign-in and UID-scoped Firebase Firestore data.

Web implements this account model today. Android Firebase configuration, authentication, account storage, and migration remain planned work. Shared security requirements below must be verified on Android before integrated releases are published.

- Google sign-in authenticates access to account financial data on both platforms as integration is implemented.
- Firestore Security Rules must enforce ownership by the authenticated Firebase UID for every account path.
- No ads are included.
- No analytics or tracking is included.
- Account financial data belongs to the shared Firestore dataset; device caches and queued changes must remain isolated by account.
- Account changes must dispose the previous account state and listeners. Pending writes must be synchronized or explicitly backed up before a confirmed discard and logout.
- Persistent browser caching requires trusted-device consent. Explain network use and cache retention clearly.
- Local app lock uses a PIN and optional biometric unlock when enabled.
- PIN data is not stored as raw text.
- App lock is not full database encryption.
- Backup files contain financial data and should be stored safely.
- Existing device data must not be uploaded or removed silently; migration requires a saved backup, a visible target account, and explicit user action.
- APK files installed from GitHub may trigger Android or Play Protect sideload warnings.

Do not treat DompetKu as a replacement for device-level security, encrypted storage, or a password manager.

## Reporting a Vulnerability

For non-sensitive bugs, open a GitHub issue.

For sensitive security issues, contact the maintainer privately through the maintainer's GitHub profile before publishing details.

Please include:

- A clear description of the issue
- Steps to reproduce
- Affected app version
- Platform, Android version and device model, or browser version as applicable
- Any relevant logs or screenshots with personal data removed

## Backup Safety

Backup and restore are user-controlled. DompetKu validates backup files before restore, but users should keep backup files in a safe place and avoid sharing them publicly.

## APK Verification

When a release includes a SHA256 checksum, verify the APK before installing it:

```powershell
Get-FileHash .\DompetSheva-vX.X.X-arm64.apk -Algorithm SHA256
```

DompetKu does not claim to be "100% secure". Security is handled as an ongoing maintenance responsibility.
