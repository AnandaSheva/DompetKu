# GitHub Copilot Instructions

DompetKu is a Flutter/Dart personal finance app for Android and web with a shared account-based, connected data model.

Follow these rules when suggesting changes:

- Use the existing feature-first architecture.
- Develop Android and web with the same Google sign-in, UID-scoped Firestore data, financial rules, and core features.
- Use device storage for caches, device preferences, and safe migration of existing data.
- Web Firebase integration exists; Android integration is planned and must be implemented and verified before it is described as available.
- Use existing Firebase services; do not add custom backend services, ads, analytics, or tracking, or automatically enable billing.
- Wait for authentication initialization before creating account repositories, enforce UID ownership, and preserve pending writes during logout and account changes.
- Use Riverpod providers and repositories for data/state access.
- Keep database logic out of UI widgets.
- Use existing theme tokens, spacing, radius, typography, and shared components.
- Keep user-facing UI copy in Bahasa Indonesia.
- Keep the public app name as `DompetKu`.
- Avoid unnecessary dependencies and Android permissions.
- Consider low-end Android performance and responsive mobile/desktop web layouts.
- Test account isolation, connection recovery, and synchronization with Firebase emulators and test accounts.
- Avoid broad rewrites of working systems.
- Treat backup/import, app lock, permissions, and update/download flows as security-sensitive.
- Keep privacy and security claims accurate.
- Run `flutter pub get`, `flutter analyze`, and `flutter test` before marking work complete.
