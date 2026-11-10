# Handoff: DOT Launcher

Launcher macOS gratis ala Raycast, termasuk fitur yang di Raycast hanya ada di paket Pro. Dibuat untuk dipakai sendiri.

## Status (10 Nov 2026)
- **Tahap 1 dan 2** selesai dan sudah di-merge ke `main`.
- **Tahap 3** selesai dan sudah di-merge ke `main` (10 Nov 2026).
  - Desain: `docs/superpowers/specs/2026-11-10-tahap-3-design.md`
  - Rencana: `docs/superpowers/plans/2026-11-10-tahap-3.md`
  - Ledger (semua `Ruling:`): `docs/superpowers/plans/2026-11-10-tahap-3-ledger.md`
- **Tahap 4** selesai dan sudah di-merge ke `main` (10 Nov 2026).
  - Desain: `docs/superpowers/specs/2026-11-10-tahap-4-design.md`
  - Rencana: `docs/superpowers/plans/2026-11-10-tahap-4.md`
  - Ledger (semua `Ruling:` dan minor yang ditunda): `docs/superpowers/plans/2026-11-10-tahap-4-ledger.md`
- **Tahap 5** selesai dan sudah di-merge ke `main` (10 Nov 2026). Pace sudah meng-uninstall Raycast; DOT kini satu-satunya launcher.
  - Desain: `docs/superpowers/specs/2026-11-10-tahap-5-design.md`
  - Rencana: `docs/superpowers/plans/2026-11-10-tahap-5.md`
  - Ledger: `docs/superpowers/plans/2026-11-10-tahap-5-ledger.md`
- **Tahap 6** selesai dan sudah di-merge ke `main` (10 Nov 2026).
  - Desain: `docs/superpowers/specs/2026-11-10-tahap-6-design.md`
  - Rencana: `docs/superpowers/plans/2026-11-10-tahap-6.md`
  - Ledger: `docs/superpowers/plans/2026-11-10-tahap-6-ledger.md`
- **Tahap 7** selesai dan sudah di-merge ke `main` (10 Nov 2026).
  - Desain: `docs/superpowers/specs/2026-11-10-tahap-7-design.md`
  - Rencana: `docs/superpowers/plans/2026-11-10-tahap-7.md`
  - Ledger: `docs/superpowers/plans/2026-11-10-tahap-7-ledger.md`
- **Tahap 8** selesai dan sudah di-merge ke `main` (10 Nov 2026).
  - Desain: `docs/superpowers/specs/2026-11-10-tahap-8-design.md`
  - Rencana: `docs/superpowers/plans/2026-11-10-tahap-8.md`
  - Ledger: `docs/superpowers/plans/2026-11-10-tahap-8-ledger.md`
- **Tahap 9** selesai dan sudah di-merge ke `main` (10 Nov 2026).
  - Desain: `docs/superpowers/specs/2026-11-10-tahap-9-design.md`
  - Rencana: `docs/superpowers/plans/2026-11-10-tahap-9.md`
  - Ledger: `docs/superpowers/plans/2026-11-10-tahap-9-ledger.md`
- **Tahap 10** selesai dan sudah di-merge ke `main` (10 Nov 2026).
  - Desain: `docs/superpowers/specs/2026-11-10-tahap-10-design.md`
  - Rencana: `docs/superpowers/plans/2026-11-10-tahap-10.md`
  - Ledger: `docs/superpowers/plans/2026-11-10-tahap-10-ledger.md`
- **Tahap 11** selesai dan sudah di-merge ke `main` (10 Nov 2026).
  - Desain: `docs/superpowers/specs/2026-11-10-tahap-11-design.md`
  - Rencana: `docs/superpowers/plans/2026-11-10-tahap-11.md`
  - Ledger: `docs/superpowers/plans/2026-11-10-tahap-11-ledger.md`
- **Tahap 12** selesai di branch `tahap-12` (10 Nov 2026), menunggu keputusan merge.
  - Desain: `docs/superpowers/specs/2026-11-10-tahap-12-design.md`
  - Rencana: `docs/superpowers/plans/2026-11-10-tahap-12.md`
  - Ledger: `docs/superpowers/plans/2026-11-10-tahap-12-ledger.md`

| Fitur | Cara pakai |
|---|---|
| Launcher | ⌥Space membuka panel. App yang sedang aktif tetap di depan. ⌘C, ⌘V, ⌘A, dan ⌘Z berfungsi di kolom pencarian. |
| Cari & buka aplikasi | Pencarian fuzzy (`vsc` → Visual Studio Code). Urutan hasil belajar dari pemakaian. |
| Kalkulator | Ketik `(2+3)*4/3`, lalu ⏎ untuk menyalin. Titik dan koma sama-sama diterima sebagai desimal. Hasil ditampilkan dengan pemisah ribuan locale (`1.500.001`), tetapi disalin tanpa pemisah. **Konversi unit**: `10 km to mi`, `100 f in c`, `1 GiB to MB`, `3 meters ke feet` (panjang, massa, suhu, volume, luas, kecepatan, waktu, data). **Kurs**: `100 usd to idr`, `€50 in usd`, `$25` (ke mata uang locale), kurs dari ExchangeRate-API; hasil di bawah 1 memakai 3 digit signifikan (`1 idr to usd` = 0,0000553 USD). **Singkatan angka**: `1jt + 500rb`, `10k usd to idr`, `Rp 50rb`, `1 juta rupiah to usd` (k/rb/ribu, jt/juta, miliar, triliun, thousand/million/billion/trillion). `Mb`/`Gb` = bit, `mb`/`MB` = byte. ⏎ menyalin angka tanpa pemisah ribuan. **Tanggal & jam**: `now + 3 days`, `today + 2 weeks`, `besok + 1 bulan`, `days until 17 aug` / `hari menuju 17 agustus` (⏎ menyalin angkanya), `time in tokyo` / `jam di tokyo`, `5pm in london`, `23.00 wib in tokyo` (menandai hari yang berbeda), **selisih** `17 aug - 1 jan` / `days between … and …` (hari absolut; tanpa tahun = tahun ini). Zona: WIB/WITA/WIT, UTC/GMT, nama kota, dan daftar tetap singkatan (EST, PST, JST, AEST, IST, …) yang berarti jam kota acuannya saat itu, berlabel offset: "New York (UTC−4)". |
| Clipboard history | Ketik "clip" atau ⇧⌥C, lalu ⏎ untuk paste. Isi password manager tidak disimpan. **Gambar** ikut tercatat (PNG di `Clipboard Images/`, maks. 20 MB / 50 megapiksel). Preview clip terpilih di kanan. ⌘P pin/unpin, ⌃X hapus (dua kali), **⌘⇧↩ paste sebagai teks polos** (tanpa format; tidak menambah clip baru). Settings › General › Clipboard History: **Keep history** (Forever … 1 day; clip yang di-pin tidak pernah dihapus; mempersingkat meminta konfirmasi dengan jumlah clip) dan **Clear History…** (dua kali tekan). |
| Window snapping | "Left Half", "Maximize", "Restore", dan lainnya. Shortcut ⌃⌥ mengikuti Rectangle. |
| Translator | Ketik "tr", ⏎, lalu tulis teks. Arah Indonesia ↔ Inggris dipilih otomatis, ⌘L membalik arah. Semuanya on-device. |
| AI chat | Ketik pertanyaan di root, lalu **Tab**. Model on-device, dengan jembatan terjemahan untuk bahasa Indonesia. **Tersimpan otomatis**: "AI Chat History" (atau ⌘Y di mode AI) untuk mencari, membuka, dan melanjutkan chat lama. ⌃X hapus satu, ⌘⇧⌫ hapus semua. |
| Snippets | Ketik nama atau keyword di root, lalu ⏎ untuk paste. Placeholder: `{date}`, `{time}`, `{datetime}`, `{clipboard}`. |
| Notes | "Open Notes", "Create Note", "Search Notes". Jendela floating Markdown dengan autosave. |
| **Settings** | ⌘, atau perintah "Settings". Bagian General, Appearance, **Shortcuts**, Snippets, **Quicklinks**, Scripts, Sync. |
| **Perintah sistem** | "Lock Screen" (⌃⌘Q macOS), "Sleep" / "Sleep Displays" (`pmset`), "Start Screen Saver", "Log Out" (⇧⌘Q; ↩ dua kali selama pesan "Press ↩ again to log out" masih tampil, lalu dialog macOS; mengetik atau membuka ulang panel membatalkan ↩ pertama). Alias `kunci`, `tidur`, `keluar`. Empat yang pertama bisa diberi shortcut global. Restart, Shut Down, Empty Trash, dan Dark Mode **belum ada**: butuh izin Automation/Full Disk Access (tanya Pace dulu). |
| **Emoji** | Perintah "Search Emoji" (bisa diberi shortcut global): cari dengan nama atau kata sehari-hari (`cinta`, `ketawa`, `thanks`, `jepang`), ⏎ menempel ke app sebelumnya (clipboard dikembalikan), ⌘C menyalin. Emoji yang sering dipakai naik; tanpa ketikan, wajah dulu. **Skin tone:** ⌘T di picker menggilir Default → Light → … → Dark (footer menyebut pilihannya), atau Settings › General › Emoji; hanya 134 emoji dasar Unicode (tangan, orang) yang berubah, ☝️ jadi ☝🏽 tanpa variation selector. Pemakaian dicatat per emoji dasar, jadi urutan tidak hilang saat tone diganti. Data dari properti Unicode Swift + bendera dari kode wilayah; tanpa emoji gabungan (keluarga, pasangan). |
| **Quicklinks** | URL tersimpan dengan `{query}` (Settings › Quicklinks atau perintah "Create Quicklink"). Ketik `gh dot launcher` untuk langsung mencari di GitHub; keyword saja (`g`) tidak mengangkat quicklink di atas app, karena quicklink diranking dari namanya; memilih quicklink lewat namanya meminta teksnya dulu; quicklink tanpa `{query}` langsung dibuka. Teks di-percent-encode. Bawaan: Google (`g`), YouTube (`yt`), GitHub (`gh`), Google Maps (`maps`). Disimpan di `settings.json` (ikut sync); **"Open with"** per quicklink (browser terpasang; browser yang hilang → browser default + HUD); entri tulisan tangan tanpa `id` tetap terbaca (id diturunkan dari nama + URL), URL non-ASCII (`bücher.de`) diterima, spasi ditolak. |
| **Shortcuts** | Settings › Shortcuts: klik, tekan kombinasi baru. Esc batal, ⌫ hapus. Konflik dengan shortcut DOT lain atau macOS ditolak. Open DOT Launcher wajib punya shortcut. Shortcut default clipboard/jendela tetap mati selama Maccy/Rectangle berjalan; kombinasi pilihan sendiri tidak. Grup **Commands**: Translate, AI Chat, AI Chat History, Open/Create/Search Notes, Search/Create Snippet, Settings, Search Emoji, Lock Screen, Sleep, Sleep Displays, Start Screen Saver (default kosong). Grup **Scripts**: setiap script command (default kosong); skrip dengan konfirmasi dijalankan dengan menekan shortcut-nya dua kali, skrip berargumen membuka form, `fullOutput` membuka panel, sisanya berjalan dengan HUD. Shortcut skrip yang filenya hilang tetap tersimpan ("Not found on this Mac") dan aktif lagi begitu file kembali (folder skrip dipantau, termasuk folder yang baru muncul setelah DOT berjalan). Shortcut standar app (⌘C, ⌘V, ⌘Q, ⌘1–9, …) ditolak, juga kalau ditulis langsung di `settings.json`. |
| **Tema** | Settings › Appearance: preset (Default, Midnight, Paper, Sunset, Graphite), warna aksen, kepadatan kaca, dan mode System/Light/Dark. Perubahan langsung terlihat. |
| **Auto-expand snippet** | Ketik keyword snippet (misalnya `;addr`) di app mana pun, dan teksnya langsung diganti. Tidak berjalan di DOT sendiri atau di app yang dikecualikan (Settings › Snippets). Clipboard dikembalikan setelahnya. Editor snippet memperingatkan keyword yang bentrok. |
| **Script commands** | Skrip apa pun dengan header `# @dot.title` atau `# @raycast.title` di folder `Scripts/`, atau di folder tambahan (Settings › Scripts › Add Folder…). Mode `fullOutput` (output di panel), `compact`/`silent` (HUD), dan `inline` (subtitle diperbarui). Mendukung argumen (text, password, dropdown) dan `needsConfirmation`. Esc menghentikan skrip, output dibatasi 1 MB. ⌘⇧X menjadikan skrip executable. Perintah "Create Script Command". |
| **Sync iCloud** | Settings › Sync › "Store data in iCloud Drive" (**default mati**). Saat menyala: Snippets, Notes, Scripts, dan `settings.json` pindah ke iCloud Drive › DOT Launcher, dan clipboard di-backup tiap 6 jam (5 backup terbaru disimpan) dan saat app ditutup. Restore memakai dua kali tekan. |
| Menu bar | Status izin dan shortcut, Launch at Login, Hide Menu Bar Icon, Settings…, Quit. |

## Keputusan
- Nama: **DOT Launcher**. Bundle ID: `com.pace.DOTLauncher`. Target: **khusus macOS 27**.
- Build memakai SwiftPM + script, tanpa Xcode (hanya Command Line Tools). Tanpa dependensi eksternal. Pemakaian pribadi.
- Tidak memakai nama, logo, atau kode Raycast. Yang dibaca hanya format komentar `@raycast.*` agar skrip lama tetap jalan. Kalau keduanya ada, `@dot.*` yang menang.
- Shortcut **default** ⌃⌥ (window) dan ⇧⌥C (clipboard) hanya aktif kalau Rectangle/Maccy tidak berjalan. Kombinasi yang diganti di Settings › Shortcuts selalu aktif.
- **Data:**
  - Folder lokal `~/Library/Application Support/DOT Launcher/` menyimpan `launcher.sqlite`, `clipboard.sqlite`, `chat.sqlite`, dan `Clipboard Images/`. **SQLite dan gambar clipboard tidak pernah ditaruh di iCloud**, dan tidak ikut backup iCloud (backup hanya `clipboard.sqlite`; clip gambar hasil restore tampil "Image unavailable").
  - Snippets, Notes, Scripts, dan `settings.json` berada di folder data aktif: folder lokal, atau `iCloud Drive/DOT Launcher/` kalau sync menyala.
  - Pengaturan yang ikut sync ada di `settings.json`: tema, ikon menu bar, auto-expand, app yang dikecualikan, backup clipboard, dan `shortcuts` (id → `"ctrl+opt+left"`, `""` = tanpa shortcut, id tidak ada = default).
  - Yang khusus Mac ini disimpan di UserDefaults: status sync, folder skrip tambahan, dan posisi jendela.
- **Sync bersifat opt-in.** Kalau dimatikan, DOT sama sekali tidak membaca atau menulis iCloud Drive. Satu-satunya pengecualian adalah tombol "Delete iCloud Backups".
- **Internet hanya untuk kurs:** `GET https://open.er-api.com/v6/latest/USD`, hanya saat konversi mata uang tampil dan cache (`exchange-rates.json`, lokal) belum ada atau lebih dari 12 jam; gagal → tunggu 1 menit atau Retry. Kurs lebih dari 7 hari ditandai "rates may be outdated". Uji offline: `DOTRatesURLOverride`.
  - Pemindahan file selalu disalin dulu, diverifikasi isinya, baru yang lama dihapus. Kalau nama sudah ada, keduanya disimpan dan file yang masuk diberi akhiran `(from This Mac)` atau `(from iCloud)`.
  - Kalau `Backups/` sudah berisi backup saat sync dinyalakan (misalnya setelah reset), backup otomatis ditahan sampai dipilih "Restore from Backup" atau "Keep Current History".
  - Mematikan sync tidak menghapus backup di iCloud. Sync juga menolak dimatikan selama masih ada file yang belum terunduh dari iCloud.
  - Sebelum restore, database lokal disalin dulu ke `clipboard-before-restore.sqlite`.
- Paste snippet, AI, dan terjemahan bersifat **sementara**: isi clipboard sebelumnya dikembalikan. "Copy" bersifat permanen.
- Skrip dijalankan dengan argv langsung (tanpa shell) dan PATH dari login shell. Kode ANSI dibuang.

## Cara kerja
```
make test     # 359 test Core (Swift Testing)
make run      # build, tanda tangani, pasang ke ~/Applications, buka
make logs     # log stream subsystem com.pace.DOTLauncher (termasuk debug)
make reset-tcc
```
- Jangan pakai `swift run`. Tanpa bundle `.app`, TCC dan privasi pasteboard tidak berfungsi benar.
- **Struktur kode:**
  - `Sources/DOTLauncherCore` berisi logika murni yang dites. Tambahan tahap 3: `Settings/` (SettingsData, SettingsFile, Theme), `Scripts/` (ScriptMetadata, ScriptScanner, ANSI), `Snippets/KeywordExpander`, dan `Sync/` (ICloudPlaceholder, FolderMigration, BackupRotation), ditambah backup/restore di `SQLiteDatabase`. Tambahan tahap 4: `Chat/` (ChatStore, ChatTitle), `Clipboard/` (ClipImage, ClipStats, file gambar di ClipboardStore), dan `Hotkeys/` (ShortcutID, Shortcuts, `KeyCombo.stringValue`). Tambahan tahap 5: `Calculator/` (Converter, MeasureUnit, ConversionFormat), `Currency/` (ExchangeRates, CurrencyNames), `Hotkeys/CommandShortcut` + `Shortcuts.registrationPlan`, `Clipboard/ClipboardRetention`, dan `Support/RunToken`.
  - `Sources/DOTLauncher` berisi app. Tambahan tahap 3: `Settings/` (SettingsStore, SettingsView, ThemeController), `Scripts/` (ScriptRunner, ScriptLibrary, HUD), `Snippets/` (KeystrokeMonitor, AutoExpandController), dan `Sync/SyncController`. Tambahan tahap 4: riwayat di `AI/AIChatController` (lanjut chat via `LanguageModelSession(transcript:)`), `Clipboard/ClipPreviewView`, dan `Settings/ShortcutsSettings` (ShortcutRecorder); `HotKeyCenter` kini `@Observable` dan `AppDelegate.applyShortcuts()` mendaftarkan shortcut dari settings. Tambahan tahap 5: `Calculator/RatesService`, `Clipboard/ClipboardMaintenance` (retensi, Clear History, file yatim), dan baris konversi di `UI/LauncherSearch`.
- **Data uji:** `defaults write com.pace.DOTLauncher DOTDataRootOverride <folder>` dan `DOTiCloudRootOverride <folder>` mengalihkan semua data ke folder uji. Settings dan menu bar lalu menampilkan "Test data folders in use". Sync menolak menyala kalau hanya override lokal yang diisi. Setelah selesai, hapus kedua key dan `syncEnabled`.

## Jebakan yang sudah ditemukan
- **Swift Testing di CLT:** plugin `TestingMacros` tidak dimuat otomatis. `Package.swift` menambahkan `-plugin-path`.
- **`@State` tidak bisa dipakai** (macro tanpa plugin di CLT). State view disimpan di model `@Observable` dan diakses lewat `@Bindable`.
- **Liquid Glass mengabaikan `appearance` NSView/NSWindow.** Mode Light/Dark dipaksa lewat `.environment(\.colorScheme)` di `ThemedRoot` ditambah tint kaca eksplisit. Tint aksen juga harus dibaca di `body` agar langsung berubah.
- **Sudut panel kaca:** panel borderless yang bisa menjadi key (`canBecomeKey = true`) mendapat garis tepi dari sistem. Garis itu memotong sudut kaca dengan lengkung yang lebih sempit dan bergerigi. `invalidateShadow()` tidak membantu. Solusinya, kaca dibungkus view yang layer-nya di-clip dengan radius yang sama (24, `.continuous`). Cara mengeceknya otomatis: ambil screenshot panel di atas latar polos, lalu ukur jarak piksel tergelap di diagonal tiap sudut. Jaraknya harus minimal 6 pt dari sudut, dan garis yang rusak hanya 0,5–4,5 pt.
- **CGEventTap di Swift 6:** `CGEvent` tidak Sendable. Event diklasifikasi menjadi `TapEvent` di callback nonisolated, baru diteruskan ke main actor. Event yang dikirim DOT sendiri (backspace, ⌘V) dikenali dari PID-nya.
- **Auto-expand:** ⌘V harus dikirim langsung setelah backspace, tanpa jeda. Dengan jeda 140 ms, teks yang diketik setelah keyword muncul sebelum snippet (`x ;addr y` → `x  yJl. …`).
- **"Di DOT sendiri" tidak bisa dicek dari app terdepan.** Panel DOT (launcher, Notes, editor snippet) non-activating, jadi app di belakangnya tetap terdepan. `AutoExpandRule` juga menolak saat DOT punya jendela key (`NSApp.keyWindow`).
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
- **Store actor + aksi `.stay`:** `.stay` langsung me-refresh daftar, padahal `ChatStore`/`ClipboardStore` adalah actor. Hapus/pin dijalankan dalam `Task`, lalu daftar di-refresh setelah `await`.
- **Merekam shortcut:** semua hotkey DOT dilepas selama merekam (kalau tidak, ⌥Space ditangkap Carbon sebelum sampai ke jendela). Perekam hanya membaca tombol dari jendela Settings, berhenti saat Settings kehilangan fokus, dan batal sendiri kalau Settings tidak mendapat fokus dalam 1 detik, supaya hotkey tidak pernah tertahan. Kombinasi yang dipegang app lain secara global (Rectangle: ⌃⌥←; di Mac Pace juga ⌃⌥⌘M) tidak pernah sampai ke DOT, jadi tidak bisa direkam selama app itu berjalan.
- **SQLite macOS memakai `secure_delete = FAST` secara default:** teks pendek yang dihapus sudah ditimpa, tetapi halaman overflow tidak. `chat.sqlite` dan `clipboard.sqlite` kini memakai `secure_delete = ON`, dan setiap penghapusan menjalankan `wal_checkpoint(TRUNCATE)` (koneksi tetap terbuka, jadi WAL menyimpan halaman lama). Untuk clipboard, indeks FTS5 juga di-`optimize`, karena tanpa itu trigram teks yang dihapus tetap ada di `clips_fts_data` bersama tombstone-nya. Test memeriksa saat store masih terbuka.
- **Angka berpemisah ribuan di konversi mengikuti locale:** di en_ID `Rp 50.000` = 50000 dan `1,5 kg` = 1,5. Pola grup (`1.500.000,75`) dicek dulu; selain itu "." dan "," sama-sama desimal seperti kalkulator. Input konversi maksimal 100 karakter (teks panjang yang ditempel tidak diparse). Kode/nama mata uang hanya boleh di **belakang** angka (`8 php`); di depan hanya simbol (`$`, `Rp`, `€`), supaya `php 8.3` tetap pencarian.
- **⌘Space:** macOS tetap mendaftarkan ⌘Space (non-eksklusif) walaupun shortcut Spotlight dimatikan, sehingga pendaftaran eksklusif gagal `-9878`. `HotKeyCenter` lalu mendaftar bersama (status `.shared`, catatan abu-abu di Settings).
- **Foundation `UnitVolume.cups` = 240 ml** (legal cup). DOT memakai US cup 236,588 ml lewat unit sendiri. "pound" adalah massa; poundsterling ditulis `gbp`/`£`.
- **System Events `frontmost`** tidak bisa dipercaya untuk app tanpa Dock seperti DOT (selalu terbaca "Finder"). Cek fokus lewat `AXMain`/`AXFocusedWindow` atau efeknya.
- **Uji UI Settings:** Settings yang dibuka dari launcher tidak membuat DOT jadi app aktif, dan klik AX juga tidak. Sebelum mengirim tombol keyboard, jalankan `tell application id "com.pace.DOTLauncher" to activate`. Tombol di Settings › Shortcuts punya `AXIdentifier` (`shortcut-<id>`, `reset-<id>`).
- **Jangan tekan ⌥Space di atas Finder saat launcher dipindah ke kombinasi lain:** Finder membuka Quick Look layar penuh.
- **Registry hotkey memakai id, bukan judul:** `HotKeyCenter` dikunci dengan `ShortcutID.rawValue` (`script.tools/deploy.sh`), karena dua skrip bisa berjudul sama. Menu bar dan log memakai `title`.
- **Singkatan angka vs unit:** unit selalu dicek lebih dulu, jadi `10k to c` adalah kelvin dan `1 m to ft` meter. Singkatan hanya dipakai kalau sisanya bukan unit (`10k usd`, `1k km`). `M`/`B`/`T` sengaja tidak didukung.
- **Translation framework tidak berhenti saat dibatalkan:** panggilan terjemahan yang sedang berjalan tetap selesai. Karena itu jawaban diterjemahkan balik per paragraf (`MarkdownSegments.translateProse`), dengan cek pembatalan sebelum tiap paragraf. Esc saat "Translating…" berhenti di paragraf berikutnya dan menyimpan jawaban bahasa Inggris (`ChatRunEnd`). Membuka chat yang sedang menjawab menunggu paling lama satu paragraf.
- **Snapshot clipboard tidak membaca TIFF di samping PNG:** membaca TIFF yang ditawarkan lazy akan membuatnya di tengah paste (auto-expand sensitif terhadap jeda). Snapshot menyalin PNG saja dan menawarkan TIFF lazy lagi saat restore (`ClipboardFilter.snapshotTypes`).
- **Ketikan uji UI harus dijaga:** panel DOT bisa tertutup di antara langkah, dan ketikan berikutnya jatuh ke app terdepan (Warp: ⌘N membuka jendela baru). Kirim tombol hanya setelah memastikan `AXFocusedUIElement` DOT adalah kolom teks. Jangan kirim Esc/⌘W tanpa penjaga: Esc di terminal tempat Claude Code berjalan menghentikan sesi. Tutup Settings lewat tombol close AX.
- **Menunggu "Translating…" di uji UI:** pakai OCR Vision (`VNRecognizeTextRequest`) pada screenshot panel, lalu kirim Esc dari alat yang sama.
- **AX `set value` tidak sampai ke binding SwiftUI `TextField`:** di uji UI Settings, ketik sungguhan lewat penjaga yang memastikan app terdepan menurut `NSWorkspace.frontmostApplication` adalah DOT (System Events `frontmost` salah untuk app tanpa Dock) dan field yang dituju punya fokus.
- **⌃⌘Q / ⇧⌘Q adalah shortcut menu Apple milik app terdepan:** DOT menyembunyikan diri dulu (`NSApp.hide`) dan menunggu fokus lepas sebelum mengirimnya; kalau tidak lepas, HUD. Kedua kombinasi itu ditolak sebagai shortcut DOT, karena DOT akan menangkap kirimannya sendiri. Lock dan Log Out sungguhan belum pernah dijalankan saat uji.
- **Konfirmasi "press ↩ again" mempertahankan baris yang dipilih:** `.stay` mengingat id baris sebelum `refresh()`.
- **Perintah sistem tidak pernah dijalankan saat uji:** `defaults write com.pace.DOTLauncher DOTSystemCommandDryRun -bool true` membuat DOT hanya mencatat "system command … (dry run)". Hapus lagi setelah uji. Uji dulu yang paling ringan (screen saver) untuk memastikan flag-nya terbaca.
- **Uji quicklink tanpa membuka browser:** app penangkap kecil dengan skema `dott7://` mencatat URL yang diterima. LaunchServices menolak mengikat skema untuk app di folder sementara (`launch-disabled in-temp-dir`), jadi app itu didaftarkan dari `~/Library/Caches/dot-launcher-tests` lalu dicabut (`lsregister -u`) dan dihapus.
- **`URL(string:)` longgar:** spasi di path di-encode diam-diam, host non-ASCII jadi punycode. Quicklink menolak template yang berisi spasi, lalu memakai parsing longgar (supaya `bücher.de` dan `|` diterima). `URL.host()` mengembalikan bentuk percent-encoded (`b%C3%BCcher.de`); URL yang dibuka memakai punycode (`absoluteString`).
- **Kalkulator tanggal (`DateQuery`) dites dengan `now`, zona waktu, dan locale yang ditetapkan.** en_ID memakai titik untuk jam ("14.59"). `TimeZoneNames` tidak lagi memakai `TimeZone(abbreviation:)`: Foundation tidak mengenal WIB/WITA/AEST, memetakan WIT ke Jakarta (padahal Jayapura) dan UTC ke GMT, serta mengenal kata biasa (EAT, CAT, ART). Singkatan berasal dari tabel tetap; `kolkata` butuh alias karena macOS memakai `Asia/Calcutta`. Jam harus berisi menit atau am/pm, supaya `10 in in cm` tetap konversi.
- **FSEvents melaporkan path asli** (`/private/tmp`, target symlink): folder skrip diresolusi dengan `realpath` sebelum dibandingkan (`ScriptFolderEvents.resolved`).
- **Host quicklink untuk tampilan diambil dari template** (`displayHost`), karena URL jadinya memakai punycode (`xn--bcher-kva.de`).
- **Nama emoji Unicode kadang kuno** ("HEAVY BLACK HEART"): `EmojiCatalog` memakai tabel kecil nama + kata kunci populer untuk sekitar 40 emoji.
- **Folder skrip dipantau FSEvents** (`ScriptFolderWatcher`, jeda 0,5 detik, `UseCFTypes | FileEvents`). Folder yang belum ada dipantau langsung (FSEvents melaporkan saat folder itu dibuat; induknya sengaja tidak dipantau karena untuk folder tambahan bisa berarti seluruh `~`); hanya path yang relevan (`ScriptFolderEvents.isRelevant`: tanpa komponen tersembunyi, maksimal kedalaman pemindai) memicu pembacaan ulang. Shortcut didaftarkan ulang hanya kalau kunci/judul skrip berubah (`ScriptShortcut.fingerprint`).
- **Dokumen TextEdit uji:** `make new document with properties {name: …}` memunculkan dialog "You don't own the file" saat isinya diubah. Klik Cancel lalu tutup dengan `saving no`.
- **Clipboard di uji:** pakai alat kecil (Swift, `NSPasteboard.pasteboardItems`) yang menyimpan semua tipe tiap item ke plist lalu memulihkannya, dan bandingkan hash-nya sebelum/sesudah. Selama `DOTDataRootOverride` aktif, salinan Pace masuk ke database uji, jadi kembalikan app ke data asli setelah setiap uji UI.

## Belum diuji / batasan yang diketahui
- **Sync dengan iCloud Drive asli sudah dicek sekali (10 Nov 2026, izin Pace, data di-backup dulu):** nyala → file pindah ke iCloud dan ter-upload (`ubiquitousItemIsUploaded`), backup clipboard utuh (21 clip, `integrity_check` ok), snippet/note tetap muncul, quit menulis backup, relaunch tanpa pertanyaan restore. Mati → file kembali identik, backup tetap di iCloud sampai "Delete iCloud Backups" ditekan. Setelahnya data dan iCloud dikembalikan seperti semula.
- Placeholder dari "Optimize Mac Storage" yang asli dan edit dari iPhone/Files belum diuji. Perilakunya hanya disimulasikan dengan mengganti nama file.
- Auto-expand berjalan tanpa izin Input Monitoring baru di Mac ini. Di Mac lain, izin itu mungkin perlu diberikan (Settings › Snippets menampilkan statusnya).
- Paste memakai `kVK_ANSI_V`, jadi bisa meleset di layout keyboard non-QWERTY.
- Snapping app Chromium/Electron dan multi-monitor belum diuji manual.
- Kalkulator belum mendukung kripto dan singkatan huruf tunggal selain `k` (`M`, `B`, `T` sengaja ditolak). Kurs tanpa target hanya untuk simbol, nama, dan 21 kode umum; kode lain butuh target (`10 nok to idr`).
- Di Mac Pace, ⌃⌥⌘M dipakai app lain sehingga tidak bisa direkam.
- Gambar clipboard tidak dibatasi total ukurannya (riwayat tanpa batas, sama seperti teks).
- Konflik shortcut dengan app lain hanya terdeteksi saat macOS menolak mendaftarkannya ("Couldn't register"); app yang menangkap kombinasi lewat event tap tidak terdeteksi.

## Langkah berikutnya
1. Minor yang ditunda di ledger tahap 12 (dan sisa: gambar dibaca di main thread sebelum cek 20 MB, konflik dengan app yang memakai event tap, shortcut skrip yang hilang tidak memberi tanda saat ditekan).
2. Restart, Shut Down, Empty Trash, Toggle Dark Mode: **perlu keputusan Pace** soal izin Automation (Apple Events ke loginwindow/Finder/System Events) atau Full Disk Access.
3. Ide fitur berikutnya (usulan Claude, perlu keputusan Pace): profil browser per quicklink, skin tone per emoji.
