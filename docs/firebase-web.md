# DompetKu: Integrasi Akun Android dan Web

Target pengembangan Android dan web adalah satu aplikasi keuangan dengan login
Google, Firebase UID, dataset Firestore, dan aturan keuangan yang sama. Gunakan
layanan Firebase pada paket Spark tanpa mengaktifkan billing otomatis, Firebase
Analytics, Cloud Functions, atau Cloud Storage. Hosting web tetap Vercel.

## Status implementasi

Android dan web memakai gerbang akun dan `CloudFinanceStore` yang sama. Android
memakai plugin resmi `google_sign_in` untuk mendapatkan ID token, kemudian
Firebase Authentication membuka sesi dengan UID yang sama seperti web.
Bootstrap menyiapkan penyimpanan sesi dan Firebase sebelum repository akun dibuat.

Data Drift perangkat lama tetap dipertahankan dan ditawarkan untuk migrasi setelah
cadangan tersimpan serta akun tujuan dikonfirmasi. Jika akun Android sudah berisi
data, penggantian membutuhkan konfirmasi tambahan. Logout menunggu penulisan,
membatalkan pengingat, lalu membersihkan cache akun. Perubahan tertunda Android
disimpan per akun untuk pemulihan; penyimpanan perangkat bukan enkripsi database penuh.

Implementasi dan build lokal tidak menggantikan verifikasi login Google nyata,
migrasi, pergantian akun, dan pengiriman notifikasi pada perangkat sebelum publikasi.

## Kontrak integrasi bersama

- Login Google harus selesai sebelum repository akun dibuat pada kedua platform.
- UID yang sama membuka dataset Firestore yang sama; UID berbeda tidak boleh
  saling membaca data, cache, antrean perubahan, atau state layar.
- Gunakan `FinanceStore`, repository, perhitungan saldo, dan aturan transfer yang
  sama. Pertahankan satu listener bersama per koleksi akun.
- Tampilkan data cache, perubahan tertunda, berhasil tersinkron, dan gagal dengan
  jelas. Pemulihan koneksi dan percobaan ulang tidak boleh menggandakan transaksi.
- Logout menunggu sinkronisasi; pembuangan perubahan memerlukan cadangan dan
  konfirmasi eksplisit. Pergantian akun membuang state dan listener akun lama.
- Migrasi data perangkat lama harus menampilkan akun tujuan, menyimpan cadangan,
  dan menunggu tindakan eksplisit pengguna. Dataset aktif tidak diganti sebelum
  staging berhasil sepenuhnya.
- Uji dengan Firebase emulators dan akun uji, bukan data keuangan produksi.

## Konfigurasi dan build Android

Aplikasi Firebase Android terdaftar pada proyek `dompetku-web-f8e4e` dengan
application ID `com.sheva.dompetku` dan Firebase app ID
`1:837744778374:android:64e958087a88fe169c0507`. Sertifikat debug dan rilis yang
tersedia di checkout saat implementasi telah didaftarkan. Daftarkan SHA1/SHA256
kembali bila kunci build berubah; jangan mengganti application ID atau kunci rilis.

Isi tiga nilai berikut hanya dalam `.env.local`, mengikuti `.env.example`:

- `FIREBASE_ANDROID_API_KEY`: API key klien Android dari konfigurasi Firebase.
- `FIREBASE_ANDROID_APP_ID`: Firebase app ID Android di atas.
- `GOOGLE_SERVER_CLIENT_ID`: OAuth client ID bertipe Web dari proyek yang sama.

Firebase diinisialisasi secara eksplisit di Dart, sehingga konfigurasi ini tidak
memerlukan `google-services.json` atau plugin Gradle Google Services. Jangan
menulis API key ke source. Nilai klien tetap berada dalam APK hasil build;
otorisasi data bergantung pada Firebase Auth dan Security Rules.

```powershell
flutter run -d <android-device-id> --dart-define-from-file=.env.local
flutter build apk --debug --dart-define-from-file=.env.local
.\scripts\build-apk.ps1
```

Script rilis memerlukan konfigurasi Firebase dan kunci rilis lokal. APK debug hanya
untuk pengujian. Jangan aktifkan `DEBUG` pada shell Gradle karena wrapper dapat
mencetak argumen build yang berisi nilai klien.

Untuk emulator Android, mode debug mendukung `FIREBASE_EMULATORS=true` dan
`FIREBASE_EMULATOR_HOST` (default `10.0.2.2`; browser memakai `127.0.0.1`). Gunakan
Auth/Firestore Emulator dan akun uji. Login Google nyata tetap membutuhkan
konfigurasi OAuth serta pengujian perangkat; jangan gunakan data keuangan produksi.

## Setup Firebase web yang tersedia

1. Buat proyek Spark dan database Firestore Standard `(default)`. Proyek yang
   dikonfigurasi checkout ini adalah `dompetku-web-f8e4e`, lokasi Jakarta.
2. Aktifkan Google di Authentication, lalu isi support email.
3. Tambahkan `localhost` dan domain produksi pada Authorized domains.
4. Jalankan `firebase login`, `dart pub global activate flutterfire_cli`, lalu
   `flutterfire configure --platforms=web` dari root proyek jika konfigurasi
   perlu dibuat ulang. Generator dapat menulis API key langsung ke source;
   pertahankan `String.fromEnvironment('FIREBASE_WEB_API_KEY')` pada `apiKey`
   sebelum menyimpan perubahan ke Git.
5. Terapkan rules dan indexes dengan:

   ```powershell
   firebase deploy --project dompetku-web-f8e4e --only 'firestore:rules,firestore:indexes'
   ```

`firebase_options.dart` berisi konfigurasi klien publik dengan API key dari
build environment, tanpa nilai API key yang ditulis langsung ke repository.
Jangan menambahkan
service account JSON, private key, token, password Google, atau kredensial admin
ke aplikasi maupun repository. `measurementId` dari konfigurasi FlutterFire
tidak mengaktifkan Analytics: aplikasi tidak mengimpor plugin Analytics.

Untuk menjalankan web secara lokal, salin `.env.example` menjadi `.env.local`
dan isi `FIREBASE_WEB_API_KEY` hanya di file lokal tersebut. `.env.local` sudah
diabaikan Git dan tidak dimasukkan sebagai asset Flutter.

```powershell
flutter run -d chrome --dart-define-from-file=.env.local
```

Firebase web tetap membutuhkan API key di browser, sehingga key dapat dibaca
dari bundle hasil build atau request jaringan. Environment variable mencegah
nilai key tersimpan di source repository; perlindungan data tetap menggunakan
Firestore Security Rules dan kepemilikan UID. Terapkan pembatasan API yang sesuai
pada key di Google Cloud Console. Menghapus key dari source saat ini tidak
menghapusnya dari riwayat commit lama.

## Login dan cache

- `/login` menampilkan Google login dengan COOP `same-origin-allow-popups`.
- Penyimpanan sesi disiapkan sebelum tombol Google aktif dan setiap pilihan
  perangkat pribadi berubah. Popup dipanggil langsung dari ketukan pengguna,
  tanpa menunggu operasi penyimpanan yang dapat membuat Safari/iOS atau PWA
  Android memblokirnya. Jika persiapan gagal, login tetap dinonaktifkan sampai
  pengguna berhasil mencoba lagi.
- Setelah login, aplikasi kembali ke `/`. Header COOP/COEP di halaman ini
  mempertahankan akses database Drift lama, termasuk OPFS, untuk migrasi.
- Sesi diperiksa sebelum repository akun dibuat. UID yang berbeda memiliki
  ProviderScope dan Navigator berbeda; layar akun lama dibuang saat berganti akun.
- Pilihan perangkat pribadi mengaktifkan sesi lokal dan cache Firestore persisten.
  Tanpa pilihan tersebut, sesi memakai session storage dan cache data berada di memori.
- Menutup tab saat koneksi terputus pada perangkat bersama dapat membuang perubahan yang
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
  internet; cache data tidak menjamin seluruh aplikasi dapat dimuat saat dibuka ulang tanpa koneksi.

## Data, restore, dan migrasi

Profil: `users/{uid}`. Data aktif:

```text
users/{uid}/datasets/{activeDataset}/wallets/{id}
users/{uid}/datasets/{activeDataset}/categories/{id}
users/{uid}/datasets/{activeDataset}/transactions/{id}
users/{uid}/datasets/{activeDataset}/budgets/{id}
users/{uid}/datasets/{activeDataset}/recurring_bills/{id}
users/{uid}/datasets/{activeDataset}/savings_goals/{id}
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

Pada Flutter 3.47.9 di Windows, runner Chrome dapat berhenti saat pemuatan karena
resource CanvasKit 404 dan selector path tes bertingkat. Kondisi ini tidak berarti
tes lulus; periksa konsol browser dan ulangi integrasi pada runner yang berfungsi.
Tes unit/widget dan tes rules emulator tetap merupakan pemeriksaan terpisah.

Emulator membutuhkan Java 21 atau lebih baru yang didukung Firebase CLI. Pada
Windows, JBR Android Studio dapat dipakai melalui `JAVA_HOME`. Chrome diperlukan
untuk tes browser. Semua tes integrasi memakai proyek `demo-dompetku` dan akun
sementara emulator, tidak menyentuh data produksi.

Untuk menjalankan aplikasi dengan emulator, mulai Auth/Firestore Emulator,
lalu `flutter run -d chrome --dart-define=FIREBASE_EMULATORS=true`. Flag tersebut
hanya digunakan pada debug build; release selalu menggunakan konfigurasi proyek.

## Deploy dan verifikasi

```powershell
flutter build web --release --no-web-resources-cdn --dart-define-from-file=.env.local
```

Vercel menjalankan `bash scripts/vercel-build.sh` dan melayani `build/web`.
Sebelum deploy, tambahkan `FIREBASE_WEB_API_KEY` di Project Settings > Environment
Variables untuk environment Production dan Preview yang digunakan, lalu deploy
ulang. Masukkan nilainya melalui dashboard Vercel, bukan `vercel.json` atau
repository. Build dihentikan jika variable belum diisi; script tidak mencetak
nilainya ke log.
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
- Transaksi dengan koneksi terputus berstatus tertunda, lalu tersinkron saat internet kembali tanpa duplikasi.
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
[Firestore data](https://firebase.google.com/docs/firestore/manage-data),
[quotas](https://firebase.google.com/docs/firestore/quotas),
[Drift web storage](https://drift.simonbinder.eu/platforms/web/).


## Jadwal tagihan dan target tabungan

Deploy `firestore.rules` yang menyertakan koleksi `recurring_bills` dan
`savings_goals` sebelum merilis integrasi kedua platform dengan fitur ini. Rules versi lama
menolak akses koleksi baru. Gunakan pengujian emulator di atas terlebih dahulu.

Kedua koleksi tetap berada di dataset UID pemilik dengan satu listener bersama
per koleksi. Tanggal jatuh tempo dan tenggat disimpan sebagai hari kalender UTC
agar tidak bergeser ketika akun dibuka dari zona waktu lain. Pembayaran tagihan
memerlukan internet dan memakai transaksi server dengan pemeriksaan versi untuk
membuat pengeluaran dan memajukan jadwal secara atomik. ID transaksi
stabil per tagihan dan tanggal jatuh tempo mencegah dua dokumen pembayaran untuk
periode yang sama. Perangkat dengan jadwal lama ditolak tanpa menimpa pembayaran
atau memundurkan jadwal. Saat koneksi terputus, jadwal baru dan target memakai
antrean perubahan dan belum dianggap tersimpan di server hingga sinkronisasi berhasil.
Edit tagihan, jeda/aktifkan, dan lewati periode juga memakai pemeriksaan
versi server dan memerlukan internet. Perubahan bersamaan pada target dan
transaksi biasa tetap mengikuti kebijakan last-write-wins yang sudah digunakan
aplikasi.

Target tabungan mencatat progres manual dan tidak mengubah saldo dompet. Backup,
pemulihan melalui staging, dan reset menyertakan kedua koleksi.

## Notifikasi tagihan web/PWA

Pada akses awal setelah akun siap, rekomendasi menyediakan pilihan **Aktifkan**
atau **Nanti saja**. Pengingat opsional; melewati atau menutup popup tidak meminta
izin browser. Rekomendasi ditandai per akun di browser agar tidak muncul berulang.
Penanda memakai penyimpanan lokal hanya pada perangkat pribadi; perangkat bersama
memakai sesi browser. Menghapus penyimpanan browser dapat memunculkan rekomendasi lagi.

Buka **Pengaturan > Notifikasi tagihan**, atau halaman **Tagihan**, lalu gunakan
sakelar yang sama untuk mengaktifkan atau menonaktifkan pengingat. Pilih **Izinkan**
pada permintaan browser. Izin hanya diminta setelah pengguna memilih aktif.
Gunakan HTTPS (localhost dapat dipakai untuk
pengujian). Pada iPhone/iPad yang mendukung notifikasi web, tambahkan aplikasi ke
Layar Utama dan buka melalui ikon tersebut. Jika izin ditolak, ubah pengaturan
notifikasi situs/perangkat, lalu tekan sakelar dan **Periksa izin** pada popup bantuan.

Pengingat memeriksa jadwal aktif yang belum dibayar pada H-1 dan hari H menurut
tanggal perangkat. Pemeriksaan dilakukan saat data berubah, aplikasi kembali
aktif, dan setiap menit selama halaman berjalan. Pengingat menunggu snapshot akun
yang selesai tersinkron; data cache, antrean penulisan, atau kesalahan sinkronisasi
tidak dipakai untuk mengirim pengingat. Jadwal kalender yang hanya berupa proyeksi,
tagihan dijeda, dan jadwal yang sudah dimajukan setelah bayar/lewati tidak dikirim.

Fitur ini tidak memakai backend, Web Push, Cloud Functions, atau langganan push.
Service worker khusus notifikasi memakai cakupan `notification-reminders/` agar
tidak mengganti worker aplikasi Flutter. Browser dapat menunda eksekusi tab latar;
tidak ada jaminan pengingat saat tab/PWA ditutup. Izin browser saja tidak membuat
penjadwal latar belakang.

Isi notifikasi hanya menyebut jumlah tagihan dan hari jatuh tempo, tanpa nama,
nominal, atau kredensial Google. Preferensi dan penanda pengiriman per akun memakai
hash, tanpa menyalin data tagihan. Perangkat pribadi menyimpan penanda di penyimpanan
lokal browser; pilihan perangkat bersama memakai sesi browser. Penanda mencegah
pengingat tagihan/periode/hari yang sama dikirim berulang; menghapus penyimpanan
browser dapat menghapus penanda ini. Notifikasi ditutup saat pengingat dinonaktifkan
atau sesi akun berakhir. Ketukan notifikasi membuka halaman Tagihan hanya untuk
akun yang sesuai. Bagian ini menjelaskan pengingat web/PWA yang sudah ada;
pengingat native mengikuti kemampuan Android dan perlu diverifikasi tersendiri.

## Pengingat native Android

Pengingat bersifat opsional dan memakai sakelar yang sama di Pengaturan serta
halaman Tagihan. Android 13+ meminta `POST_NOTIFICATIONS` hanya setelah pengguna
memilih aktif. `RECEIVE_BOOT_COMPLETED` memulihkan jadwal setelah reboot; akses
status jaringan mengikuti SDK Firebase. Tidak ada izin alarm presisi, akses file
luas, layanan foreground, push server, atau backend tambahan.

Jadwal berasal dari snapshot akun yang selesai tersinkron. Setiap tagihan aktif
hanya menyumbang periode berikutnya yang belum dibayar, dengan pengingat H-1 dan
hari H sekitar pukul 09.00 waktu perangkat. Alarm memakai `setAndAllowWhileIdle`
yang tidak presisi: Android dan penghematan baterai dapat menunda pengiriman.
Jadwal dipulihkan setelah reboot, pembaruan paket, atau perubahan zona waktu.

Hanya hash akun/periode, tanggal, dan jumlah tagihan yang masuk ke penjadwal.
Notifikasi tidak menyebut nama tagihan, nominal, atau kredensial. Pembayaran,
lewati periode, jeda, penggantian dataset, penonaktifan, dan logout memperbarui atau
membatalkan alarm. Ketukan membuka halaman Tagihan untuk akun yang sesuai dan
seluruh Navigator tetap dilindungi app lock.

Alarm dapat berjalan ketika aplikasi ditutup berdasarkan jadwal tersinkron terakhir.
Perubahan dari perangkat lain saat proses Android tidak berjalan baru diterapkan
ketika aplikasi dibuka dan tersinkron kembali. Tidak ada sinkronisasi latar belakang
terpisah. Force stop dan pembatasan baterai vendor dapat menghentikan pengingat;
buka kembali aplikasi untuk memulihkan jadwal.
