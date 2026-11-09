# Handoff: DOT Launcher

Launcher macOS gratis ala Raycast, termasuk fitur yang di Raycast hanya ada di paket Pro. Dibuat untuk dipakai sendiri.

## Status (9 Nov 2026)
**MVP tahap 1 sudah selesai** (commit M0–M6 di branch `main`). Isinya:

| Fitur | Cara pakai |
|---|---|
| Launcher | ⌥Space membuka panel. App yang sedang aktif tetap di depan. |
| Cari & buka aplikasi | Pencarian fuzzy dengan bonus akronim (`vsc` → Visual Studio Code). Urutan hasil belajar dari pemakaian. Kalau pencarian kosong, yang tampil adalah app yang sering dipakai. |
| Kalkulator | Ketik ekspresi (`(2+3)*4/3`), lalu ⏎ untuk menyalin hasilnya. Titik dan koma sama-sama diterima sebagai desimal. Hasil memakai pemisah desimal sesuai locale. |
| Clipboard history tanpa batas | Ketik "clip" atau tekan ⇧⌥C, lalu ⏎ untuk paste ke app sebelumnya. Isi password manager tidak ikut disimpan. |
| Window snapping | Perintah "Left Half", "Maximize", "Restore", dan lainnya di launcher. Shortcut ⌃⌥ sama dengan default Rectangle. |
| Menu bar | Status izin, status shortcut, Launch at Login, Quit. |

## Keputusan
- Nama: **DOT Launcher**. Bundle ID: `com.pace.DOTLauncher`.
- Target: **khusus macOS 27**.
- Build memakai SwiftPM + script, tanpa Xcode. Hanya Command Line Tools yang terpasang.
- Distribusi pribadi, tanpa notarisasi dan tanpa lisensi.
- Tanpa dependensi eksternal.
- Shortcut ⌃⌥ (window) dan ⇧⌥C (clipboard) **hanya aktif kalau Rectangle/Maccy tidak berjalan**. Lewat menu bar ada opsi "Enable anyway".
- Data disimpan di `~/Library/Application Support/DOT Launcher/`:
  - `launcher.sqlite` untuk frekuensi pemakaian
  - `clipboard.sqlite` untuk riwayat clipboard (FTS5 trigram)

## Cara kerja
```
make test     # 74 test Core (Swift Testing)
make run      # build, tanda tangani, pasang ke ~/Applications, buka
make logs     # log stream subsystem com.pace.DOTLauncher (termasuk debug)
make reset-tcc
```
- Jangan pakai `swift run`. Tanpa bundle `.app`, TCC dan privasi pasteboard tidak berfungsi benar.
- Struktur kode:
  - `Sources/DOTLauncherCore`: logika murni yang dites (fuzzy, ranker, kalkulator, SQLite, clipboard store, geometri window, KeyCombo).
  - `Sources/DOTLauncher`: app AppKit + SwiftUI.
- Rencana lengkap: `~/.claude/plans/baca-handoff-md-lalu-lanjutkan-cached-barto.md`.

## Jebakan yang sudah ditemukan
- **Swift Testing di CLT:** plugin macro `TestingMacros` tidak dimuat otomatis. `Package.swift` menambahkan `-plugin-path` ke folder `.../host/plugins/testing`.
- **Tanda tangan:** setiap build ditandatangani dengan sertifikat Apple Development (SHA1 `96BC64B9…`), sehingga izin Accessibility tetap berlaku setelah rebuild (sudah terbukti). Sertifikat ini **kedaluwarsa 2027-02-04**. Setelah diperpanjang, kalau izin bermasalah, jalankan `make reset-tcc`.
- **`make install`:** script menunggu proses lama berhenti sebelum `open`. Tanpa jeda ini, app kadang tidak terbuka.
- **Hotkey Carbon:** konflik tidak terdeteksi. `RegisterEventHotKey` tetap sukses walaupun Rectangle berjalan, karena itulah shortcut dibuat bergantung pada app yang berjalan.
- **Shortcut ⌃⌥← di Rectangle:** di Mac ini tampaknya sudah tidak aktif, karena Rectangle tidak bereaksi.
- **zsh:** `log` adalah builtin zsh, jadi pakai `/usr/bin/log`.
- **Path `/private/var`:** `FileManager` mengubah `/var` menjadi `/private/var`. `AppScanner` menyusun path anak dari path root supaya hasilnya konsisten.

## Belum diuji / batasan yang diketahui
- Snapping app Chromium/Electron dan multi-monitor belum diuji manual. Chrome yang sedang berjalan saat uji berada dalam mode fullscreen, dan memang sengaja dilewati. Konversi koordinat antar-monitor sudah tercakup unit test.
- Paste mengirim ⌘V memakai `kVK_ANSI_V`, jadi bisa meleset di layout keyboard non-QWERTY.
- Clipboard belum menyimpan gambar (rencana M4b: disimpan sebagai file, bukan blob) dan belum punya panel preview.
- Shortcut belum bisa diubah lewat UI. Default ada di `WindowAction.defaultHotKey` dan `AppDelegate`.
- Kalkulator belum mendukung konversi unit atau kurs.

## Langkah berikutnya (tahap 2, usulan)
1. Clipboard: gambar (M4b), panel preview, hapus/pin dari panel (⌘⌫, ⌘P).
2. Snippets dan notes.
3. AI chat. Di macOS 27, **Foundation Models** (on-device, gratis) bisa dipakai tanpa API key. Ollama atau API key sendiri bisa jadi opsi tambahan.
4. Translator memakai framework Translation Apple (on-device).
5. Pengaturan: ubah shortcut, tema.
6. Tahap 3: sync (folder iCloud Drive), script commands.
