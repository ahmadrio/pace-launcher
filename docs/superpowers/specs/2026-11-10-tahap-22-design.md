# Desain Tahap 22: Paket Rilis

## Maksud
Tahap kedua dari rencana rilis publik (keputusan Pace, 10 Nov 2026): PACE Launcher dirilis lewat GitHub Releases, tanpa Apple Developer Program dan tanpa notarisasi. Tahap ini menyiapkan semua yang dibutuhkan untuk membuat file rilis, tapi **belum** membuat repo GitHub, push, atau mengunggah apa pun (itu tahap 24, hanya setelah Pace bilang ya). Pace memilih langsung mulai, jadi detail di bawah adalah **keputusan Claude** dan bisa dikoreksi.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - Satu sertifikat self-signed untuk semua build, supaya izin Accessibility, Input Monitoring, dan Automation pengguna tetap berlaku setelah update.
  - Versi 1.0.0.
  - `make release` menghasilkan DMG dan file checksum SHA-256 yang sudah dicek.
  - Panduan instalasi untuk pengguna (termasuk Open Anyway) dan catatan cara membuat rilis untuk Pace.
  - "Create Script Command" membuka skrip baru di editor teks, bukan menjalankannya.
- **Bukan sasaran**
  - Notarisasi, Developer ID, Homebrew.
  - Panduan izin di dalam app dan cek update (tahap 23).
  - README, LICENSE, kebijakan privasi, repo publik (tahap 24).
- **Anti-sasaran**
  - Kunci privat sertifikat masuk ke repo, DMG, atau log.
  - Rilis dibuat dari kode yang belum di-commit.
  - Orang yang membangun dari source tanpa sertifikat Pace tidak bisa menjalankan app.

## Sertifikat
- **Satu identitas untuk build debug dan rilis:** "PACE Launcher Signing" (RSA, berlaku 20 tahun), disimpan di login keychain Pace. Build dari `make run` dan dari GitHub sama-sama memakainya, jadi izin tidak berpindah-pindah antara keduanya. Sertifikat Apple Development tidak dipakai lagi (kedaluwarsa Feb 2027 dan memuat email Pace).
- **Dibuat oleh skrip** `scripts/make-signing-identity.sh`: kunci dibuat di folder sementara di luar repo, diimpor ke login keychain dengan akses untuk `codesign`, lalu file sementaranya dihapus. Skrip menolak jalan kalau identitas dengan nama itu sudah ada.
- **Mengubah keychain Pace butuh persetujuan Pace saat itu.** Pada pemakaian pertama, macOS bisa menanyakan izin `codesign` memakai kunci; Pace memilih "Always Allow".
- **Cadangan:** kunci hanya ada di login keychain (ikut Time Machine). Kalau hilang, rilis berikutnya memakai sertifikat baru dan pengguna perlu memberi izin ulang sekali. Cara mengekspor cadangan `.p12` ditulis di catatan rilis.
- **Kontributor tanpa sertifikat itu:** `make run` tetap jalan dengan tanda tangan ad-hoc dan peringatan bahwa izin akan hilang setiap build. `make release` menolak jalan tanpa sertifikat.

## Paket rilis
- **Versi:** `CFBundleShortVersionString` 1.0.0. `CFBundleVersion` tetap timestamp build.
- **`make release`:**
  1. Menolak jalan kalau ada perubahan yang belum di-commit (bisa dilewati dengan `PACE_ALLOW_DIRTY=1` untuk uji).
  2. Build `release`, ditandatangani dengan sertifikat di atas.
  3. Mengecek: tanda tangan valid, requirement memuat hash sertifikat itu, arsitektur arm64, versi dari Info.plist.
  4. Membuat `build/release/PACE-Launcher-<versi>.dmg` berisi app dan pintasan ke Applications.
  5. Memasang DMG (read-only, tidak muncul di Finder), mengecek ulang app di dalamnya, lalu melepasnya.
  6. Menulis `PACE-Launcher-<versi>.dmg.sha256` yang bisa dicek dengan `shasum -a 256 -c`.
- **DMG tidak ditandatangani:** tanpa notarisasi, tanda tangan DMG tidak mengubah perilaku Gatekeeper.
- **Hanya Apple silicon:** macOS 27 hanya berjalan di Apple silicon.

## Dokumen
- `docs/INSTALL.md` (bahasa Inggris, untuk pengguna GitHub): syarat, cek checksum, pasang dari DMG, Open Anyway di System Settings › Privacy & Security (perlu diulang di setiap versi baru), izin yang diminta app, cara uninstall, dan build dari source.
- `docs/RELEASING.md` (bahasa Inggris, untuk Pace): membuat sertifikat, mencadangkannya, menaikkan versi, `make release`, dan apa yang diunggah ke GitHub Releases.

## "Create Script Command"
Template baru dibuka dengan editor teks default macOS (app untuk teks biasa, biasanya TextEdit). Kalau tidak ada, file ditunjukkan di Finder. Skrip tidak pernah dijalankan saat dibuat.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- Satu sertifikat untuk debug dan rilis, menggantikan sertifikat Apple Development.
- Masa berlaku 20 tahun, nama "PACE Launcher Signing".
- Tidak ada file cadangan `.p12` otomatis; cara ekspor ditulis di catatan rilis.
- DMG sederhana (tanpa gambar latar), tidak ditandatangani.
- Panduan dalam bahasa Inggris karena UI app berbahasa Inggris dan pembacanya pengguna GitHub.

## Tambahan atas permintaan Pace (10 Nov 23:53)
Ikon menu bar dibuat ulang agar senada dengan ikon app: huruf "P" tebal dengan tiga garis kecepatan, sebagai template image yang otomatis berwarna gelap atau terang mengikuti menu bar. Menggantikan simbol `command.square`.
