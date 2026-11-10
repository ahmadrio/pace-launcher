# Handoff: DOT Launcher

Launcher macOS gratis ala Raycast, termasuk fitur yang di Raycast hanya ada di paket Pro. Dibuat untuk dipakai sendiri.

## Status (10 Nov 2026)
- **Tahap 1 dan 2** selesai dan sudah di-merge ke `main`.
- **Tahap 3** selesai dan sudah di-merge ke `main` (10 Nov 2026).
  - Desain: `docs/superpowers/specs/2026-11-10-tahap-3-design.md`
  - Rencana: `docs/superpowers/plans/2026-11-10-tahap-3.md`
  - Ledger (semua `Ruling:`): `docs/superpowers/plans/2026-11-10-tahap-3-ledger.md`

| Fitur | Cara pakai |
|---|---|
| Launcher | ⌥Space membuka panel. App yang sedang aktif tetap di depan. ⌘C, ⌘V, ⌘A, dan ⌘Z berfungsi di kolom pencarian. |
| Cari & buka aplikasi | Pencarian fuzzy (`vsc` → Visual Studio Code). Urutan hasil belajar dari pemakaian. |
| Kalkulator | Ketik `(2+3)*4/3`, lalu ⏎ untuk menyalin. Titik dan koma sama-sama diterima sebagai desimal. |
| Clipboard history | Ketik "clip" atau ⇧⌥C, lalu ⏎ untuk paste. Isi password manager tidak disimpan. |
| Window snapping | "Left Half", "Maximize", "Restore", dan lainnya. Shortcut ⌃⌥ mengikuti Rectangle. |
| Translator | Ketik "tr", ⏎, lalu tulis teks. Arah Indonesia ↔ Inggris dipilih otomatis, ⌘L membalik arah. Semuanya on-device. |
| AI chat | Ketik pertanyaan di root, lalu **Tab**. Model on-device, dengan jembatan terjemahan untuk bahasa Indonesia. |
| Snippets | Ketik nama atau keyword di root, lalu ⏎ untuk paste. Placeholder: `{date}`, `{time}`, `{datetime}`, `{clipboard}`. |
| Notes | "Open Notes", "Create Note", "Search Notes". Jendela floating Markdown dengan autosave. |
| **Settings** | ⌘, atau perintah "Settings". Bagian General, Appearance, Snippets, Scripts, Sync. |
| **Tema** | Settings › Appearance: preset (Default, Midnight, Paper, Sunset, Graphite), warna aksen, kepadatan kaca, dan mode System/Light/Dark. Perubahan langsung terlihat. |
| **Auto-expand snippet** | Ketik keyword snippet (misalnya `;addr`) di app mana pun, dan teksnya langsung diganti. Tidak berjalan di DOT sendiri atau di app yang dikecualikan (Settings › Snippets). Clipboard dikembalikan setelahnya. Editor snippet memperingatkan keyword yang bentrok. |
| **Script commands** | Skrip apa pun dengan header `# @dot.title` atau `# @raycast.title` di folder `Scripts/`, atau di folder tambahan (Settings › Scripts › Add Folder…). Mode `fullOutput` (output di panel), `compact`/`silent` (HUD), dan `inline` (subtitle diperbarui). Mendukung argumen (text, password, dropdown) dan `needsConfirmation`. Esc menghentikan skrip, output dibatasi 1 MB. ⌘⇧X menjadikan skrip executable. Perintah "Create Script Command". |
| **Sync iCloud** | Settings › Sync › "Store data in iCloud Drive" (**default mati**). Saat menyala: Snippets, Notes, Scripts, dan `settings.json` pindah ke iCloud Drive › DOT Launcher, dan clipboard di-backup tiap 6 jam (5 backup terbaru disimpan) dan saat app ditutup. Restore memakai dua kali tekan. |
| Menu bar | Status izin dan shortcut, Launch at Login, Hide Menu Bar Icon, Settings…, Quit. |

## Keputusan
- Nama: **DOT Launcher**. Bundle ID: `com.pace.DOTLauncher`. Target: **khusus macOS 27**.
- Build memakai SwiftPM + script, tanpa Xcode (hanya Command Line Tools). Tanpa dependensi eksternal. Pemakaian pribadi.
- Tidak memakai nama, logo, atau kode Raycast. Yang dibaca hanya format komentar `@raycast.*` agar skrip lama tetap jalan. Kalau keduanya ada, `@dot.*` yang menang.
- Shortcut ⌃⌥ (window) dan ⇧⌥C (clipboard) hanya aktif kalau Rectangle/Maccy tidak berjalan.
- **Data:**
  - Folder lokal `~/Library/Application Support/DOT Launcher/` menyimpan `launcher.sqlite` dan `clipboard.sqlite`. **SQLite tidak pernah ditaruh di iCloud.**
  - Snippets, Notes, Scripts, dan `settings.json` berada di folder data aktif: folder lokal, atau `iCloud Drive/DOT Launcher/` kalau sync menyala.
  - Pengaturan yang ikut sync ada di `settings.json`: tema, ikon menu bar, auto-expand, app yang dikecualikan, dan backup clipboard.
  - Yang khusus Mac ini disimpan di UserDefaults: status sync, folder skrip tambahan, dan posisi jendela.
- **Sync bersifat opt-in.** Kalau dimatikan, DOT sama sekali tidak membaca atau menulis iCloud Drive. Satu-satunya pengecualian adalah tombol "Delete iCloud Backups".
  - Pemindahan file selalu disalin dulu, diverifikasi isinya, baru yang lama dihapus. Kalau nama sudah ada, keduanya disimpan dan file yang masuk diberi akhiran `(from This Mac)` atau `(from iCloud)`.
  - Kalau `Backups/` sudah berisi backup saat sync dinyalakan (misalnya setelah reset), backup otomatis ditahan sampai dipilih "Restore from Backup" atau "Keep Current History".
  - Mematikan sync tidak menghapus backup di iCloud. Sync juga menolak dimatikan selama masih ada file yang belum terunduh dari iCloud.
  - Sebelum restore, database lokal disalin dulu ke `clipboard-before-restore.sqlite`.
- Paste snippet, AI, dan terjemahan bersifat **sementara**: isi clipboard sebelumnya dikembalikan. "Copy" bersifat permanen.
- Skrip dijalankan dengan argv langsung (tanpa shell) dan PATH dari login shell. Kode ANSI dibuang.

## Cara kerja
```
make test     # 180 test Core (Swift Testing)
make run      # build, tanda tangani, pasang ke ~/Applications, buka
make logs     # log stream subsystem com.pace.DOTLauncher (termasuk debug)
make reset-tcc
```
- Jangan pakai `swift run`. Tanpa bundle `.app`, TCC dan privasi pasteboard tidak berfungsi benar.
- **Struktur kode:**
  - `Sources/DOTLauncherCore` berisi logika murni yang dites. Tambahan tahap 3: `Settings/` (SettingsData, SettingsFile, Theme), `Scripts/` (ScriptMetadata, ScriptScanner, ANSI), `Snippets/KeywordExpander`, dan `Sync/` (ICloudPlaceholder, FolderMigration, BackupRotation), ditambah backup/restore di `SQLiteDatabase`.
  - `Sources/DOTLauncher` berisi app. Tambahan tahap 3: `Settings/` (SettingsStore, SettingsView, ThemeController), `Scripts/` (ScriptRunner, ScriptLibrary, HUD), `Snippets/` (KeystrokeMonitor, AutoExpandController), dan `Sync/SyncController`.
- **Data uji:** `defaults write com.pace.DOTLauncher DOTDataRootOverride <folder>` dan `DOTiCloudRootOverride <folder>` mengalihkan semua data ke folder uji. Settings dan menu bar lalu menampilkan "Test data folders in use". Sync menolak menyala kalau hanya override lokal yang diisi. Setelah selesai, hapus kedua key dan `syncEnabled`.

## Jebakan yang sudah ditemukan
- **Swift Testing di CLT:** plugin `TestingMacros` tidak dimuat otomatis. `Package.swift` menambahkan `-plugin-path`.
- **`@State` tidak bisa dipakai** (macro tanpa plugin di CLT). State view disimpan di model `@Observable` dan diakses lewat `@Bindable`.
- **Liquid Glass mengabaikan `appearance` NSView/NSWindow.** Mode Light/Dark dipaksa lewat `.environment(\.colorScheme)` di `ThemedRoot` ditambah tint kaca eksplisit. Tint aksen juga harus dibaca di `body` agar langsung berubah.
- **CGEventTap di Swift 6:** `CGEvent` tidak Sendable. Event diklasifikasi menjadi `TapEvent` di callback nonisolated, baru diteruskan ke main actor. Event yang dikirim DOT sendiri (backspace, ⌘V) dikenali dari PID-nya.
- **Auto-expand:** ⌘V harus dikirim langsung setelah backspace, tanpa jeda. Dengan jeda 140 ms, teks yang diketik setelah keyword muncul sebelum snippet (`x ;addr y` → `x  yJl. …`).
- **Skrip:** `ScriptRun` disimpan di registry statis. Kalau hanya dipegang referensi weak, run langsung hilang dan HUD tidak pernah muncul. Pembacaan environment login shell memakai deadline sebelum membaca output.
- **SQLite backup:** salinan dari database WAL diubah ke `journal_mode=DELETE`, dan file `-shm` sisa dihapus, supaya backup berupa satu file. Backup ditulis dulu di folder lokal, lalu dipindah ke iCloud.
- **Placeholder iCloud** (`.nama.icloud`) dikenali oleh store, oleh daftar backup, dan oleh migrasi. Placeholder tidak pernah disalin dan tidak pernah hilang dari daftar ("Downloading…"). Nama yang placeholder-nya ada dianggap **sudah terpakai**, karena file baru di path item yang di-evict akan menggantikan isinya di iCloud. `settings.json` tidak disimpan selama yang ada baru placeholder-nya.
- **Pemindahan yang terputus:** penanda `syncMoveInProgress` di UserDefaults dipasang sebelum memindah file. Saat app start, pemindahan diselesaikan ke arah yang dipilih. Kalau gagal di tengah, hanya file yang dipindah oleh proses itu yang dikembalikan.
- **Catatan/snippet dengan ID sama di dua tempat** diberi nama `<UUID> (from This Mac).md`, lalu langsung diberi ID baru (`adoptRenamedCopies`) supaya tetap terlihat.
- **`Process` dan grup proses:** setiap skrip berjalan di grup prosesnya sendiri (pgid = pid), dan `terminate()` menghentikan seluruh grup. Akhir skrip dilaporkan tanpa menunggu EOF pipe, karena proses latar belakang bisa memegang pipe berjam-jam (`ScriptProcess` di Core).
- **Uji UI dengan System Events:**
  - `entire contents` tidak melihat isi SwiftUI. Pakai path eksplisit, misalnya `checkbox 1 of scroll area 1 of group 1 of window "DOT Launcher Settings"`. Sidebar Settings adalah `button N of group 1`.
  - Tombol SwiftUI tidak punya AXTitle, jadi diklik berdasarkan urutan lalu dicek dengan screenshot.
  - `kind` adalah kata kunci AppleScript dan tidak bisa dipakai sebagai nama variabel.
  - Pakai dokumen TextEdit baru yang belum disimpan (`make new document`, `close front document saving no`).
- **Menu Edit wajib ada** agar ⌘C/⌘V di kolom teks berfungsi. Akibatnya, status item berada di **menu bar 2** dalam System Events.
- **Tanda tangan:** setiap build ditandatangani dengan sertifikat Apple Development, sehingga izin bertahan setelah rebuild. Sertifikat ini **kedaluwarsa 2027-02-04**. Kalau izin bermasalah, jalankan `make reset-tcc`.
- **zsh:** `log` adalah builtin zsh, jadi pakai `/usr/bin/log`. `FileManager` mengubah `/var` menjadi `/private/var`.

## Belum diuji / batasan yang diketahui
- **Sync dengan iCloud Drive asli sudah dicek sekali (10 Nov 2026, izin Pace, data di-backup dulu):** nyala → file pindah ke iCloud dan ter-upload (`ubiquitousItemIsUploaded`), backup clipboard utuh (21 clip, `integrity_check` ok), snippet/note tetap muncul, quit menulis backup, relaunch tanpa pertanyaan restore. Mati → file kembali identik, backup tetap di iCloud sampai "Delete iCloud Backups" ditekan. Setelahnya data dan iCloud dikembalikan seperti semula.
- **Auto-expand juga aktif di kolom pencarian DOT sendiri.** Mengetik keyword snippet (`;addr`) di launcher langsung mengembangkannya, jadi snippet tidak bisa dicari lewat keyword-nya. Belum diperbaiki.
- Placeholder dari "Optimize Mac Storage" yang asli dan edit dari iPhone/Files belum diuji. Perilakunya hanya disimulasikan dengan mengganti nama file.
- Auto-expand berjalan tanpa izin Input Monitoring baru di Mac ini. Di Mac lain, izin itu mungkin perlu diberikan (Settings › Snippets menampilkan statusnya).
- Paste memakai `kVK_ANSI_V`, jadi bisa meleset di layout keyboard non-QWERTY.
- Snapping app Chromium/Electron dan multi-monitor belum diuji manual.
- Clipboard belum mendukung gambar dan belum punya preview. Shortcut belum bisa diubah lewat UI. Kalkulator belum mendukung unit/kurs.

## Langkah berikutnya
1. Matikan auto-expand saat panel DOT sendiri yang aktif (lihat batasan di atas).
2. Riwayat AI chat yang persisten.
3. Clipboard: gambar, preview, pin/hapus dari panel.
4. Ubah shortcut lewat Settings.
