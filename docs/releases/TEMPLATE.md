# DompetKu v{VERSION}

Rilis ini berfokus pada {RINGKASAN_SATU_KALIMAT}.

## Pembaruan

- {PERUBAHAN_1}.
- {PERUBAHAN_2}.
- {PERUBAHAN_3}.

## Download

Untuk sebagian besar HP Android modern, gunakan:

`DompetSheva-v{VERSION}-arm64.apk`

## Catatan

Arah pengembangan DompetKu menyatukan data akun Android dan web melalui login Google dan Firestore. Cakupan integrasi yang sudah diverifikasi pada rilis ini: {STATUS_INTEGRASI_ANDROID_DAN_WEB}.

DompetKu tidak memakai iklan, analytics, atau tracking. Status sinkronisasi dan penyimpanan data harus dijelaskan sesuai perilaku build yang dirilis.

File cadangan berisi data keuangan, jadi simpan di tempat yang aman.

Jika memasang APK dari luar Play Store, Android atau Play Protect mungkin tetap menampilkan peringatan.

## SHA256

`{SHA256_ARM64_HURUF_BESAR}`

<!-- CARA PAKAI:
1. Ganti {VERSION} dengan versi tanpa prefiks v, contoh: 1.4.0.
2. Tulis 1 kalimat fokus rilis, lalu daftar perubahan maksimal 5-8 poin, kalimat pendek gaya imperatif ("Menambahkan...", "Memperbaiki...").
3. SHA256 WAJIB hash arm64 dan jadi angka hex-64 PERTAMA di seluruh body, karena fitur update di dalam aplikasi membaca kecocokan pertama untuk verifikasi file. Jangan tulis hash lain sebelum bagian ini.
4. Hash boleh huruf besar (mengikuti contoh v1.3.0); aplikasi membandingkan tanpa memedulikan besar/kecil.
5. Salin isi ini ke GitHub Release: judul "DompetKu v{VERSION}", tag v{VERSION}, centang Set as latest.
6. Simpan salinan akhir sebagai docs/releases/v{VERSION}.md.
7. Isi {STATUS_INTEGRASI_ANDROID_DAN_WEB} sesuai hasil pengujian build ini. Jangan menyatakan integrasi Android tersedia sebelum login, migrasi, dan sinkronisasi lintas platform diverifikasi.
-->
