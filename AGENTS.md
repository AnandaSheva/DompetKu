# AGENTS.md

This file is the primary guide for AI coding agents working on DompetKu.

## Project Overview

DompetKu is an offline-first Android personal finance tracker built with Flutter. The app helps users manage income, expenses, transfers, wallets, budgets, backups, and app updates locally on their device.

## Tech Stack

- Flutter
- Dart
- Drift
- SQLite
- Riverpod
- fl_chart
- Android

## Architecture Map

- `lib/app` for app bootstrap, theme, and global providers
- `lib/data` for database, repositories, and data models
- `lib/features` for feature-first UI and flows
- `lib/shared` for reusable UI components
- `lib/core` for constants, enums, formatters, and helpers
- `test` for unit and widget tests
- `android` for Android platform configuration

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
flutter build apk --release --split-per-abi
```

## Coding Rules

- Keep DompetKu offline-first.
- Keep Android data local by default. Web uses Google sign-in and per-account Firebase Firestore, as explicitly requested.
- Keep user-facing app name as `DompetKu`.
- Use `dompet_sheva` for the Dart package and `dompet-sheva` for export filenames.
- Preserve the legacy Android application ID, native update channel, and database name for installed-app and local-data compatibility. Repository URLs must point to an existing release source.
- Keep UI text in Bahasa Indonesia.
- Prefer small, reviewable changes.
- Use existing repositories, providers, theme tokens, and shared components.
- Do not rewrite working systems without a clear reason.
- Do not add unnecessary dependencies.
- Do not add a custom backend, ads, tracking, or analytics. Google login and Firestore are allowed only for web; keep Android offline without accounts.
- Do not commit generated junk, local exports, backups, or temporary reports.

## UI and UX Rules

- Keep the visual direction Apple-like/iOS modern, but lightweight.
- Use existing design tokens and reusable components.
- Keep touch targets comfortable for Android.
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

- Android requires no account. Web requires Google sign-in.
- Android core features stay local. Web financial data syncs only within the authenticated Firebase UID.
- No ads.
- No analytics or tracking.
- No hidden network activity. Explain Google sign-in, Firestore sync, and optional persistent browser cache in web privacy copy.
- Android internet access remains tied to user-triggered update checks, APK downloads, external links, or sharing exports. Web may use Firebase Auth and Firestore after account sign-in.

## Data Rules

- Use integer values for Rupiah.
- Keep Drift queries in repositories or DAOs, not directly in UI.
- Validate imports before destructive restore.
- Transfers must not count as income or expense.
- Preserve migration safety for existing local data.

## Web Firebase Rules

- Gate web account repositories behind completed auth-state initialization.
- Scope every cloud path to the Firebase UID and enforce ownership in Firestore Security Rules.
- Keep one shared subscription per account collection; never create a listener per widget.
- Ask for trusted-device consent before persistent browser caching.
- Preserve pending writes and block logout until synchronization succeeds.
- Legacy local migration needs a downloaded backup, visible target account, and explicit user action.
- Stage destructive imports before atomically activating the replacement dataset.
- Use Firebase emulators for account isolation, rules, and offline-write tests; never test on production financial data.
- Do not add Firebase Analytics or upload Google credentials to Firestore.

## Release Rules

- Release APKs must be built intentionally.
- Release signing secrets stay local.
- Generate SHA256 checksums for published APKs.
- Keep release notes concise and accurate.
- Do not publish debug-signed APKs as official releases.

## Do Not Do

- Do not add backend services.
- Do not add login or online accounts to Android. Google sign-in is allowed for web.
- Do not add cloud sync to Android. Web may use Firestore on the Spark plan; never enable billing automatically.
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
