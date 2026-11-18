# Contributing to DompetKu

Thanks for your interest in improving DompetKu.

DompetKu is a connected personal finance app for Android and web. Contributions should keep shared account data and financial rules consistent across platforms while preserving a simple, lightweight experience and account privacy.

Android and web share Firebase Authentication and Firestore account storage. Configure Android build values locally and verify native Google sign-in and reminders on a device; see [the integration guide](docs/firebase-web.md).

## Local Setup

```bash
flutter pub get
flutter analyze
flutter test
```

To build a release APK locally:

```bash
flutter build apk --release --split-per-abi --dart-define-from-file=.env.local
```

## Branch Naming

Use short, descriptive names:

```txt
feat/update-checker
fix/wallet-balance
docs/readme-polish
refactor/settings-sheet
```

## Commit Style

Use clear commit messages:

```txt
feat: add budget reset flow
fix: prevent transfer to same wallet
docs: update release checklist
test: cover version comparison
```

## Development Principles

- Keep Android and web aligned around Google sign-in and the same UID-scoped Firestore datasets.
- Avoid unnecessary dependencies.
- Use existing Firebase services for authentication and synchronization; do not add custom backend services, ads, analytics, or tracking.
- Treat Android and web as equal product platforms.
- Preserve existing device data and require a saved backup and explicit migration to the selected account.
- Verify account isolation, interrupted connections, pending writes, and cross-client synchronization with Firebase emulators; never use production financial data for tests.
- Keep Bahasa Indonesia for app UI.
- Keep public documentation clear and direct.
- Do not commit secrets, keystores, local config, backups, or exported financial data.

## UI and UX

- Follow the existing design system.
- Keep controls readable and comfortable to tap.
- Avoid heavy blur, excessive shadows, and expensive animations.
- Use simple, beginner-friendly wording in the app.

## AI-Assisted Contributions

AI-assisted pull requests are welcome when they are reviewed, scoped, and tested. Contributors are responsible for everything they submit.

- Do not submit unreviewed AI output.
- Mention AI assistance in the pull request if it materially affected the change.
- Do not use AI output to add secrets, tracking, unnecessary permissions, or undocumented behavior.
- Follow [AGENTS.md](AGENTS.md) and [docs/ai-assisted-development.md](docs/ai-assisted-development.md).
- Run the required checks before opening a pull request.

## Before Opening a Pull Request

Run:

```bash
flutter analyze
flutter test
```

Update documentation when behavior, permissions, release process, or security assumptions change.
