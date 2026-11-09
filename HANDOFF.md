# Handoff: DOT Launcher

Launcher macOS gratis ala Raycast, termasuk fitur yang di Raycast hanya ada di paket Pro. Dibuat untuk dipakai sendiri.

## Status (10 Nov 2026)
- **Tahap 1** selesai di `main` (commit M0–M6).
- **Tahap 2** selesai di branch **`tahap-2`** dan belum di-merge ke `main`.
  - Desain: `docs/superpowers/specs/2026-11-09-tahap-2-design.md`
  - Rencana: `docs/superpowers/plans/2026-11-09-tahap-2.md`

| Fitur | Cara pakai |
|---|---|
| Launcher | ⌥Space membuka panel. App yang sedang aktif tetap di depan. ⌘C, ⌘V, ⌘A, dan ⌘Z berfungsi di kolom pencarian. |
| Cari & buka aplikasi | Pencarian fuzzy (`vsc` → Visual Studio Code). Urutan hasil belajar dari pemakaian. |
| Kalkulator | Ketik `(2+3)*4/3`, lalu ⏎ untuk menyalin. Titik dan koma sama-sama diterima sebagai desimal. |
| Clipboard history | Ketik "clip" atau ⇧⌥C, lalu ⏎ untuk paste. Isi password manager tidak disimpan. |
| Window snapping | "Left Half", "Maximize", "Restore", dan lainnya. Shortcut ⌃⌥ mengikuti Rectangle. |
| **Translator** | Ketik "tr", ⏎, lalu tulis teks. Arah Indonesia ↔ Inggris dipilih otomatis, ⌘L membalik arah. ⏎ menyalin, ⌘↩ mem-paste. Semuanya on-device. |
| **AI chat** | Ketik pertanyaan di root, lalu **Tab** (atau pilih baris "Ask AI"). Bisa juga lewat perintah "AI Chat". Jawaban berasal dari Foundation Models on-device. Pertanyaan berbahasa Indonesia diterjemahkan ke Inggris lalu jawabannya diterjemahkan balik, dan ⌘⇧O menampilkan jawaban asli. ⌘N chat baru, ⌘⇧C copy, ⌘↩ paste, Esc menghentikan jawaban. |
| **Snippets** | Ketik nama atau keyword (misalnya ";addr") di root, lalu ⏎ untuk paste. Placeholder yang didukung: `{date}`, `{time}`, `{datetime}`, `{clipboard}`. Perintah "Create Snippet" dan "Search Snippets". ⌘E edit, ⌃X ×2 hapus. |
| **Notes** | Perintah "Open Notes", "Create Note", "Search Notes". Jendela floating dengan styling Markdown langsung dan autosave. ⌘P daftar catatan, ⌘N catatan baru, ⌃X ×2 memindah catatan ke Trash, ⌘W menutup. |
| Menu bar | Status izin dan shortcut, Launch at Login, **Hide Menu Bar Icon**, Quit. Kalau ikon disembunyikan, gunakan perintah "Toggle Menu Bar Icon", "Accessibility Settings", dan "Quit DOT Launcher" di launcher. Membuka app lagi dari Finder juga menampilkan launcher. |

## Keputusan
- Nama: **DOT Launcher**. Bundle ID: `com.pace.DOTLauncher`. Target: **khusus macOS 27**.
- Build memakai SwiftPM + script, tanpa Xcode (hanya Command Line Tools). Tanpa dependensi eksternal. Pemakaian pribadi.
- Shortcut ⌃⌥ (window) dan ⇧⌥C (clipboard) hanya aktif kalau Rectangle/Maccy tidak berjalan. Menu bar menyediakan "Enable anyway".
- Semua data tetap di Mac, di `~/Library/Application Support/DOT Launcher/`:
  - `launcher.sqlite`: frekuensi pemakaian
  - `clipboard.sqlite`: riwayat clipboard (FTS5 trigram)
  - `Snippets/<UUID>.json` dan `Notes/<UUID>.md`: berupa file supaya sync lewat folder iCloud Drive di tahap 3 mudah
- AI hanya on-device. Model Apple belum mendukung bahasa Indonesia, jadi dipakai jembatan terjemahan on-device.
- Hapus item memakai **⌃X dua kali**. ⌘⌫ tetap untuk menghapus teks.
- Paste snippet, AI, dan terjemahan bersifat **sementara**: isi clipboard sebelumnya dikembalikan dan hasil paste tidak masuk history. "Copy" bersifat permanen dan tercatat.
- Riwayat AI chat hanya tersimpan selama app berjalan. Tidak ada hotkey global baru.

## Cara kerja
```
make test     # 122 test Core (Swift Testing)
make run      # build, tanda tangani, pasang ke ~/Applications, buka
make logs     # log stream subsystem com.pace.DOTLauncher (termasuk debug)
make reset-tcc
```
- Jangan pakai `swift run`. Tanpa bundle `.app`, TCC dan privasi pasteboard tidak berfungsi benar.
- **Struktur kode:**
  - `Sources/DOTLauncherCore` berisi logika murni yang dites: fuzzy, ranker, kalkulator, SQLite, clipboard store, geometri window, KeyCombo, deteksi bahasa dan arah terjemahan, segmen Markdown, highlighter Markdown, snippet store/expander, dan note store.
  - `Sources/DOTLauncher` berisi app AppKit + SwiftUI. Mode panel (`root`, `clipboard`, `translate`, `ai`, `snippets`, `notes`) diatur lewat `LauncherModel.ModeHandler` dan `customContent`.
- Ledger eksekusi tahap 2: `docs/superpowers/plans/2026-11-09-tahap-2-ledger.md`. Semua keputusan teknis tercatat di baris `Ruling:`, termasuk hasil review akhir.

## Jebakan yang sudah ditemukan
- **Swift Testing di CLT:** plugin `TestingMacros` tidak dimuat otomatis. `Package.swift` menambahkan `-plugin-path`.
- **`@State` tidak bisa dipakai.** Di SDK macOS 27, `@State` berupa macro (`SwiftUIMacros`) yang plugin-nya tidak ada di CLT. State view disimpan di model `@Observable`. `@FocusState`, `@Bindable`, dan `@Observable` aman.
- **Translation belum siap untuk concurrency Swift 6.** Framework ini harus di-import dengan `@preconcurrency import Translation`. Semua panggilan dimulai dari main actor.
- **FoundationModels di macOS 27:** `LanguageModelSession.GenerationError` sudah deprecated. Pakai `LanguageModelError` (`contextSizeExceeded`, `guardrailViolation`, `refusal`, …).
- **Menu Edit wajib ada.** App accessory tetap butuh `NSApp.mainMenu` agar ⌘C, ⌘V, ⌘A, dan ⌘Z berfungsi di kolom teks (`MainMenu.swift`). Akibatnya, status item kini berada di **menu bar 2** dalam System Events.
- **Shortcut ⌃ di panel** ditangkap di `sendEvent`, karena ⌃X tidak selalu dikirim sebagai key equivalent. Event auto-repeat (tombol ditahan) diabaikan di `KeyShortcut(event:)`. Tanpa itu, menahan ⌃X akan dihitung sebagai tekanan kedua dan langsung menghapus.
- **Invariant Notes:** selama jendela Notes terbuka, editor harus selalu punya catatan aktif (`currentID`). Setelah catatan dibuang, catatan terbaru (atau catatan baru) langsung dibuka, dan isi editor dikosongkan dulu supaya teks yang dibuang tidak tersimpan lagi.
- **Translator:** status berubah menjadi `.translating` begitu teks berubah, bukan setelah debounce. Copy dan Paste hanya bekerja pada terjemahan yang sudah selesai untuk teks saat ini.
- **Tanda tangan:** setiap build ditandatangani dengan sertifikat Apple Development, sehingga izin Accessibility bertahan setelah rebuild. Sertifikat ini **kedaluwarsa 2027-02-04**. Kalau izin bermasalah setelah perpanjangan, jalankan `make reset-tcc`.
- **`make install`** menunggu proses lama berhenti sebelum `open`.
- **Hotkey Carbon:** konflik dengan app lain tidak terdeteksi. Itu sebabnya shortcut bergantung pada app yang berjalan.
- **zsh:** `log` adalah builtin zsh, jadi pakai `/usr/bin/log`. `FileManager` mengubah `/var` menjadi `/private/var`.
- **Uji UI otomatis:** pakai dokumen TextEdit baru yang belum disimpan. Dokumen yang sudah tersimpan bisa berstatus "Locked", dan ⌘V lalu menawarkan duplikasi. Skrip bantu ada di scratchpad sesi (`fresh-paste.applescript`, `logged.sh`).

## Belum diuji / batasan yang diketahui
- Snapping app Chromium/Electron dan multi-monitor belum diuji manual. Konversinya sudah tercakup unit test.
- Pesan "paket bahasa belum terpasang" di Translator tidak bisa diuji langsung, karena semua pasangan bahasa yang dicek di Mac ini sudah terpasang. Jalur "tidak didukung" sudah teruji.
- Paste memakai `kVK_ANSI_V`, jadi bisa meleset di layout keyboard non-QWERTY.
- Clipboard belum mendukung gambar dan belum punya preview. Shortcut belum bisa diubah lewat UI. Kalkulator belum mendukung unit/kurs.
- Kualitas model on-device terbatas. Contohnya, "say hi in five words" dijawab "Hello.".

## Langkah berikutnya
1. Review akhir branch `tahap-2`, lalu merge ke `main`.
2. Auto-expand snippet (butuh izin Input Monitoring).
3. Riwayat AI chat yang persisten.
4. Clipboard: gambar, preview, pin/hapus dari panel.
5. Pengaturan: ubah shortcut, tema.
6. Tahap 3: sync (folder iCloud Drive) dan script commands.
