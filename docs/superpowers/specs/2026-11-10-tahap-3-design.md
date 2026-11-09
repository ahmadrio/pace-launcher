# Desain Tahap 3: Tema, Script Commands, Auto-expand Snippet, Sync iCloud

## Maksud
DOT Launcher adalah launcher macOS pribadi milik Pace (lihat `HANDOFF.md`). Tahap 1 dan 2 sudah ada di `main`.

Tahap 3 menambahkan empat hal:
- tampilan yang bisa diatur (tema)
- menjalankan skrip milik sendiri dari launcher
- snippet yang mengembang otomatis saat diketik
- data yang aman di iCloud Drive

Semuanya gratis, tanpa layanan pihak ketiga.

## Keputusan Pace
- Keempat fitur masuk tahap 3: **Tema, Auto-expand snippet, Script commands, Sync lewat iCloud**.
- **Hanya satu Mac.** Sync berarti data tersimpan di iCloud Drive: aman kalau Mac rusak atau di-reset, dan bisa dibuka dari iPhone atau iPad lewat app Files. Tidak perlu menangani edit bersamaan dari dua Mac.
- Data yang ikut: **Snippets & Notes, Pengaturan, Clipboard history, Script commands**.
- Script commands **kompatibel dengan format komentar skrip komunitas Raycast** (`@raycast.title`, dan seterusnya), sekaligus mendukung format DOT sendiri (`@dot.title`). Tidak memakai kode atau logo Raycast.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran:**
  - Semua fitur bisa dipakai dari keyboard.
  - Pengaturan ada di satu jendela Settings.
  - Data snippets, notes, skrip, dan pengaturan ikut ke iCloud saat sync dinyalakan.
  - Clipboard history punya backup di iCloud dan bisa dipulihkan.
- **Bukan sasaran:**
  - merge antar beberapa Mac
  - CloudKit (butuh Apple Developer Program berbayar)
  - app iOS
  - sync frekuensi pemakaian (`launcher.sqlite`, sifatnya per mesin)
  - mode skrip `inline` yang diperbarui otomatis di latar belakang (lihat Fitur 4)
- **Anti-sasaran:**
  - Data hilang atau tertimpa saat dipindah ke atau dari iCloud.
  - Database SQLite rusak karena diletakkan di folder sync.
  - Auto-expand berjalan di kolom password atau di dalam DOT sendiri.
  - Skrip berjalan tanpa sengaja. Contohnya, skrip yang meminta konfirmasi harus benar-benar dikonfirmasi.
  - Merusak perilaku tahap 1 dan 2, termasuk 122 test yang ada.

## Batasan teknis
Batasannya sama seperti tahap 2:
- macOS 27, hanya Command Line Tools.
- Tidak ada `@State` (macro-nya tidak tersedia di CLT); state UI disimpan di model `@Observable`.
- Tidak ada `#Preview`, tidak ada SwiftData.
- Swift 6 strict concurrency; target app memakai `defaultIsolation(MainActor)`.
- Logika murni ada di `DOTLauncherCore` dan dites dengan Swift Testing (TDD).
- Tanpa dependensi eksternal.
- Uji UI dilakukan otomatis lewat System Events dan screenshot.

Fakta di Mac ini: iCloud Drive aktif di `~/Library/Mobile Documents/com~apple~CloudDocs`.

## Fondasi: jendela Settings dan `settings.json`
- **Jendela Settings.** `NSWindow` biasa berisi SwiftUI, dibuka lewat:
  - perintah launcher "Settings"
  - item "Settings…" (⌘,) di menu bar dan menu app
- **Bagian di jendela Settings:**
  - **General:** ikon menu bar, Launch at Login
  - **Appearance:** tema
  - **Snippets:** auto-expand dan daftar app yang dikecualikan
  - **Scripts:** lokasi folder, Reload, Open in Finder
  - **Sync:** iCloud on/off, backup clipboard, Restore
- **Penyimpanan pengaturan.** Pengaturan yang perlu ikut sync pindah dari UserDefaults ke `settings.json` di folder data, yaitu tema, ikon menu bar, auto-expand, dan app yang dikecualikan.
  - Pengaturan yang khusus mesin ini tetap di UserDefaults: posisi jendela, lokasi folder data, dan status sync.
  - Nilai `showMenuBarIcon` yang lama dimigrasikan sekali dari UserDefaults.

## Fitur 1: Tema
- Pengaturan di Settings → Appearance:
  - **Preset**: Default, Midnight, Paper, Sunset, Graphite
  - **Warna aksen**: dipakai untuk sorotan baris terpilih, chip mode, dan kursor
  - **Kepekatan kaca**: slider 0–90%, yaitu tint di atas Liquid Glass
  - **Mode tampilan**: System, Light, Dark
- Memilih preset mengisi ketiga nilai lainnya. Mengubah salah satu nilai menjadikan tema "Custom".
- Berlaku untuk panel launcher, jendela Notes, dan editor snippet. Perubahan langsung terlihat tanpa restart.

## Fitur 2: Script commands
- **Folder skrip:**
  - Folder utama `<folder data>/Scripts/` ikut ke iCloud saat sync menyala.
  - Pace bisa menambah folder lain lewat Settings → Scripts → "Add Folder…", misalnya clone repo skrip komunitas. Daftar folder tambahan disimpan di UserDefaults karena khusus Mac ini, tidak ikut sync, dan tidak dipindah oleh fitur sync.
  - Semua folder dipindai rekursif sampai kedalaman 3. Folder tersembunyi dilewati. File tanpa metadata `title` (gambar, README) diabaikan.
  - Folder dibaca ulang setiap kali launcher dibuka, sama seperti snippets.
- **Metadata** dibaca dari baris komentar di awal file (`#` atau `//`), dengan prefiks `@raycast.` atau `@dot.`. Kunci yang didukung:
  - `title` (wajib)
  - `mode`: `fullOutput`, `compact`, `silent`, `inline`
  - `packageName`
  - `icon`: emoji, path file relatif terhadap skrip, atau absolut. URL diabaikan dan diganti ikon default.
  - `description`
  - `argument1` sampai `argument3`: JSON dengan `type` (`text`, `password`, atau `dropdown` beserta `data`), `placeholder`, `optional`, `percentEncoded`
  - `currentDirectoryPath`
  - `needsConfirmation`
  - `schemaVersion`
  - kunci lain (`author`, `refreshTime`, …) diabaikan tanpa error
- **Di launcher:**
  - Setiap skrip muncul di pencarian root sebagai perintah. Judulnya diambil dari `title`, subjudulnya dari `packageName` atau `description`, dan ikonnya dari `icon`.
  - Skrip yang tidak executable tetap muncul dengan pesan "not executable" dan aksi "Make Executable" (`chmod +x`).
  - Skrip berargumen: ⏎ membuka form argumen di panel (satu kolom per argumen, Tab untuk pindah, ⏎ untuk menjalankan). Argumen bertipe `password` disembunyikan. Argumen wajib harus diisi.
  - `needsConfirmation`: ⏎ pertama menampilkan "Press ↩ again to run".
- **Menjalankan skrip:**
  - Skrip dijalankan langsung sebagai proses, mengikuti shebang-nya. Direktori kerjanya `currentDirectoryPath` atau folder skrip.
  - PATH diambil dari login shell pengguna, dibaca sekali saat app start. App GUI hanya mendapat PATH minimal, sehingga `brew` dan `node` tidak akan ketemu tanpa langkah ini.
  - stdin ditutup. Kode ANSI di output dibuang.
  - Esc menghentikan skrip yang sedang berjalan.
- **Mode output:**
  - `fullOutput`: panel pindah ke tampilan output (monospace, mengalir saat skrip berjalan). Ada ⌘C untuk menyalin output dan Esc untuk berhenti atau kembali.
  - `compact` dan `silent`: panel menutup, lalu muncul HUD kecil di layar selama sekitar 2 detik berisi baris terakhir output (`compact`) atau "✓ <title>" (`silent`). Kalau skrip gagal, HUD menampilkan baris error terakhir.
  - `inline`: dijalankan sekali saat launcher dibuka (paling sering setiap 60 detik, timeout 10 detik), dan baris pertama outputnya menjadi subjudul baris skrip. Tidak ada refresh otomatis di latar belakang.
- **Perintah tambahan:**
  - "Create Script Command": membuat file template di folder Scripts lalu membukanya di editor default.
  - "Open Scripts Folder".
- **Logika yang dites di Core:** parser metadata (kedua prefiks, argumen JSON, kunci tak dikenal, file tanpa metadata) dan pembersih kode ANSI.

## Fitur 3: Auto-expand snippet
- Hanya untuk snippet yang punya keyword. Begitu urutan karakter yang diketik **berakhir dengan keyword** (dicocokkan persis, membedakan huruf besar-kecil), keyword dihapus dengan backspace sebanyak panjangnya, lalu isi snippet di-paste memakai `TextPaster.paste` (clipboard dikembalikan).
- Cara kerja: event tap keyboard yang hanya mendengar (tidak mengubah event). Izin yang dibutuhkan (Input Monitoring atau Accessibility) dicek dan diminta lewat API resmi. Status izin ditampilkan di Settings dan menu bar.
- Buffer ketikan direset saat:
  - klik mouse
  - tombol panah, Return, Tab, atau Esc
  - shortcut ⌘, ⌃, atau ⌥
  - pindah app
  - jeda mengetik lebih dari 5 detik
- Tidak pernah berjalan:
  - di DOT sendiri
  - di kolom password (Secure Input otomatis memblokir event tap)
  - di app yang dikecualikan di Settings (default: tidak ada)
- Toggle di Settings → Snippets, default **nyala** setelah izin diberikan.
- **Logika yang dites di Core:** pencocok keyword dengan buffer (keyword terpanjang menang, aturan reset, batas panjang buffer).

## Fitur 4: Sync lewat iCloud Drive
- **Toggle "Store data in iCloud Drive"** di Settings → Sync, default mati.
  - **Saat dinyalakan:** `Snippets/`, `Notes/`, `Scripts/`, dan `settings.json` dipindah dari `~/Library/Application Support/DOT Launcher/` ke `~/Library/Mobile Documents/com~apple~CloudDocs/DOT Launcher/`. Prosesnya: salin, verifikasi isinya identik, baru hapus yang lokal. Kalau nama file di tujuan sudah ada, keduanya disimpan (file yang masuk diberi akhiran) dan tidak ada yang ditimpa.
  - **Saat dimatikan:** dipindah balik dengan aturan yang sama.
  - Lokasi folder data aktif disimpan di UserDefaults.
- **SQLite tetap lokal.** `clipboard.sqlite` dan `launcher.sqlite` tidak pernah tinggal di folder iCloud.
- **Backup clipboard history** (kalau sync dan opsi "Include clipboard history" menyala):
  - Salinan konsisten dibuat dengan SQLite Online Backup API ke `iCloud/DOT Launcher/Backups/clipboard-<yyyyMMdd-HHmm>.sqlite`.
  - Waktunya: saat app start (kalau backup terakhir lebih tua dari 6 jam), setiap 6 jam, dan saat app ditutup.
  - **Rotasi:** 5 backup terbaru disimpan, yang lebih lama dihapus. Waktu backup terakhir dibaca dari nama file di iCloud, bukan disimpan per Mac.
  - **Melindungi backup yang ada.** Kalau sync dinyalakan dan folder `Backups/` di iCloud sudah berisi backup (misalnya setelah Mac di-reset dan DOT dipasang ulang), backup otomatis **ditahan**. Settings lalu menampilkan pilihan "Restore from backup (<tanggal>, <jumlah> clips)" atau "Keep current history". Backup otomatis baru berjalan lagi setelah Pace memilih. Dengan begitu, database lokal yang hampir kosong tidak pernah menimpa backup yang berisi.
  - Settings menampilkan waktu backup terakhir.
  - Tombol "Restore clipboard history…" memilih backup terbaru (atau backup lain dari daftar), lalu menimpa database lokal dengan isinya. Perlu dikonfirmasi dua kali. Sebelum ditimpa, database lokal disalin dulu ke `clipboard-before-restore.sqlite` di folder lokal.
  - **Saat sync atau "Include clipboard history" dimatikan,** backup di iCloud **tetap disimpan** demi keamanan, dan Settings menuliskannya dengan jelas. Tombol "Delete iCloud backups" (dikonfirmasi dua kali) menghapus semua backup clipboard kalau Pace ingin menghapusnya karena alasan privasi.
- **File yang di-"evict" iCloud.** Kalau "Optimize Mac Storage" aktif, iCloud bisa mengganti file dengan placeholder `.<nama>.icloud`. Store snippets, notes, dan skrip mengenali placeholder ini, meminta unduhan (`startDownloadingUbiquitousItem`), lalu menampilkan item tersebut setelah tersedia. Catatan tidak boleh hilang dari daftar diam-diam.
- **Perubahan dari luar** (misalnya catatan diedit di iPhone): snippets dan skrip dibaca ulang setiap launcher dibuka. Daftar notes dibaca ulang saat dicari. Catatan yang terbuka dimuat ulang saat jendela Notes ditampilkan, kalau file berubah dan tidak ada edit yang belum tersimpan.
- **Privasi:** clipboard history bisa berisi data sensitif. File di iCloud Drive dienkripsi Apple, tapi end-to-end hanya kalau Advanced Data Protection aktif. Settings menampilkan kalimat ini di samping opsi "Include clipboard history in backup" (default nyala, sesuai pilihan Pace).
- **Logika yang dites di Core:**
  - pengenalan nama placeholder `.icloud`
  - rencana migrasi folder (salin, verifikasi, hapus; menangani nama bentrok)
  - backup dan restore SQLite (backup lalu restore menghasilkan isi yang sama)

## Pengujian dengan data uji (keputusan Pace)
- Uji otomatis **tidak boleh menyentuh data asli Pace atau iCloud Drive aslinya**.
- App membaca dua override dari UserDefaults: `DOTDataRootOverride` (pengganti folder data lokal) dan `DOTiCloudRootOverride` (pengganti folder iCloud Drive). Keduanya bisa diisi dengan `defaults write com.pace.DOTLauncher …`. Selama override aktif:
  - semua data (snippets, notes, skrip, pengaturan, `clipboard.sqlite`, `launcher.sqlite`) dibaca dari dan ditulis ke folder uji
  - Settings dan menu bar menampilkan peringatan jelas "Test data folders in use"
- Sebelum uji: data asli di `~/Library/Application Support/DOT Launcher/` disalin ke folder backup lokal. Setelah uji: override dihapus dan app dibuka ulang memakai data asli.
- Satu cek terakhir dengan iCloud asli hanya dilakukan **setelah Pace mengizinkan** dan setelah datanya di-backup.

## Urutan pengerjaan
1. Fondasi (Settings dan `settings.json`)
2. Tema
3. Script commands
4. Auto-expand
5. Sync

Sync dikerjakan terakhir karena memindahkan folder yang dipakai fitur lain. Fondasi sudah menyiapkan "folder data aktif" yang bisa berpindah lokasi. Setiap milestone diakhiri dengan test Core hijau, uji UI otomatis, dan commit.

## Bagian yang ditentukan builder
- Warna persis setiap preset dan tampilan HUD.
- Panjang buffer auto-expand.
- Interval dan timeout yang tidak disebut di atas.
- Struktur file kode.
- Teks pesan.
- Isi template skrip.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- SQLite tidak pernah tinggal di iCloud; clipboard history di-backup berkala dan bisa di-restore.
- Sync dinyalakan dari Settings (default mati). Saat dinyalakan, data dipindah dengan aman tanpa ada yang ditimpa.
- Frekuensi pemakaian tidak ikut sync.
- Skrip `inline` diperbarui hanya saat launcher dibuka, tanpa proses latar belakang.
- Auto-expand langsung jalan begitu keyword lengkap diketik (tanpa menunggu spasi), hanya untuk snippet yang punya keyword.
- Pengaturan yang ikut sync pindah ke `settings.json`; yang khusus mesin tetap di UserDefaults.
- Lima preset tema: Default, Midnight, Paper, Sunset, Graphite.
- Backup clipboard berupa 5 salinan bertanggal yang dirotasi. Backup otomatis ditahan kalau di iCloud sudah ada backup, sampai Pace memilih Restore atau Keep.
- Mematikan sync tidak menghapus backup di iCloud; penghapusannya lewat tombol tersendiri.
- Folder skrip tambahan bisa dipilih (khusus Mac ini, tidak ikut sync) dan dipindai rekursif.
