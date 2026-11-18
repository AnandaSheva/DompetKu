# Roadmap

DompetKu is developed as a connected personal finance app for Android and web. Both platforms must share account data, financial rules, and core features through Google sign-in and Firebase Firestore.

Android and web now use the shared Firebase account path in source, including native Google sign-in, explicit legacy-data migration, and Android bill alarms. Device verification and publication remain separate release steps.

## Near Term

- Verify native Google sign-in on debug and release-signed Android builds
- Verify Android/web synchronization and safe migration of existing device data
- Verify notification permission, app closure, reboot, account switching, and battery-saving behavior on Android
- Align account, synchronization, retry, and error states across Android and web
- Verify Android/web synchronization, account isolation, concurrent edits, pending writes, logout, and restore using Firebase emulators and test accounts
- UI polish and accessibility fixes
- More repository and regression tests
- Better release notes and APK verification flow
- Export and backup UX improvements

## Later

- Backup encryption
- Optional database encryption
- More flexible reports
- More complete import validation
- Possible Play Store distribution

Google sign-in and synchronized account data are core product requirements on both platforms. Keep Firebase usage within the Spark plan without automatically enabling billing. Ads, analytics, tracking, and custom backend services are outside the product scope.
