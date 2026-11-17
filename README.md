<p align="center">
  <img src="assets/icons/app_icon.png" width="96" alt="DompetKu logo">
</p>

<h1 align="center">DompetKu</h1>

<p align="center">
  Connected personal finance tracking for Android and web, with shared account data.
</p>

<p align="center">
  DompetKu brings income, expenses, wallets, budgets, and financial planning into one account across devices.
</p>

<p align="center">
  <a href="https://github.com/AnandaSheva/DompetKu/actions/workflows/flutter-ci.yml"><img alt="Flutter CI" src="https://img.shields.io/github/actions/workflow/status/AnandaSheva/DompetKu/flutter-ci.yml?branch=main&style=flat-square&label=Flutter%20CI"></a>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white">
  <img alt="Android and Web" src="https://img.shields.io/badge/Android-Web-3DDC84?style=flat-square&logo=android&logoColor=white">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/License-MIT-blue?style=flat-square"></a>
  <a href="https://github.com/AnandaSheva/DompetKu/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/AnandaSheva/DompetKu?style=flat-square"></a>
  <img alt="Connected finance" src="https://img.shields.io/badge/Finance-connected-2563EB?style=flat-square">
</p>

## Product Direction and Implementation Status

Android and web are equal product platforms. Development must use Google sign-in, the same Firebase UID and Firestore dataset, consistent financial rules, and synchronization across devices. Device storage supports caching, device preferences, and safe migration of existing data.

Web already implements Firebase Authentication and Firestore. Android still uses the existing Drift data path; its Firebase configuration, sign-in, account repositories, and data migration require implementation and testing. This documentation update defines the shared direction; it does not deliver Android synchronization. See [the integration guide](docs/firebase-web.md) and [ROADMAP.md](ROADMAP.md).

## Branding and Compatibility

The app is now named **DompetKu**, with Dart package `dompet_sheva`.
The Android application ID, native update channel, database name, and backup format remain compatible with existing installations. Updating an existing installation requires the same signing key.

The GitHub repository and update endpoint still use the existing repository URL. Historical release notes, published APK filenames, and screenshots in `docs/` describe earlier releases; they have not been rewritten as new releases. The wallet icon uses the blue brand palette. Run `scripts/render-brand-icons.ps1` on Windows to render the SVG sources, then `dart run flutter_launcher_icons` to regenerate Android launchers.

## Features

- Income and expense tracking
- Wallet management
- Transfer between wallets
- Monthly budgets
- Recurring bill schedules with confirmed expense recording
- Savings goals with manual progress and optional deadlines
- Analytics and summaries
- Local app lock with PIN and optional biometric unlock
- Backup and restore for moving data between phones
- CSV transaction export
- In-app update checker with direct APK download
- Google sign-in and account data synchronization on web; Android integration is planned

## Tagihan dan Target Tabungan

Buka **Tagihan** atau **Target tabungan** dari Beranda, atau
**Tagihan & Target Tabungan** dari Pengaturan. Jadwal tagihan mendukung
pengulangan mingguan, bulanan, dan tahunan. Pilih **Catat pembayaran** setelah
membayar untuk membuat satu transaksi pengeluaran dan memajukan satu periode.
**Lewati periode** hanya memajukan jadwal; tagihan juga dapat dijeda atau diedit.
Transaksi pengeluaran yang sudah ada dapat dijadikan jadwal untuk periode berikutnya.
Tanggal 29?31 mengikuti hari terakhir bulan pendek dan kembali ke tanggal asal
pada bulan yang mendukungnya.

Target tabungan menyimpan nominal tujuan, tenggat opsional, dan jumlah terkumpul
yang diperbarui manual. Progres tidak memindahkan uang atau mengubah saldo dompet.
Kedua fitur disertakan dalam backup JSON; backup lama tetap bisa dipulihkan.
Android menampilkan jadwal di aplikasi. Di web/PWA, pengingat bersifat opsional.
Rekomendasi awal menyediakan pilihan **Aktifkan** atau **Nanti saja**. Sakelar
**Notifikasi tagihan** di Pengaturan atau halaman Tagihan dapat diubah kapan saja.
Izin browser hanya diminta saat pengguna memilih aktif. Pengingat H-1 dan
hari H diperiksa saat DompetKu dibuka/aktif dan data akun selesai tersinkron;
pengingat tidak berjalan saat aplikasi ditutup. Tidak ada pembayaran otomatis.

## Privacy Model

- Shared target for Android and web: Google sign-in and financial data scoped to the authenticated Firebase UID
- No ads
- No analytics or tracking
- Account financial data is stored in Google Firebase; device caches and existing data need careful handling during migration and logout
- Backup files contain financial data and should be stored safely

The connected design uses the internet for Firebase Authentication and Firestore synchronization on both platforms, alongside supported user-triggered updates, downloads, external links, and sharing. Persistent browser cache requires trusted-device consent. Device caches and backup files are not full database encryption. Android account support remains pending as described above. See [setup and verification](docs/firebase-web.md).

## Download

Download the latest Android APK from GitHub Releases:

https://github.com/AnandaSheva/DompetKu/releases/

For most modern Android phones, use the `arm64` APK.

APK naming for future DompetKu releases (replace `{VERSION}` with the release version):

```txt
DompetSheva-v{VERSION}-arm64.apk
```

APK files installed from GitHub are sideloaded. Android or Play Protect may show a warning because the app is not installed from the Play Store.

## Verify APK

If a release provides a SHA256 checksum, verify the downloaded APK before installing it.

PowerShell:

```powershell
Get-FileHash '.\DompetSheva-v{VERSION}-arm64.apk' -Algorithm SHA256
```

SHA256 tersedia di halaman GitHub Release.

## Build From Source

Requirements:

- Flutter stable
- Android SDK
- Java 17

Commands:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

Release signing uses a local keystore. Do not commit `android/key.properties`, `.jks`, or `.keystore` files.

For release publishing steps, see [docs/release-checklist.md](docs/release-checklist.md).

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

## Project Structure

```txt
lib/app       App bootstrap, theme, and providers
lib/core      Constants, enums, formatters, and helpers
lib/data      Account storage, Drift database, repositories, backup, security, updates
lib/features  Feature-first UI modules
lib/shared    Shared layouts, widgets, and components
test          Unit and widget tests
android       Android host project
web           Browser host project
```

## Roadmap

- Android Google sign-in and Firebase account integration
- Shared Android/web data synchronization and safe migration of existing device data
- Cross-platform account isolation and synchronization tests
- UI polish
- Backup encryption
- Better data export
- Optional database encryption
- More tests
- Possible Play Store distribution

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## AI-Assisted Development

DompetKu includes repository-level instructions for AI-assisted development. AI-generated changes must follow the same standards as human contributions: small scope, no secrets, no unnecessary permissions, and passing checks.

- [AGENTS.md](AGENTS.md)
- [AI-assisted development guide](docs/ai-assisted-development.md)

## Automated Checks

The repository uses GitHub Actions for Flutter analyze/test checks, Dependabot for dependency updates, and CodeQL for scheduled Android host-code scanning.

## Security

See [SECURITY.md](SECURITY.md).

## Support Development

If DompetKu helps you, you can support its ongoing development here:

https://tako.id/shevaanandaa/gift

## License

DompetKu is released under the [MIT License](LICENSE).

Copyright (c) 2026 Sheva.
