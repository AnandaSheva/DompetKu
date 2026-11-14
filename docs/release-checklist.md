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

On Windows, use the release script after running the checks above. Set `JAVA_HOME` to your JDK (Android Studio's `jbr` also works), or make sure `java` is on `PATH`, so the script can run `apksigner`.

```powershell
.\scripts\build-apk.ps1
```

The script reads the version and build number from `pubspec.yaml`, rebuilds all ABI APKs, and checks each APK's actual `versionName`, `versionCode`, application ID, and release signature before copying it. It rejects debug signatures and writes named APKs plus `SHA256SUMS.txt` to `build/releases/{VERSION}+{BUILD}/`. Upload files from this folder.

An APK filename and GitHub tag do not change the installed Android version. Never rename or upload an older APK as a newer release. If the installed `versionName` is older than the tag, the app will keep offering the same update after installation.

For a manual build on other platforms:

```bash
flutter build apk --release --split-per-abi
```

Expected APK outputs:

- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`

## Rename APKs

Skip this step when using `scripts/build-apk.ps1`. For manual builds, first inspect the generated APK manifest with Android SDK `aapt dump badging` or `apkanalyzer manifest version-name` and confirm it matches `pubspec.yaml` and the intended GitHub tag. Check the build number and release signature too.

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

- Confirm the APK's internal version, `pubspec.yaml`, and release tag are identical, and its build number is higher than the previous release for the same ABI.
- Upload APK files to GitHub Releases.
- Push tag `v{VERSION}`.
- Create GitHub Release `DompetKu v{VERSION}`.
- Include a short changelog.
- Include SHA256 checksums.
- Include SHA256 in release notes.
- Mark the release as latest when appropriate.
- Download the `arm64` APK from the release and smoke test install on Android.
- Open Settings and confirm the installed version matches the release. Check for updates again; the app must report that it is already up to date.
