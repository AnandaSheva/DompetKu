# AGENTS.md

This file is the primary guide for AI coding agents working on DompetKu.

## Project Overview

DompetKu is a connected personal finance tracker built with Flutter for Android and web. Both platforms must use the same account-based financial data, business rules, and core features, with Google sign-in and Firebase Firestore synchronization across devices.

Android and web now use the shared Firebase account path. Android Google sign-in, explicit legacy-data migration, and local bill alarms are implemented in source. Verify real Google login, migration, and notification delivery on Android before publishing an integrated release.

## Tech Stack

- Flutter
- Dart
- Firebase Authentication
- Cloud Firestore
- Drift
- SQLite
- Riverpod
- fl_chart
- Android and web

## Architecture Map

- `lib/app` for app bootstrap, theme, and global providers
- `lib/data` for database, repositories, and data models
- `lib/features` for feature-first UI and flows
- `lib/shared` for reusable UI components
- `lib/core` for constants, enums, formatters, and helpers
- `test` for unit and widget tests
- `android` for Android platform configuration
- `web` for browser platform configuration

Keep database and platform logic out of UI widgets. Use repositories and providers for app state and data access.

## Commands

Run these checks before reporting completion:

```bash
flutter pub get
flutter analyze
flutter test
```

For release builds:

```bash
flutter build apk --release --split-per-abi --dart-define-from-file=.env.local
```

## Coding Rules

- Develop Android and web as equal clients of the same connected finance app.
- Use Google sign-in and per-account Firebase Firestore on both platforms. Keep financial data and business rules consistent across devices using the same account.
- Treat device storage as cache, device preferences, or a migration source; account financial data belongs to the shared Firestore dataset.
- Keep user-facing app name as `DompetKu`.
- Use `dompet_sheva` for the Dart package and `dompet-sheva` for export filenames.
- Preserve the legacy Android application ID, native update channel, and database name for installed-app and local-data compatibility. Repository URLs must point to an existing release source.
- Keep UI text in Bahasa Indonesia.
- Prefer small, reviewable changes.
- Use existing repositories, providers, theme tokens, and shared components.
- Do not rewrite working systems without a clear reason.
- Do not add unnecessary dependencies.
- Use the existing Firebase services for authentication and data synchronization. Do not add a custom backend, ads, tracking, or analytics.
- Do not commit generated junk, local exports, backups, or temporary reports.

## UI and UX Rules

- Keep the visual direction Apple-like/iOS modern, but lightweight.
- Use existing design tokens and reusable components.
- Keep touch targets comfortable on Android and mobile web, and layouts usable on desktop browsers.
- Use consistent account, loading, synchronization, retry, and error states across platforms.
- Maintain contrast and readability.
- Keep interactions fast and subtle.
- Avoid excessive blur, glass effects, shadows, gradients, or animation.
- Avoid generic Material defaults when an existing premium component exists.
- Keep copy clear, short, beginner-friendly, and professional.

## Security Rules

- Do not store raw PINs.
- App lock is local protection, not full database encryption.
- Backup files contain financial data.
- Treat backup/import and update/download flows as security-sensitive.
- Do not install APKs silently.
- Do not add suspicious or unnecessary Android permissions.
- Do not commit `android/key.properties`, `.jks`, `.keystore`, or signing secrets.
- Keep security and privacy claims accurate.

## Privacy Rules

- Require Google sign-in for account financial data on Android and web as integration is implemented.
- Synchronize financial data only within the authenticated Firebase UID on both platforms.
- No ads.
- No analytics or tracking.
- No hidden network activity. Explain Google sign-in, Firestore synchronization, and device caching in privacy copy on both platforms.
- Internet access supports account authentication and financial data synchronization on Android and web, plus user-triggered updates, downloads, external links, or sharing where supported.

## Data Rules

- Use integer values for Rupiah.
- Keep Drift queries in repositories or DAOs, not directly in UI.
- Validate imports before destructive restore.
- Transfers must not count as income or expense.
- Preserve migration safety for existing local data.
- Show pending, synchronized, and failed states accurately. Cached data and queued changes must not be presented as confirmed server data.

## Firebase Rules for Android and Web

- Gate account repositories on both platforms behind completed auth-state initialization.
- Scope every cloud path to the Firebase UID and enforce ownership in Firestore Security Rules.
- Keep one shared subscription per account collection; never create a listener per widget.
- Ask for trusted-device consent before persistent browser caching.
- Preserve pending writes and block logout until synchronization succeeds.
- Legacy device-data migration needs a saved backup, visible target account, and explicit user action; never upload or discard existing data silently.
- Stage destructive imports before atomically activating the replacement dataset.
- Use Firebase emulators for account isolation, rules, interrupted connections, pending writes, retries, and cross-client synchronization tests; never test on production financial data.
- Do not add Firebase Analytics or upload Google credentials to Firestore.

## Release Rules

- Release APKs must be built intentionally.
- Release signing secrets stay local.
- Generate SHA256 checksums for published APKs.
- Keep release notes concise and accurate.
- Do not publish debug-signed APKs as official releases.

## Do Not Do

- Do not add custom backend services alongside Firebase.
- Do not create separate financial datasets or divergent business rules for Android and web using the same account.
- Use Firestore on the Spark plan for both platforms; never enable billing automatically.
- Do not add ads, analytics, or tracking.
- Do not add chatbot or AI features to the app.
- Do not add broad storage, overlay, accessibility, SMS, contacts, or location permissions.
- Do not silently install updates.
- Do not fabricate features in documentation.

## Report Format

When an AI agent changes code or repository files, report:

- Summary
- Changed files
- Tests run
- Build result
- New dependencies
- Permissions changed
- Known limitations
