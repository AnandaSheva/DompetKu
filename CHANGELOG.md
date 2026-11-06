# Changelog

All notable changes to DompetKu are documented in this file.

## [Unreleased]

- Apply a blue/bright-blue palette across light and dark themes, financial accents, categories, charts, app icons, and web metadata.
- Display earlier/imported category colors in the blue palette without rewriting stored financial data.

- Rebrand the app as DompetKu across Android, web, onboarding, settings, app lock, and update messages.
- Rename new backup, CSV export, and downloaded APK files to use the new brand.
- Rename the Dart package to `dompet_sheva` and update project documentation and CI artifact naming.
- Preserve the existing Android application ID, database, backup format, and release source for compatibility.

## [1.3.0] - 2026-07-03

- Improved Analytics period filtering.
- Improved chart explanations, legends, and budget visibility.
- Improved category icons across transactions, dashboard, and settings.
- Improved budget form layout consistency.
- Fixed app version display consistency.
- Prepared release naming and documentation for v1.3.0.

## [1.2.1] - 2026-07-02

- Added in-app update checker.
- Added direct Android APK download flow.
- Added SHA256 validation when a release checksum is available.
- Improved update error handling and Android installer handoff.

## [1.2.0] - 2026-07-02

- Improved security and release hygiene.
- Hardened local app lock behavior.
- Added PIN failed-attempt cooldown.
- Improved backup validation and restore safety.
- Added release signing configuration for local keystore use.
- Updated public documentation for APK verification and offline trust model.

## [1.1.0] - 2026-07-02

- Added offline transactions, wallets, categories, budgets, analytics, backup, and settings.
- Added PIN lock, optional biometric unlock, and hide balance.
- Added MIT License.
