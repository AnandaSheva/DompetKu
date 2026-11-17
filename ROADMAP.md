# Roadmap

DompetKu is developed as a connected personal finance app for Android and web. Both platforms must share account data, financial rules, and core features through Google sign-in and Firebase Firestore.

Web currently implements Firebase account storage. Android account integration and cross-platform synchronization still require implementation and verification.

## Near Term

- Configure Firebase and Google sign-in for Android using the existing account model
- Connect Android repositories to the same UID-scoped Firestore datasets as web
- Migrate existing device data only after a saved backup, visible destination account, and explicit user action
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
