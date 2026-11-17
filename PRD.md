# DompetKu PRD

## 1. Product Overview

**DompetKu** adalah aplikasi pengelolaan keuangan pribadi untuk Android dan web dengan data akun yang terhubung dan tersinkron antarperangkat.

DompetKu dibuat untuk mencatat pemasukan, pengeluaran, dompet, dan budget sehari-hari melalui akun Google yang sama di Android maupun web, dengan proses yang sederhana.

Fokus DompetKu adalah membantu pengguna memahami kondisi uang pribadi secara cepat melalui data akun terhubung: saldo tersisa, pemasukan bulan ini, pengeluaran bulan ini, kategori paling boros, budget, dan riwayat transaksi.

Aplikasi harus terasa **simple, elegant, premium, cepat, stabil, terhubung, dan iOS-like**, serta nyaman digunakan di Android dan browser.

Dokumen ini menetapkan target pengembangan bersama untuk kedua platform. Integrasi Firebase sudah tersedia pada web; konfigurasi Firebase, login, repository akun, dan migrasi data Android masih perlu diimplementasikan dan diuji sebelum dinyatakan tersedia.

---

## 2. Product Vision

Membuat aplikasi pengelola keuangan pribadi yang terasa seperti aplikasi bawaan sistem modern: ringan, cepat, bersih, visualnya elegan, dan tidak membuat pengguna malas mencatat transaksi.

DompetKu harus membantu pengguna menjawab pertanyaan utama dalam beberapa detik:

- Uang saya sekarang tersisa berapa?
- Bulan ini saya sudah keluar uang berapa?
- Pemasukan saya dari mana saja?
- Pengeluaran terbesar saya untuk apa?
- Apakah budget bulan ini masih aman?
- Apakah pola keuangan saya membaik atau memburuk?

---

## 3. Target User

### Primary User

Pengguna utama adalah:

- Pengguna Android dan web yang ingin mencatat keuangan pribadi
- Pengguna yang mengelola pemasukan, pengeluaran, transfer, dan budget harian
- Pengguna yang ingin mengakses data keuangan yang sama melalui satu akun
- Pengguna yang ingin data antarperangkat tetap konsisten dan terisolasi dari akun lain
- Tidak ingin terlalu banyak mengetik
- Butuh dashboard visual yang mudah dibaca

### Primary Device

Perangkat referensi Android:

- Redmi 13
- Android 16
- HyperOS 3.0.3

Aplikasi harus terasa ringan dan stabil pada perangkat tersebut. Web merupakan platform produk yang setara dan harus diuji pada browser mobile maupun desktop.

---

## 4. Problem Statement

Pengguna membutuhkan aplikasi pencatat keuangan yang:

1. Cepat digunakan untuk input transaksi harian.
2. Mengakses keuangan melalui akun Google yang sama di Android dan web.
3. Menyinkronkan data akun melalui Firestore agar perubahan terhubung antarperangkat.
4. Memiliki dashboard dan analytics yang jelas.
5. Tidak terasa seperti spreadsheet atau aplikasi akuntansi berat.
6. Tidak memiliki UI generik seperti template dashboard biasa.
7. Cocok untuk berbagai kebutuhan keuangan pribadi sehari-hari.

Masalah utama bukan hanya mencatat transaksi, tetapi membuat proses mencatat menjadi cukup mudah sehingga pengguna mau melakukannya setiap hari.

---

## 5. Product Goals

### Functional Goals

- Pengguna bisa mencatat pemasukan.
- Pengguna bisa mencatat pengeluaran.
- Pengguna bisa mencatat transfer antar-wallet.
- Pengguna bisa mengelola wallet seperti Cash, DANA, GoPay, rekening, dan tabungan.
- Pengguna bisa melihat riwayat transaksi.
- Pengguna bisa memfilter transaksi berdasarkan tanggal, tipe, kategori, dan wallet.
- Pengguna bisa melihat dashboard bulanan.
- Pengguna bisa melihat analytics visual.
- Pengguna bisa membuat budget bulanan.
- Pengguna bisa export dan import data akun dengan validasi serta konfirmasi penggantian data.
- Pengguna bisa melanjutkan pengelolaan keuangan di Android maupun web menggunakan akun yang sama.

### Experience Goals

- Input transaksi harus cepat.
- UI harus terasa premium, minimal, dan tidak ramai.
- Pengguna tidak perlu banyak mengetik.
- Informasi utama harus terlihat jelas dalam sekali buka.
- Aplikasi harus nyaman dipakai setiap hari.
- Animasi harus halus tapi tidak berlebihan.
- Tampilan harus iOS-like, tetapi tetap cocok di Android.

### Technical Goals

- Data keuangan terhubung melalui Firebase Firestore per akun.
- Login Google dan model data yang sama pada Android dan web.
- Ringan.
- Stabil.
- Mudah dikembangkan.
- Open-source ready.
- Menggunakan Firebase yang sudah ada tanpa backend kustom tambahan.
- Status sinkronisasi, perubahan tertunda, dan kegagalan koneksi terlihat jelas.
- Tidak memakai dependency berlebihan.

---

## 6. Non-Goals

DompetKu tidak bertujuan menjadi:

- Aplikasi bank.
- Aplikasi investasi.
- Aplikasi crypto.
- Aplikasi akuntansi profesional.
- Aplikasi invoice lengkap.
- Aplikasi pajak.
- Aplikasi kolaborasi keuangan dengan akses lintas akun tanpa izin pemilik.
- Aplikasi dengan iklan.
- Aplikasi tracking pengguna.

Fokus pengembangan adalah pengelolaan keuangan pribadi melalui satu akun dengan data yang sama di Android dan web. Login Google dan sinkronisasi Firestore termasuk kebutuhan inti.

---

## 7. Platform Scope

### Product Platforms

- Android
- Flutter Web/PWA pada browser mobile dan desktop

Kedua platform memakai akun, dataset Firestore, aturan keuangan, dan fitur inti yang sama. Perbedaan teknis seperti biometrik, izin notifikasi, atau instalasi APK mengikuti kemampuan platform.

### Future Optional

- Windows desktop
- Export PDF
- Manual cloud backup
- Google Drive backup
- Advanced financial report

---

## 8. Core Features

## 8.1 Onboarding

Onboarding muncul saat pertama kali aplikasi dibuka.

Login Google dan inisialisasi akun harus selesai sebelum data keuangan akun dimuat. Tampilkan akun tujuan dan tawarkan migrasi data perangkat lama secara eksplisit setelah cadangan tersimpan.

Data yang dikumpulkan:

- Nama pengguna
- Mata uang default: IDR
- Wallet awal
- Saldo awal opsional
- Preferensi tema: system, light, dark

Onboarding harus singkat. Jangan membuat pengguna mengisi terlalu banyak hal di awal.

### Acceptance Criteria

- Pengguna bisa menyelesaikan onboarding kurang dari 1 menit.
- Pengguna bisa mulai memakai data akun setelah login dan onboarding selesai.
- Android dan web dengan UID yang sama membuka dataset akun yang sama.
- Wallet default bisa dibuat otomatis.
- Onboarding tidak terasa seperti form panjang.

---

## 8.2 Dashboard

Dashboard adalah halaman utama aplikasi.

Dashboard harus menampilkan:

- Total saldo
- Pemasukan bulan ini
- Pengeluaran bulan ini
- Net cashflow
- Rata-rata pengeluaran harian
- Budget progress
- Kategori pengeluaran terbesar
- Recent transactions
- Quick add transaction

Dashboard harus menjawab kondisi keuangan pengguna secara cepat dan visual.

### Acceptance Criteria

- Pengguna bisa melihat total saldo dengan jelas.
- Pengguna bisa melihat ringkasan pemasukan dan pengeluaran bulan ini.
- Pengguna bisa langsung menambah transaksi dari dashboard.
- Dashboard tetap rapi walaupun belum ada data.
- Empty state harus informatif dan tidak terasa kosong.

---

## 8.3 Transaction Input

DompetKu harus mengutamakan input transaksi yang cepat.

Jenis transaksi:

- Pemasukan
- Pengeluaran
- Transfer antar-wallet

Field transaksi:

- Nominal
- Tipe transaksi
- Kategori
- Wallet
- Tanggal
- Catatan opsional

Input harus minim mengetik. Gunakan:

- Custom number pad
- Segmented control
- Category picker
- Wallet picker
- Quick template
- Date picker
- Chip atau button selection

### Acceptance Criteria

- Pengguna bisa input transaksi umum kurang dari 10 detik.
- Pengguna tidak wajib mengisi catatan.
- Nominal mudah diketik dengan keypad.
- Kategori dan wallet bisa dipilih tanpa mengetik.
- Transaksi langsung mempengaruhi saldo dan dashboard.

---

## 8.4 Categories

Kategori digunakan untuk mengelompokkan pemasukan dan pengeluaran.

### Expense Categories

Default kategori pengeluaran:

- Makan
- Minum
- Kos
- Laundry
- Galon
- Listrik
- Bensin
- Transport
- Kuliah
- Print/Tugas
- Buku
- Kesehatan
- Obat
- Pakaian
- Hiburan
- Bioskop
- Nongkrong
- Liburan
- Digital/Software
- Kuota
- Peralatan Kerja
- Sosial/Donasi
- Lainnya

### Income Categories

Default kategori pemasukan:

- Uang saku orang tua
- Desain grafis
- Video editing
- PPT / desain presentasi
- Project kerja
- Part-time
- Hadiah
- Refund
- Cashback
- Lainnya

### Acceptance Criteria

- Kategori default tersedia saat pertama kali aplikasi digunakan.
- Pengguna bisa memilih kategori dengan cepat.
- Kategori bisa dibedakan berdasarkan tipe income atau expense.
- Kategori bisa diedit atau ditambahkan pada versi fitur lanjutan.

---

## 8.5 Wallet Management

Wallet adalah tempat uang pengguna disimpan.

Default wallet:

- Cash
- DANA
- GoPay
- ShopeePay
- OVO
- Rekening
- Tabungan

Setiap transaksi harus terkait dengan satu wallet.

### Acceptance Criteria

- Pengguna bisa melihat daftar wallet.
- Pengguna bisa melihat saldo per wallet.
- Pengguna bisa menambah wallet.
- Pengguna bisa mengedit wallet.
- Pengguna bisa melakukan transfer antar-wallet.
- Saldo wallet dihitung dari saldo awal dan transaksi.

---

## 8.6 Transaction History

Riwayat transaksi menampilkan semua pemasukan, pengeluaran, dan transfer.

Fitur riwayat:

- List transaksi
- Filter tanggal
- Filter tipe transaksi
- Filter kategori
- Filter wallet
- Search catatan
- Edit transaksi
- Hapus transaksi

### Acceptance Criteria

- Riwayat transaksi mudah dibaca.
- Pemasukan dan pengeluaran terlihat berbeda secara visual.
- Filter tidak membuat UI terasa padat.
- Pengguna bisa mengubah atau menghapus transaksi yang salah.

---

## 8.7 Analytics

Analytics membantu pengguna memahami pola keuangan.

Analytics utama:

- Donut chart pengeluaran per kategori
- Line chart cashflow harian
- Bar chart pengeluaran mingguan/bulanan
- Top 5 kategori pengeluaran
- Sumber pemasukan terbesar
- Perbandingan bulan ini vs bulan lalu

Analytics harus fokus pada insight, bukan sekadar grafik dekoratif.

### Acceptance Criteria

- Grafik tetap rapi di Android dan browser mobile maupun desktop.
- Grafik mudah dibaca.
- Analytics tetap punya empty state saat belum ada data.
- Warna grafik konsisten dengan makna finansial.
- Tidak terlalu banyak grafik dalam satu layar.

---

## 8.8 Budget

Budget membantu pengguna mengontrol pengeluaran bulanan.

Jenis budget:

- Budget total bulanan
- Budget per kategori

Status budget:

- Aman
- Mendekati limit
- Terlampaui

### Acceptance Criteria

- Pengguna bisa membuat budget bulanan.
- Pengguna bisa melihat progress budget.
- Aplikasi bisa memberi indikator visual jika budget hampir habis.
- Budget dihitung berdasarkan transaksi bulan berjalan.

---

## 8.9 Backup, Export, and Import

Backup melengkapi sinkronisasi akun dengan salinan data yang dapat disimpan pengguna sebelum impor, migrasi, atau perubahan besar.

Fitur wajib:

- Export JSON
- Import JSON
- Export CSV

Fitur opsional lanjutan:

- Export PDF
- Manual backup ke folder lokal
- Manual backup ke cloud storage

### Acceptance Criteria

- Pengguna bisa export semua data.
- Pengguna bisa import ulang data dari file backup.
- CSV bisa digunakan untuk analisis di spreadsheet.
- File backup dapat disimpan pengguna secara mandiri; pemulihan data akun membutuhkan koneksi, validasi, staging, dan aktivasi dataset secara atomik.
- Migrasi data perangkat lama menampilkan akun tujuan dan membutuhkan cadangan tersimpan serta tindakan eksplisit pengguna.

---

## 8.10 Security

Kebutuhan keamanan produk terintegrasi:

- Google sign-in dan isolasi data berdasarkan Firebase UID
- Firestore Security Rules untuk kepemilikan data akun
- Hide balance toggle
- PIN lock
- Biometric lock
- Auto-lock timeout

### Acceptance Criteria

- Pengguna bisa menyembunyikan nominal saldo.
- Pengguna bisa mengaktifkan lock app.
- Biometric bersifat opsional.
- Security tidak mengganggu input cepat.
- Pergantian akun membuang state dan listener akun sebelumnya.
- Logout menunggu sinkronisasi; membuang perubahan memerlukan cadangan dan konfirmasi eksplisit.

---

## 9. UX Requirements

## 9.1 Input Experience

Aplikasi harus menghindari form panjang.

Prioritaskan:

- Tap
- Select
- Chip
- Segmented button
- Quick template
- Number keypad
- Bottom sheet
- Large touch target

Hindari:

- Banyak TextField
- Form terlalu panjang
- Navigasi berlapis terlalu dalam
- Input yang membutuhkan banyak keyboard typing

---

## 9.2 Navigation

Navigasi utama menggunakan bottom navigation.

Tab utama:

- Beranda
- Transaksi
- Analitik
- Wallet
- Setting

Tombol tambah transaksi harus mudah dijangkau. Pada Android, tombol tambah boleh menggunakan floating action button atau bottom-centered quick action selama tidak terasa seperti Material default yang generik.

---

## 9.3 Empty State

Setiap halaman yang belum memiliki data harus tetap terasa selesai.

Empty state harus:

- Menjelaskan kondisi kosong
- Memberi arahan tindakan berikutnya
- Tidak terlalu ramai
- Tidak memakai ilustrasi berlebihan
- Tetap sesuai visual premium

Contoh:

- Belum ada transaksi
- Belum ada analytics
- Belum ada budget
- Belum ada wallet tambahan

---

## 10. UI Direction

## 10.1 Design Personality

DompetKu harus terasa:

- iOS-like
- Premium
- Minimal
- Calm
- Elegant
- Soft
- Precise
- Modern
- Tidak berisik
- Tidak generik

Referensi iOS digunakan sebagai inspirasi visual, bukan untuk disalin mentah. Aplikasi tetap harus nyaman di Android.

---

## 10.2 Visual Principles

Prinsip visual:

- Background bersih dan lembut
- Surface/card terasa melayang halus
- Radius besar dan konsisten
- Shadow soft, bukan kasar
- Typography besar untuk angka penting
- Warna terbatas
- Divider sangat halus
- Icon sederhana
- Layout lega
- Animasi halus dan cepat

---

## 10.3 Anti-Generic UI Rules

DompetKu tidak boleh terlihat seperti:

- Default Flutter counter app
- Default Material purple theme
- Dashboard template generik
- UI SaaS analytics biasa
- Card collection dengan gradient acak
- Glassmorphism berlebihan
- UI terlalu ramai
- UI dengan terlalu banyak icon
- UI yang dibuat hanya agar terlihat “rame”

UI harus terasa disengaja, bukan hasil template cepat.

---

## 10.4 iOS-like Adaptation Rules

Yang diambil dari iOS-like design:

- Calm hierarchy
- Large title
- Minimal chrome
- Soft card stack feel
- Floating surfaces
- Subtle blur/frosted impression jika dibutuhkan
- Consistent spacing
- Smooth transition
- High-quality typography
- Focus on content

Yang tidak boleh disalin mentah:

- Komponen yang terlalu spesifik iPhone
- Navigasi yang tidak cocok untuk Android
- Apple branding
- Apple Wallet clone
- iOS-only interaction yang aneh di Android

DompetKu harus mengadaptasi inspirasi visual iOS secara konsisten dengan pola interaksi yang nyaman untuk Android dan web.

---

## 11. Data Requirements

Data utama:

### Transactions

- id
- type
- amount
- category_id
- wallet_id
- transfer_wallet_id optional
- date
- note optional
- created_at
- updated_at

### Categories

- id
- name
- type
- icon
- color
- is_default
- created_at
- updated_at

### Wallets

- id
- name
- type
- initial_balance
- created_at
- updated_at

### Budgets

- id
- category_id optional
- month
- limit_amount
- created_at
- updated_at

### Quick Templates

- id
- title
- transaction_type
- default_amount optional
- category_id
- wallet_id
- icon
- color

### App Settings

- user_name
- currency
- theme_mode
- hide_balance
- app_lock_enabled
- onboarding_completed

---

## 12. Technical Requirements

Recommended stack:

- Flutter
- Dart
- Firebase Authentication
- Cloud Firestore
- Drift
- SQLite
- Riverpod
- fl_chart
- shared_preferences
- intl
- path_provider
- file_picker
- share_plus
- csv
- local_auth

Rules:

- Android and web must share Google sign-in and UID-scoped Firestore account data.
- Use existing Firebase services without adding a custom backend or automatically enabling billing.
- Gate account repositories behind completed authentication initialization.
- Treat device storage as cache, device preferences, or a legacy migration source.
- Preserve pending writes and show synchronization, retry, and connection errors accurately.
- Test account isolation and cross-client synchronization using Firebase emulators and test accounts.
- No tracking.
- No ads.
- No unnecessary package.
- Android and web are equal product platforms with the same financial rules and core features.

---

## 13. Performance Requirements

DompetKu harus:

- Cepat dibuka
- Tidak berat saat scroll
- Tidak delay saat input transaksi
- Tidak menggunakan animasi berat berlebihan
- Tidak memakai asset besar tanpa kebutuhan
- Tetap nyaman di Redmi 13
- Menampilkan status sinkronisasi dan pemulihan koneksi tanpa kehilangan perubahan

Target pengalaman:

- App launch terasa cepat.
- Navigasi antar-tab terasa instan.
- Input transaksi tidak terasa lambat.
- Dashboard tetap smooth walaupun transaksi bertambah banyak.

---

## 14. Accessibility Requirements

DompetKu harus memperhatikan:

- Kontras teks yang cukup
- Ukuran teks nyaman dibaca
- Touch target cukup besar
- Warna tidak menjadi satu-satunya pembeda
- Icon harus didukung label
- Nominal uang harus mudah dibaca
- Dark mode tidak menyilaukan

---

## 15. Open Source Requirements

Karena DompetKu akan diunggah sebagai repo open-source, project harus memiliki:

- README.md
- LICENSE
- ROADMAP.md
- CONTRIBUTING.md
- CODE_OF_CONDUCT.md
- SECURITY.md
- PRD.md
- DESIGN_SYSTEM.md
- ARCHITECTURE.md

Kode harus:

- Rapi
- Modular
- Mudah dibaca
- Tidak menyimpan data pribadi asli
- Tidak menyertakan credential
- Tidak menyertakan file backup pribadi
- Tidak menyertakan data transaksi asli pengguna

---

## 16. Release Scope

## 16.1 Integrated Product Scope

Target produk terintegrasi dianggap siap jika sudah memiliki dan memverifikasi:

- Google sign-in di Android dan web
- Dataset Firestore bersama per Firebase UID
- Sinkronisasi data antarperangkat dan isolasi antar-akun
- Migrasi aman data perangkat lama dengan cadangan dan konfirmasi
- Onboarding
- Dashboard
- Add income
- Add expense
- Transfer wallet
- Transaction history
- Wallet management
- Category default
- Analytics dasar
- Budget dasar
- Export/import JSON
- Export CSV
- Settings
- Status sinkronisasi, perubahan tertunda, dan pemulihan koneksi
- Android build dan web deployment

---

## 16.2 Out of Scope

Fitur berikut tidak termasuk cakupan pengembangan saat ini:

- Backend kustom tambahan
- OCR struk
- AI financial assistant
- Invoice lengkap
- Tax report
- Bank integration
- Subscription tracking otomatis
- Push notification kompleks

---

## 17. Development Phases

## Phase 1 - Product Foundation

Tujuan: membuat fondasi aplikasi yang rapi dan tidak generik.

Scope:

- App shell
- Theme system
- Design tokens
- Bottom navigation
- Dashboard static
- Empty states
- Basic page structure

Output:

- UI awal sudah terasa seperti DompetKu, bukan Flutter starter app.

---

## Phase 2 - Connected Account Foundation

Tujuan: membuat fondasi akun dan data terhubung yang sama untuk Android dan web.

Scope:

- Firebase Authentication dan login Google di kedua platform
- Firestore dataset per UID dan Security Rules
- Inisialisasi sesi sebelum repository akun
- Listener bersama dan status sinkronisasi
- Migrasi data Drift/SQLite lama dengan backup dan konfirmasi
- Repository
- Seed categories
- Seed wallets

Output:

- Data akun yang sama siap dipakai oleh fitur transaksi pada Android dan web.

---

## Phase 3 - Transaction System

Tujuan: membuat fitur transaksi utama.

Scope:

- Add income
- Add expense
- Transfer wallet
- Edit transaction
- Delete transaction
- Transaction history
- Filter transaction

Output:

- Pengguna sudah bisa mencatat keuangan harian.

---

## Phase 4 - Dashboard and Analytics

Tujuan: menghubungkan data ke visual.

Scope:

- Real dashboard data
- Monthly summary
- Donut chart
- Line chart
- Bar chart
- Top category
- Income source breakdown

Output:

- Pengguna bisa membaca kondisi keuangan dari dashboard dan analytics.

---

## Phase 5 - Budget and Backup

Tujuan: membuat aplikasi layak dipakai jangka panjang.

Scope:

- Budget total
- Budget per category
- Export JSON
- Import JSON
- Export CSV
- Reset data

Output:

- Aplikasi aman digunakan karena data bisa dicadangkan.

---

## Phase 6 - Security and Polish

Tujuan: membuat aplikasi terasa matang.

Scope:

- Hide balance
- PIN lock
- Biometric lock
- Dark mode polish
- Animation polish
- Responsive Android and web layouts
- Account isolation and synchronization checks across Android and web
- README screenshot
- Release APK

Output:

- DompetKu siap dipakai pribadi dan dipublikasikan sebagai open-source project.

---

## 18. Success Metrics

DompetKu berhasil jika:

- Pengguna bisa mencatat transaksi harian tanpa merasa ribet.
- Data akun yang sama tersedia di Android dan web setelah sinkronisasi berhasil.
- Dashboard langsung memberi gambaran kondisi uang.
- UI tidak terasa generik.
- Aplikasi berjalan stabil di Android dan browser mobile maupun desktop.
- Data bisa dibackup.
- Repo GitHub terlihat rapi dan profesional.
- Project bisa dilanjutkan dengan Codex tanpa arah yang kabur.

---

## 19. Design Quality Bar

Setiap perubahan UI harus melewati pertanyaan berikut:

1. Apakah tampilan ini masih terasa premium?
2. Apakah ini terlalu mirip template dashboard generik?
3. Apakah informasi utama mudah dibaca?
4. Apakah spacing sudah lega?
5. Apakah warna terlalu ramai?
6. Apakah komponen ini terasa seperti bagian dari satu design system?
7. Apakah ini nyaman digunakan di Android dan web?
8. Apakah animasi membantu, bukan mengganggu?
9. Apakah input masih cepat?
10. Apakah ini sesuai karakter DompetKu?

Jika jawabannya lemah, desain harus direvisi.

---

## 20. Final Product Statement

DompetKu is a connected personal money management app for Android and web, designed for everyday income, expense, wallet, and budget tracking through one account. Both platforms must share Google sign-in, UID-scoped Firestore data, consistent financial rules, and synchronization across devices. It focuses on fast transaction input, clear financial summaries, useful analytics, and a premium iOS-inspired interface adapted for mobile and browser use.

The app must be private, lightweight, stable, elegant, and practical for daily use.
