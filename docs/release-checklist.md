# Release Checklist

Use this checklist before publishing a DompetKu GitHub Release. Replace `{VERSION}` with the version from `pubspec.yaml`, without the `+build` suffix, throughout this checklist.

## Before Build

- Confirm `pubspec.yaml` has the intended version and an increased build number.
- Use the same Android application ID and release signing key as the installed version when publishing an update.
- Run `flutter pub get`.
- Run `flutter analyze`.
- Run `flutter test`.
- Confirm release build passed.
- Confirm `android/key.properties` exists locally.
- Confirm no keystore or signing secrets are staged.

## Build

```bash
flutter build apk --release --split-per-abi
```

Expected APK outputs:

- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`

## Rename APKs

Use release-friendly names:

```txt
DompetSheva-v{VERSION}-armeabi-v7a.apk
DompetSheva-v{VERSION}-arm64.apk
DompetSheva-v{VERSION}-x86_64.apk
```

PowerShell:

```powershell
Copy-Item "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "build\app\outputs\flutter-apk\DompetSheva-v{VERSION}-arm64.apk"
Copy-Item "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" "build\app\outputs\flutter-apk\DompetSheva-v{VERSION}-armeabi-v7a.apk"
Copy-Item "build\app\outputs\flutter-apk\app-x86_64-release.apk" "build\app\outputs\flutter-apk\DompetSheva-v{VERSION}-x86_64.apk"
```

## Generate SHA256

PowerShell:

```powershell
Get-FileHash '.\DompetSheva-v{VERSION}-arm64.apk' -Algorithm SHA256
```

Add checksums to the GitHub Release notes.

## Publish

- Upload APK files to GitHub Releases.
- Push tag `v{VERSION}`.
- Create GitHub Release `DompetKu v{VERSION}`.
- Include a short changelog.
- Include SHA256 checksums.
- Include SHA256 in release notes.
- Mark the release as latest when appropriate.
- Download the `arm64` APK from the release and smoke test install on Android.
