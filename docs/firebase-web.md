# DompetKu Web: Google sign-in dan Firestore

Android tetap offline dengan Drift. Web memakai Firebase Authentication dan
Firestore pada paket Spark, tanpa Firebase Analytics, Cloud Functions, atau
Cloud Storage. Hosting aplikasi tetap Vercel.

Karena dependency Flutter Firebase juga menyertakan SDK Android, manifest Android
secara eksplisit menolak initializer Firebase serta izin transitive
`ACCESS_NETWORK_STATE` dan `READ_GSERVICES`. Tidak ada izin Android baru yang
dibutuhkan untuk fitur web ini.

## Setup Firebase

1. Buat proyek Spark dan database Firestore Standard `(default)`. Proyek yang
   dikonfigurasi checkout ini adalah `dompetku-web-f8e4e`, lokasi Jakarta.
2. Aktifkan Google di Authentication, lalu isi support email.
3. Tambahkan `localhost` dan domain produksi pada Authorized domains.
4. Jalankan `firebase login`, `dart pub global activate flutterfire_cli`, lalu
   `flutterfire configure --platforms=web` dari root proyek.
5. Terapkan rules dan indexes dengan:

   ```powershell
   firebase deploy --project dompetku-web-f8e4e --only 'firestore:rules,firestore:indexes'
   ```

`firebase_options.dart` berisi konfigurasi klien publik. Jangan menambahkan
service account JSON, private key, token, password Google, atau kredensial admin
ke aplikasi maupun repository. `measurementId` dari konfigurasi FlutterFire
tidak mengaktifkan Analytics: aplikasi tidak mengimpor plugin Analytics.

## Login dan cache

- `/login` menampilkan Google login dengan COOP `same-origin-allow-popups`.
- Setelah login, aplikasi kembali ke `/`. Header COOP/COEP di halaman ini
  mempertahankan akses database Drift lama, termasuk OPFS, untuk migrasi.
- Sesi diperiksa sebelum repository akun dibuat. UID yang berbeda memiliki
  ProviderScope dan Navigator berbeda; layar akun lama dibuang saat berganti akun.
- Pilihan perangkat pribadi mengaktifkan sesi lokal dan cache Firestore persisten.
  Tanpa pilihan tersebut, sesi memakai session storage dan cache data berada di memori.
- Menutup tab saat offline pada perangkat bersama dapat membuang perubahan yang
  belum tersinkron. Status sinkronisasi dan peringatan sebelum meninggalkan halaman
  membantu pengguna mengunduh cadangan terlebih dahulu.
- Pada perangkat pribadi, antrean perubahan tambahan disimpan berdasarkan UID
  agar kegagalan server seperti kuota habis dapat dicoba ulang setelah refresh.
- Logout menunggu semua perubahan, menghentikan listener, lalu mencoba membersihkan
  cache Firestore. Tab lain dapat menghalangi pembersihan; pengguna mendapat pesan
  untuk menutup tab lain dan menghapus data situs bila menggunakan perangkat bersama.
- Jika sinkronisasi belum berhasil, pengguna dapat mengunduh cadangan, mengonfirmasi
  file sudah tersimpan, lalu memilih keluar dan membersihkan perubahan lokal.
- Cache browser bukan enkripsi penuh. Login baru dan pengisian cache memerlukan
  internet; cache data tidak menjamin seluruh aplikasi dapat dimuat saat cold start offline.

## Data, restore, dan migrasi

Profil: `users/{uid}`. Data aktif:

```text
users/{uid}/datasets/{activeDataset}/wallets/{id}
users/{uid}/datasets/{activeDataset}/categories/{id}
users/{uid}/datasets/{activeDataset}/transactions/{id}
users/{uid}/datasets/{activeDataset}/budgets/{id}
users/{uid}/datasets/{activeDataset}/quick_templates/{id}
users/{uid}/datasets/{activeDataset}/settings/1
```

ID baru adalah integer acak yang aman untuk JavaScript. Nilai Rupiah selalu
integer. Satu listener per koleksi dibagikan ke semua repository. Perhitungan
saldo dan transfer menggunakan logika yang sama dengan Android.

Restore/reset membutuhkan internet. Data diunggah ke dataset baru dalam batch
maksimal 400 dokumen. Pointer akun beralih secara atomik setelah semua batch
berhasil. Dataset sebelumnya baru dibersihkan setelah peralihan sukses;
`retiredDatasets` menyimpan pekerjaan pembersihan yang perlu dicoba kembali.
Kegagalan staging tidak mengubah dataset aktif. Upload staging yang terputus
sebelum aktivasi dapat meninggalkan dokumen yang perlu diperiksa dan dibersihkan
oleh pemilik proyek Firebase; jangan menghapus dataset yang sedang aktif.

Migrasi database browser lama bersifat eksplisit: akun tujuan ditampilkan,
pengguna mengunduh dan mengonfirmasi backup JSON, kemudian memilih pindahkan.
Database lama tidak dihapus. Browser mengikat database lama ke UID yang dipilih
agar akun lain tidak ditawari data tersebut. Fingerprint migrasi di Firestore
mencegah impor ulang yang menggandakan data. Akun yang sudah digunakan memakai
alur impor cadangan dengan konfirmasi penggantian, bukan penggabungan otomatis.

Saat memulihkan/reset dari perangkat lain, sinkronkan dan buat cadangan pada semua
perangkat dahulu. Edit bersamaan pada dokumen yang sama memakai perilaku last-write-wins
Firestore; tidak ada penyelesaian konflik manual. Riwayat aktif saat ini dimuat sekali
per sesi untuk perhitungan lokal; akun besar memerlukan optimasi ringkasan/pagination.

## Pengujian lokal

```powershell
flutter pub get
flutter analyze
flutter test
npm --prefix tools/firestore-tests ci
firebase emulators:exec --project demo-dompetku --only 'firestore,auth' 'npm --prefix tools/firestore-tests test'
firebase emulators:exec --project demo-dompetku --only 'firestore,auth' 'flutter test --platform chrome test/web/cloud_store_test.dart'
```

Emulator membutuhkan Java 21 atau lebih baru yang didukung Firebase CLI. Pada
Windows, JBR Android Studio dapat dipakai melalui `JAVA_HOME`. Chrome diperlukan
untuk tes browser. Semua tes integrasi memakai proyek `demo-dompetku` dan akun
sementara emulator, tidak menyentuh data produksi.

Untuk menjalankan aplikasi dengan emulator, mulai Auth/Firestore Emulator,
lalu `flutter run -d chrome --dart-define=FIREBASE_EMULATORS=true`. Flag tersebut
hanya digunakan pada debug build; release selalu menggunakan konfigurasi proyek.

## Deploy dan verifikasi

```powershell
flutter build web --release --no-web-resources-cdn
```

Vercel menjalankan `bash scripts/vercel-build.sh` dan melayani `build/web`.
Deploy rules/indexes Firebase terpisah dari deploy Vercel. Gunakan domain produksi
yang stabil dan pastikan `/login` mendapat header khusus dari `vercel.json`.
Jangan menyalin header isolasi halaman `/` ke `/login`, karena popup OAuth perlu
berkomunikasi dengan halaman pembukanya.

Uji hasil deployment di browser desktop dan mobile:

- Refresh tanpa sesi menampilkan login; sesi aktif membuka data akun.
- Login dibatalkan, popup diblokir, domain tidak diizinkan, dan koneksi gagal
  memberi pesan yang jelas.
- Akun A dan B tidak saling membaca data, termasuk setelah logout/berganti akun.
- Perubahan muncul di perangkat lain setelah status tersimpan di cloud.
- Transaksi offline tampil lokal, kemudian tersinkron saat internet kembali.
- Transfer tidak mengubah total pemasukan/pengeluaran.
- Impor invalid tidak menghapus data, impor besar selesai atomik, dan migrasi
  yang dicoba ulang tidak membuat duplikasi.
- `sqlite3.wasm` tetap merupakan WASM dengan MIME `application/wasm`, bukan HTML
  hasil SPA rewrite, agar pembacaan database lama bekerja.

Spark tidak menagih penggunaan berlebih; layanan dibatasi saat kuota berlaku
terlampaui. Pantau penggunaan per proyek di Firebase Console. Kuota gratis dan
ketentuan layanan dapat berubah; periksa dokumentasi resmi sebelum rilis.

Referensi: [Flutter setup](https://firebase.google.com/docs/flutter/setup),
[Google login](https://firebase.google.com/docs/auth/flutter/federated-auth),
[Firestore offline](https://firebase.google.com/docs/firestore/manage-data/enable-offline),
[quotas](https://firebase.google.com/docs/firestore/quotas),
[Drift web storage](https://drift.simonbinder.eu/platforms/web/).
