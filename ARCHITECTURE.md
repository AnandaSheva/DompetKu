# DompetKu Architecture

## 1. Architecture Overview

DompetKu menggunakan arsitektur **feature-first Flutter architecture** dengan pemisahan yang jelas antara:

- app configuration
- core utilities
- data layer
- feature layer
- shared UI components

Tujuan arsitektur ini adalah menjaga project tetap:

- rapi
- mudah dibaca
- mudah dikembangkan
- tidak overengineering
- cocok untuk open-source
- aman untuk dikerjakan bersama Codex/GPT

DompetKu adalah aplikasi **pengelolaan keuangan pribadi dengan data terhubung** untuk Android dan web. Arsitektur harus memprioritaskan konsistensi data akun antarperangkat, privasi, performa, stabilitas, dan maintainability.

Android dan web memakai Firebase Authentication dan CloudFinanceStore per UID. Android memakai Google sign-in native, migrasi Drift eksplisit, dan AlarmManager untuk pengingat tagihan. Verifikasi perangkat dan rilis tetap diperlukan.

---

## 2. Core Principles

## 2.1 Connected Account Data

Android dan web harus memakai login Google, Firebase UID, dan dataset Firestore yang sama untuk akun yang sama. Firestore menjadi sumber data akun bersama; cache perangkat mendukung responsivitas dan pemulihan koneksi.

Data fitur yang wajib terhubung ke akun:

- onboarding
- wallet
- transaksi
- kategori
- budget
- dashboard
- analytics
- settings
- tagihan dan target tabungan
- backup dan pemulihan data akun

Inisialisasi autentikasi harus selesai sebelum repository akun dibuat. Bedakan data cache, perubahan tertunda, data tersinkron, dan kegagalan server secara jelas; antrean perubahan harus dipertahankan hingga tersimpan atau dibuang melalui tindakan eksplisit yang didahului cadangan.

---

## 2.2 Android and Web Parity

Android dan web adalah platform produk yang setara dengan fitur inti dan aturan keuangan yang sama.

Gunakan kontrak repository yang sama untuk perhitungan saldo, transfer, budget, tagihan, target tabungan, dan pemulihan data. Perbedaan platform hanya menangani kemampuan perangkat seperti biometrik, izin browser, atau instalasi APK.

Platform produk:

```txt
1. Android
2. Flutter Web/PWA
```

Setiap keputusan UI dan teknis harus mempertimbangkan Android serta browser mobile dan desktop. Windows desktop tetap merupakan kemungkinan pengembangan lanjutan.

---

## 2.3 Simple but Scalable

Project tidak boleh terlalu sederhana sampai berantakan, tapi juga tidak boleh terlalu kompleks seperti enterprise app.

Gunakan struktur yang cukup rapi untuk jangka panjang, tetapi tetap mudah dipahami.

---

## 2.4 Feature-First

Setiap fitur utama memiliki folder sendiri.

Contoh fitur:

* dashboard
* transactions
* analytics
* wallets
* categories
* budgets
* settings
* backup
* onboarding

Feature-first dipilih agar setiap area aplikasi mudah ditemukan dan tidak tercampur.

---

## 2.5 Reusable UI Components

UI yang dipakai berulang harus masuk ke folder `shared`.

Contoh:

* card
* button
* empty state
* bottom navigation
* section header
* wallet card
* transaction tile

Jangan menulis ulang style yang sama berkali-kali di banyak screen.

---

## 3. Recommended Project Structure

Struktur utama:

```txt
lib/
  main.dart

  app/
    app.dart
    router/
      app_router.dart
    theme/
      app_theme.dart
      app_colors.dart
      app_spacing.dart
      app_radius.dart
      app_typography.dart
      app_shadows.dart
      app_durations.dart

  core/
    constants/
      app_constants.dart
      app_strings.dart
    enums/
      transaction_type.dart
      wallet_type.dart
      budget_status.dart
      category_type.dart
    extensions/
      datetime_extension.dart
      num_extension.dart
      string_extension.dart
    formatters/
      currency_formatter.dart
      date_formatter.dart
    helpers/
      calculation_helper.dart
      validation_helper.dart
    utils/
      result.dart

  data/
    auth/
      auth_repository.dart
    store/
      finance_store.dart
      cloud_finance_store.dart
      cloud_codec.dart
    local/
      database/
        app_database.dart
        tables/
          transactions_table.dart
          categories_table.dart
          wallets_table.dart
          budgets_table.dart
          quick_templates_table.dart
          app_settings_table.dart
        daos/
          transactions_dao.dart
          categories_dao.dart
          wallets_dao.dart
          budgets_dao.dart
          quick_templates_dao.dart
          app_settings_dao.dart
      seed/
        default_categories.dart
        default_wallets.dart
        default_quick_templates.dart
    repositories/
      transaction_repository.dart
      category_repository.dart
      wallet_repository.dart
      budget_repository.dart
      analytics_repository.dart
      backup_repository.dart
      settings_repository.dart

  features/
    onboarding/
      presentation/
        pages/
        widgets/
      providers/

    dashboard/
      presentation/
        pages/
        widgets/
      providers/

    transactions/
      presentation/
        pages/
        widgets/
      providers/

    analytics/
      presentation/
        pages/
        widgets/
      providers/

    wallets/
      presentation/
        pages/
        widgets/
      providers/

    categories/
      presentation/
        pages/
        widgets/
      providers/

    budgets/
      presentation/
        pages/
        widgets/
      providers/

    settings/
      presentation/
        pages/
        widgets/
      providers/

    backup/
      presentation/
        pages/
        widgets/
      providers/

  shared/
    layouts/
      main_shell.dart
      dompet_sheva_scaffold.dart
    widgets/
      empty_state.dart
      loading_state.dart
      error_state.dart
      premium_bottom_nav.dart
    components/
      primary_button.dart
      secondary_button.dart
      frosted_card.dart
      section_header.dart
      money_metric_card.dart
      balance_hero_card.dart
      premium_list_tile.dart
```

---

## 4. Folder Responsibilities

## 4.1 `main.dart`

Entry point aplikasi.

Tugas:

* menjalankan root app
* tidak berisi logic besar
* tidak berisi UI detail

Contoh ideal:

```dart
void main() {
  runApp(const DompetShevaApp());
}
```

---

## 4.2 `app/`

Folder `app` berisi konfigurasi global aplikasi.

Tanggung jawab:

* root MaterialApp
* theme setup
* route setup
* global app configuration

Tidak boleh berisi:

* database logic
* business logic fitur
* UI page detail
* dummy data fitur

---

## 4.3 `app/theme/`

Berisi design tokens dan theme global.

File utama:

```txt
app_theme.dart
app_colors.dart
app_spacing.dart
app_radius.dart
app_typography.dart
app_shadows.dart
app_durations.dart
```

Tujuan:

* menghindari hardcode style
* menjaga UI konsisten
* memudahkan perubahan design system

Semua warna, radius, spacing, dan durasi animasi utama harus berasal dari file theme.

---

## 4.4 `core/`

Folder `core` berisi utility murni yang tidak tergantung satu fitur tertentu.

Isi:

* constants
* enums
* extensions
* formatters
* helpers
* utils

Contoh:

* formatter Rupiah
* formatter tanggal
* enum transaction type
* helper perhitungan cashflow
* result wrapper

Folder `core` tidak boleh menjadi tempat pembuangan file acak.

---

## 4.5 `data/`

Folder `data` berisi autentikasi, penyimpanan akun, sinkronisasi, database perangkat, seed, dan repository.

Tanggung jawab:

* Firebase Authentication dan identitas akun
* Firestore melalui kontrak `FinanceStore`
* listener bersama, status sinkronisasi, dan antrean perubahan per akun
* Drift/SQLite dan DAO untuk kompatibilitas serta migrasi data perangkat lama
* seed data akun
* repository

Tidak boleh berisi:

* widget UI
* page UI
* component visual
* style

---

## 4.6 `features/`

Folder `features` berisi fitur utama aplikasi.

Setiap fitur boleh memiliki:

```txt
presentation/
  pages/
  widgets/
providers/
```

Jika fitur masih kecil, boleh dibuat sederhana dulu. Jangan memaksa struktur terlalu dalam jika belum dibutuhkan.

---

## 4.7 `shared/`

Folder `shared` berisi UI/component yang digunakan di banyak fitur.

Contoh:

* MainShell
* DompetShevaScaffold
* PremiumBottomNav
* EmptyState
* LoadingState
* ErrorState
* MoneyMetricCard
* BalanceHeroCard
* SectionHeader

Jika widget hanya dipakai di satu fitur, simpan di folder fitur tersebut, bukan `shared`.

---

## 5. Layering Rules

Urutan dependency:

```txt
UI Feature
  -> Riverpod Provider (auth/account scope)
    -> Repository
      -> FinanceStore
        -> Firestore account dataset
        -> Drift/SQLite legacy migration source
```

Aturan:

* UI tidak boleh langsung mengakses Firebase atau database; gunakan provider dan repository.
* Repository memakai kontrak penyimpanan bersama dan aturan keuangan yang sama pada kedua platform.
* Implementasi penyimpanan menangani Firestore atau DAO database perangkat sesuai tanggung jawabnya.
* Scope akun harus menunggu autentikasi dan dibuang saat UID berubah.
* Core utilities boleh dipakai semua layer.
* Shared UI tidak boleh tahu detail database.
* Data layer tidak boleh import UI.

---

## 6. State Management Strategy

State management utama yang direkomendasikan:

```txt
Riverpod
```

Namun Riverpod tidak perlu dipakai sebelum benar-benar dibutuhkan.

Tahapan:

## Phase 1

Static UI:

* gunakan StatefulWidget jika hanya untuk tab index sederhana
* tidak perlu Riverpod untuk dummy UI

## Phase 2

Saat mulai data akun terhubung:

* gunakan Riverpod untuk status autentikasi dan scope akun
* gunakan repository provider
* gunakan async provider untuk data akun dan status sinkronisasi
* gunakan provider database perangkat hanya untuk kompatibilitas dan migrasi

## Phase 3

Saat fitur makin kompleks:

* gunakan Notifier/AsyncNotifier untuk form transaksi
* gunakan provider terpisah untuk filter, selected period, dan settings

Aturan:

* jangan membuat global state tanpa alasan
* jangan menyimpan semua state di satu provider besar
* setiap provider harus punya tanggung jawab jelas
* form state dipisahkan dari list state

---

## 7. Database Strategy

Penyimpanan utama data akun pada arsitektur target menggunakan:

```txt
Firebase Authentication + Cloud Firestore
```

Alasan:

* satu dataset per UID untuk Android dan web
* Security Rules membatasi akses ke pemilik akun
* satu listener bersama per koleksi untuk seluruh repository
* status sinkronisasi dan percobaan ulang terlihat jelas
* operasi sensitif memakai transaksi server atau staging sebelum aktivasi dataset

Drift + SQLite tetap dipertahankan untuk kompatibilitas dan migrasi data perangkat yang sudah ada. Pertahankan nama database dan keamanan migrasi; jangan mengunggah, menghapus, atau mengganti data lama tanpa cadangan tersimpan, akun tujuan yang terlihat, dan tindakan eksplisit pengguna.

---

## 8. Data Model

## 8.1 Transactions

Tabel transaksi menyimpan semua pemasukan, pengeluaran, dan transfer.

Field:

```txt
id
type
amount
category_id
wallet_id
transfer_wallet_id nullable
date
note nullable
created_at
updated_at
```

Rules:

* `type` berisi income, expense, atau transfer.
* `amount` disimpan sebagai integer Rupiah, bukan double.
* `wallet_id` wajib.
* `category_id` wajib untuk income dan expense.
* `transfer_wallet_id` hanya digunakan untuk transfer.
* `note` opsional.

---

## 8.2 Categories

Field:

```txt
id
name
type
icon
color
is_default
created_at
updated_at
```

Rules:

* `type` berisi income, expense, atau both.
* kategori default tidak boleh hilang total tanpa mekanisme reset.
* kategori digunakan untuk analytics.

---

## 8.3 Wallets

Field:

```txt
id
name
type
initial_balance
created_at
updated_at
```

Rules:

* saldo wallet dihitung dari saldo awal + transaksi.
* jangan menyimpan current balance secara manual kecuali ada alasan performa.
* wallet bisa berupa cash, ewallet, bank, atau savings.

---

## 8.4 Budgets

Field:

```txt
id
category_id nullable
month
limit_amount
created_at
updated_at
```

Rules:

* jika `category_id` null, berarti budget total bulanan.
* jika `category_id` terisi, berarti budget kategori.
* budget dihitung dari transaksi expense bulan terkait.

---

## 8.5 Quick Templates

Field:

```txt
id
title
transaction_type
default_amount nullable
category_id
wallet_id
icon
color
created_at
updated_at
```

Rules:

* quick template mempercepat input transaksi.
* default amount boleh kosong.
* template bisa digunakan untuk transaksi rutin seperti makan, minum, laundry, uang saku, atau pemasukan tambahan.

---

## 8.6 App Settings

Field:

```txt
id
user_name
currency
theme_mode
hide_balance
app_lock_enabled
onboarding_completed
created_at
updated_at
```

Rules:

* pengaturan akun yang perlu sinkronisasi atau backup berada dalam dataset Firestore akun.
* preferensi khusus perangkat, seperti app lock dan izin notifikasi, boleh disimpan pada perangkat sesuai kebutuhan.
* pisahkan preferensi perangkat dari data akun agar pergantian akun tidak membocorkan data.

---

## 9. Repository Rules

Repository menjadi penghubung antara UI dan kontrak penyimpanan akun `FinanceStore`.

Contoh repository:

```txt
TransactionRepository
WalletRepository
CategoryRepository
BudgetRepository
AnalyticsRepository
BackupRepository
SettingsRepository
```

Repository bertanggung jawab untuk:

* menyediakan data ke UI
* menggabungkan data dari kontrak penyimpanan jika diperlukan
* menyembunyikan detail database dari UI
* menyediakan method yang semantic

Contoh method:

```txt
watchMonthlySummary()
watchRecentTransactions()
addExpense()
addIncome()
transferWallet()
deleteTransaction()
watchWalletBalances()
getExpenseByCategory()
exportBackup()
importBackup()
```

Jangan membuat UI memanggil query SQL langsung.

---

## 10. Analytics Rules

Analytics dihitung dari data transaksi.

Analytics utama:

* total income bulan ini
* total expense bulan ini
* net cashflow
* average daily expense
* expense by category
* income by source
* daily cashflow
* weekly expense
* top spending categories
* budget usage

Rules:

* analytics tidak boleh mengubah data transaksi
* analytics harus bisa kosong tanpa error
* analytics harus punya empty state
* perhitungan uang menggunakan integer
* filtering periode harus konsisten

---

## 11. Money Calculation Rules

Semua nominal uang disimpan sebagai integer Rupiah.

Benar:

```txt
12000
250000
1500000
```

Hindari:

```txt
12000.0
250000.50
```

Untuk IDR, decimal tidak diperlukan.

Rules:

* pemasukan menambah saldo
* pengeluaran mengurangi saldo
* transfer mengurangi wallet asal dan menambah wallet tujuan
* total saldo = semua saldo wallet
* net cashflow = income - expense
* transfer tidak dihitung sebagai income atau expense

---

## 12. Formatting Rules

Currency display:

```txt
Rp12.000
Rp250.000
Rp1.500.000
```

Tanggal:

```txt
Hari ini
Kemarin
1 Jul 2026
Juli 2026
```

Gunakan formatter terpusat:

```txt
currency_formatter.dart
date_formatter.dart
```

Jangan format uang secara manual di setiap widget.

---

## 13. UI Architecture Rules

UI harus dipisahkan menjadi:

* page
* section
* component

Contoh:

```txt
DashboardPage
  DashboardHeader
  BalanceHeroCard
  MonthlySummaryGrid
  InsightCard
  RecentTransactionSection
```

Jika file page terlalu panjang, pecah menjadi widget kecil.

Batas rekomendasi:

```txt
Page file: maksimal ±250-350 baris
Component file: maksimal ±150-250 baris
```

Jika lebih besar, evaluasi pemecahan file.

---

## 14. Design Token Rules

Gunakan token:

```txt
AppColors
AppSpacing
AppRadius
AppTypography
AppShadows
AppDurations
```

Hindari hardcode berulang seperti:

```dart
EdgeInsets.all(17)
BorderRadius.circular(23)
Color(0xFF...)
```

Hardcode boleh hanya jika sangat spesifik dan tidak reusable, tetapi harus minimal.

---

## 15. Navigation Architecture

Untuk awal, navigasi boleh sederhana menggunakan `IndexedStack`.

Main tabs:

```txt
DashboardPage
TransactionsPage
AnalyticsPage
WalletsPage
SettingsPage
```

Jika aplikasi mulai membutuhkan nested routes, gunakan router terpusat di:

```txt
app/router/app_router.dart
```

Rules:

* jangan menyebar route string di banyak file
* jangan membuat navigasi terlalu dalam
* input transaksi lebih cocok bottom sheet atau modal page
* halaman detail boleh memakai route khusus

---

## 16. Error Handling

Gunakan error state yang user-friendly.

Jangan tampilkan error teknis mentah ke UI pengguna.

Contoh buruk:

```txt
SqliteException: no such table transactions
```

Contoh baik:

```txt
Data transaksi belum bisa dimuat.
Coba buka ulang aplikasi.
```

Log teknis boleh dicatat untuk debugging, tetapi UI harus tetap bersih.

---

## 17. Empty State Handling

Setiap data kosong harus punya empty state.

Contoh:

* tidak ada transaksi
* tidak ada analytics
* tidak ada budget
* tidak ada wallet tambahan
* tidak ada hasil filter

Empty state harus memiliki:

* icon
* title
* message
* optional action

---

## 18. Backup Architecture

Backup harus bisa menyimpan data utama:

* transactions
* categories
* wallets
* budgets
* quick templates
* app settings

Format utama:

```txt
JSON
```

Format tambahan:

```txt
CSV
```

Backup JSON digunakan untuk restore aplikasi.

Export CSV digunakan untuk analisis manual di spreadsheet.

Rules:

* backup tidak boleh menyertakan data rahasia sistem
* backup harus versioned
* import harus validasi struktur data
* import tidak boleh merusak database jika file invalid
* pemulihan akun harus memakai staging dan mengaktifkan dataset pengganti secara atomik setelah seluruh upload berhasil
* backup dan migrasi harus menampilkan akun tujuan serta membutuhkan konfirmasi pengguna

---

## 19. Security Architecture

Security yang direncanakan:

* Google sign-in pada Android dan web
* isolasi data per Firebase UID dan Firestore Security Rules
* hide balance
* PIN lock
* biometric lock
* auto-lock timeout

Rules:

* security tidak boleh mengganggu input cepat
* hide balance hanya mengubah tampilan nominal
* biometric harus opsional
* app tetap bisa digunakan tanpa biometric
* app lock melindungi akses perangkat dan tidak menggantikan autentikasi akun atau mengenkripsi seluruh database
* perubahan tertunda harus disinkronkan sebelum logout, atau dicadangkan sebelum konfirmasi pembuangan

---

## 20. Dependency Rules

Dependency boleh ditambahkan hanya jika jelas manfaatnya.

Recommended dependencies:

```txt
flutter_riverpod
firebase_core
firebase_auth
cloud_firestore
drift
drift_flutter
sqlite3_flutter_libs
fl_chart
intl
shared_preferences
path_provider
file_picker
share_plus
csv
local_auth
```

Rules:

* jangan menambah package hanya untuk hal kecil
* jangan menambah package UI besar tanpa alasan
* gunakan layanan Firebase yang sudah ada tanpa backend kustom tambahan
* Firebase Auth dan Firestore merupakan fondasi akun serta sinkronisasi pada Android dan web
* jangan mengaktifkan billing otomatis; gunakan paket Spark
* jangan menambah analytics/tracking package
* jangan menambah ads package

---

## 21. File Naming Rules

Gunakan snake_case.

Benar:

```txt
dashboard_page.dart
balance_hero_card.dart
transaction_repository.dart
currency_formatter.dart
```

Salah:

```txt
DashboardPage.dart
balanceHeroCard.dart
transactionRepo.dart
```

Class name tetap PascalCase:

```dart
class DashboardPage {}
class BalanceHeroCard {}
class TransactionRepository {}
```

---

## 22. Import Rules

Gunakan relative import untuk file dalam `lib/` jika masih sederhana.

Contoh:

```dart
import '../../shared/components/money_metric_card.dart';
```

Jika project sudah besar dan path mulai rumit, evaluasi penggunaan package import.

Jangan mencampur style import secara acak dalam satu area.

---

## 23. Testing Strategy

Testing minimal:

* formatter test
* calculation helper test
* repository test later
* database DAO test later
* Firebase emulator tests untuk kepemilikan UID dan isolasi antar-akun
* sinkronisasi lintas klien, perubahan bersamaan, koneksi terputus, percobaan ulang, dan logout dengan perubahan tertunda
* migrasi data perangkat, validasi impor, dan aktivasi dataset secara atomik

Prioritas test awal:

```txt
currency formatter
date formatter
cashflow calculation
wallet balance calculation
budget status calculation
```

UI test bisa ditambahkan setelah fitur stabil.

---

## 24. Git and Open Source Rules

Repo harus aman untuk publik.

Jangan commit:

* file backup pribadi
* database pribadi
* screenshot data pribadi
* credential
* key
* token
* `.env`
* build output
* file besar tidak perlu

Harus ada:

* README.md
* LICENSE
* ROADMAP.md
* CONTRIBUTING.md
* CODE_OF_CONDUCT.md
* SECURITY.md
* PRD.md
* DESIGN_SYSTEM.md
* ARCHITECTURE.md
* CODEX_RULES.md
* TASKS.md

---

## 25. Development Flow

Setiap perubahan besar harus mengikuti alur:

1. Baca PRD.md
2. Baca DESIGN_SYSTEM.md
3. Baca ARCHITECTURE.md
4. Cek TASKS.md
5. Buat plan singkat
6. Ubah file seperlunya
7. Pastikan app tetap runnable
8. Commit perubahan

---

## 26. Phase Architecture

## Phase 1 - Static UI Foundation

Tujuan:

* app shell
* design system
* dashboard premium static
* empty states
* navigation

Belum perlu:

* database
* Riverpod kompleks
* chart library
* backup
* security

---

## Phase 2 - Connected Account Foundation

Tujuan:

* konfigurasi Firebase Android dan web
* Google sign-in dan inisialisasi sesi
* dataset Firestore per UID dan Security Rules
* kontrak `FinanceStore` dan listener bersama
* migrasi Drift/SQLite lama dengan cadangan serta konfirmasi
* seed data
* repositories

Mulai gunakan Riverpod untuk:

* auth/account provider
* repository provider
* data stream provider
* synchronization status provider

---

## Phase 3 - Transaction System

Tujuan:

* add income
* add expense
* transfer wallet
* transaction history
* filters
* edit/delete transaction

State yang dibutuhkan:

* transaction form state
* selected type
* selected category
* selected wallet
* selected date
* amount input

---

## Phase 4 - Dashboard and Analytics

Tujuan:

* real dashboard summary
* expense by category
* cashflow trend
* top categories
* budget progress

Mulai gunakan:

* analytics repository
* fl_chart
* period filter provider

---

## Phase 5 - Backup and Security

Tujuan:

* export/import JSON
* export CSV
* hide balance
* PIN
* biometric

Gunakan package tambahan hanya jika diperlukan.

---

## 27. Quality Checklist

Sebelum menerima pull request atau perubahan Codex, cek:

```txt
[ ] App masih bisa run
[ ] Tidak ada file acak
[ ] Tidak ada dependency tidak perlu
[ ] UI mengikuti design system
[ ] Tidak ada default Material style mentah
[ ] Struktur folder tetap rapi
[ ] Data layer tidak tercampur UI
[ ] Nama file konsisten
[ ] Tidak ada data pribadi
[ ] Tidak ada credential
[ ] Perubahan sesuai phase
[ ] Android dan web mengikuti kontrak akun dan aturan keuangan yang sama
[ ] Isolasi akun dan sinkronisasi diuji dengan emulator untuk perubahan terkait
[ ] Fitur terencana dibedakan dari integrasi yang sudah diverifikasi
```

---

## 28. Final Architecture Statement

DompetKu uses a feature-first Flutter architecture with shared account-based Firestore storage, reusable premium UI components, centralized design tokens, and clear separation between app, core, data, features, and shared layers.

The architecture must support a connected Android and web app with consistent financial data and business rules across devices, while remaining lightweight, stable, maintainable, and open-source ready.


## Shared account storage and implementation status

`FinanceStore` is the storage contract used by the existing financial repositories.
`CloudFinanceStore` is wired into both Android and web after authentication.
`AppDatabase` with Drift remains the migration source for existing device data.
Migration requires a saved backup, visible destination account, and explicit action.
Existing immutable Drift row objects remain
value objects at this boundary so financial calculations and forms stay compatible.

Each authenticated UID owns `users/{uid}` and versioned account datasets at
`users/{uid}/datasets/{dataset}/{collection}/{numericId}`. Numeric IDs for new cloud
records are random safe integers, avoiding cross-device auto-increment collisions.
Amounts remain integer Rupiah. One subscription per collection is shared by all
repositories; opening another screen does not create another backend listener.

Auth loading, signed-out, and signed-in states have separate widget trees. The
signed-in subtree and its Navigator are disposed when the UID changes. Android
bootstrap initializes Firebase with build-time Android options and restores native
account state before account repositories are created.
Native bill alarms use hashed account keys and are canceled on logout.
The app lock wraps the Navigator so notification routes remain protected.
Persistent web cache is opt-in; pending
writes remain visible and prevent logout from discarding them. Failed writes can
be retried and included in a JSON export. On a trusted device a UID-scoped outbox
also preserves rejected writes across refreshes.

Imports and resets upload a separate dataset in bounded batches, then atomically
switch `activeDataset` only after upload succeeds. Legacy migration is explicit,
requires a backup, and records an immutable migration fingerprint in the profile.
See `docs/firebase-web.md` for setup, tests, quotas, and deployment checks.
