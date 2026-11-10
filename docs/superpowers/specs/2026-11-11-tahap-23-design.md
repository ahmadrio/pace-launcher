# Desain Tahap 23: Sambutan, Izin, dan Cek Update

## Maksud
Tahap ketiga dari rencana rilis publik. Orang yang mengunduh PACE Launcher dari GitHub membuka app, lalu tidak melihat apa-apa: PACE hanya punya ikon di menu bar, tanpa ikon Dock dan tanpa jendela. Mereka juga tidak tahu izin mana yang dibutuhkan dan kenapa. Tahap ini menambahkan:
1. **Jendela sambutan** saat pertama dibuka: cara membuka launcher, status izin yang diperbarui langsung, dan tombol ke System Settings.
2. **Cek update** lewat GitHub Releases, karena app tanpa notarisasi tidak punya jalur update lain. App hanya memberi tahu dan membuka halaman unduhan; ia tidak pernah memasang apa pun sendiri.

Pace memilih langsung mulai, jadi semua detail di bawah adalah **keputusan Claude** dan bisa dikoreksi.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - Pengguna baru tahu dalam satu layar: PACE ada di menu bar, ⌥Space membuka launcher, dan izin apa yang perlu diberikan untuk fitur apa.
  - Status izin di jendela itu berubah sendiri begitu izin diberikan di System Settings, tanpa menutup jendela.
  - Pengguna tahu ada versi baru tanpa harus mengecek GitHub sendiri.
  - Cek update bisa dimatikan, dan permintaan jaringannya dijelaskan di app dan di dokumen.
- **Bukan sasaran**
  - Memasang update otomatis (Sparkle atau sejenisnya). Tanpa notarisasi, pengguna tetap harus Open Anyway untuk setiap versi.
  - Catatan rilis di dalam app, kanal beta, atau "Skip This Version".
  - Membuat repo GitHub atau rilis (tahap 24).
- **Anti-sasaran**
  - PACE menghubungi GitHub sebelum pengguna sempat melihat pengaturannya, atau saat pengaturannya mati.
  - PACE membuka URL yang datang dari jawaban jaringan.
  - Pemberitahuan update yang muncul berulang-ulang untuk versi yang sama.
  - Uji otomatis memakai tanda "sambutan sudah tampil" milik Mac Pace, sehingga sambutan tidak muncul saat Pace memasang dari GitHub.

## Jendela sambutan
- **Kapan tampil:** sekali per Mac, saat app pertama dibuka. Tandanya disimpan di UserDefaults (`welcomeShown`), karena izin berlaku per Mac. Tanda dipasang saat jendela tampil.
- **Data uji tidak menyentuh tanda asli:** selama folder data uji dipakai (`PACEDataRootOverride`), tanda yang dibaca dan ditulis adalah `welcomeShown.testData`. Aturan yang sama berlaku untuk tanda cek update di bawah.
- **Dibuka lagi** dari menu bar ("Welcome & Permissions…") dan dari launcher (perintah "Welcome & Permissions", alias `welcome`, `permissions`, `izin`, `setup`, `onboarding`). Alias `permissions` dipindah dari "Accessibility Settings" ke perintah ini.
- **Jendela biasa** seperti Settings (mengaktifkan PACE, fokus kembali ke app sebelumnya saat ditutup), judul "Welcome to PACE Launcher".
- **Isi, dari atas:**
  1. Ikon app, judul, dan versi.
  2. "PACE lives in the menu bar" dan cara membuka launcher dengan shortcut aktual (⌥Space atau pilihan pengguna). Kalau shortcut itu gagal didaftarkan karena dipakai app lain, ada catatan oranye dan tombol ke Settings › Shortcuts.
  3. **Daftar izin**, masing-masing dengan kegunaan, status, dan tombol:

     | Izin | Untuk apa | Status yang mungkin |
     |---|---|---|
     | Accessibility | Window snapping, paste ke app lain, Lock Screen, Log Out | Granted / Not granted + "Open Settings…" |
     | Input Monitoring | Keyword snippet yang langsung diganti saat diketik | Granted / Not granted + "Open Settings…" / "Not needed while auto-expand is off" / "Granted — quit and reopen PACE to start" |
     | Paste from Other Apps | Riwayat clipboard | Allowed / "Asks each time" + "Open Settings…" / Denied + "Open Settings…" / Unavailable |
     | Automation | Restart, Shut Down, Empty Trash, Toggle Dark Mode | Selalu "macOS asks the first time you use one" (tanpa tombol) |

     Status dibaca ulang setiap detik selama jendela terbuka. Begitu Input Monitoring diberikan dan auto-expand menyala, PACE mencoba menyalakan auto-expand sekali tanpa relaunch. Kalau gagal, statusnya meminta pengguna membuka ulang PACE.
  4. Toggle "Check for updates automatically" (pengaturan yang sama dengan Settings) dengan penjelasan permintaan jaringannya.
  5. Toggle "Launch at login" (hanya untuk app yang terpasang di Applications).
  6. Catatan cara membuka jendela ini lagi, tombol "Open Launcher" (menutup jendela lalu membuka panel), dan "Done".
- **Automation tidak dicek statusnya**, karena memeriksanya bisa memunculkan dialog izin atau butuh app target yang sedang berjalan.

## Cek update
- **Sumber:** `GET https://api.github.com/repos/ahmadrio/pace-launcher/releases/latest`. Nama repo `ahmadrio/pace-launcher` adalah usulan Claude; repo dibuat di tahap 24, dan nilainya ada di satu konstanta.
- **Isi permintaan:** session ephemeral tanpa cookie dan cache (seperti kurs), header `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2022-11-28`, dan `User-Agent: PACELauncher` (GitHub mewajibkan User-Agent). Versi app dan data pengguna tidak dikirim. Timeout 10 detik.
- **Membaca jawaban:**
  - 200: `tag_name`, `draft`, `prerelease`. Tag dibaca sebagai versi `x.y.z` (awalan `v` boleh, 1–3 angka). Tag lain, draft, dan prerelease tidak dianggap versi baru.
  - 404: belum ada rilis (repo belum ada atau kosong). Bukan error.
  - 403/429: GitHub membatasi permintaan. Lainnya: error.
- **Versi baru** = versi tag lebih tinggi dari `CFBundleShortVersionString`. Build lokal yang lebih baru dari rilis tidak menampilkan apa pun.
- **Halaman unduhan** dibangun dari konstanta repo dan tag yang sudah lolos pembacaan versi: `https://github.com/ahmadrio/pace-launcher/releases/tag/<tag>`. URL dari jawaban GitHub tidak pernah dibuka.
- **Otomatis** (pengaturan `checkForUpdates` di `settings.json`, **default menyala**, ikut sync):
  - Paling sering sekali sehari: cek dilakukan kalau cek terakhir yang berhasil (200 atau 404) sudah lebih dari 24 jam lalu, atau jamnya ada di masa depan (jam Mac diubah).
  - Dicoba sekitar 10 detik setelah app dibuka, lalu setiap jam. Gagal (offline) berarti dicoba lagi jam berikutnya.
  - **Tidak pernah selama jendela sambutan terbuka.** Pada pembukaan pertama, cek pertama baru terjadi setelah jendela sambutan ditutup, jadi pengguna sudah melihat pengaturannya.
  - Selama folder data uji dipakai, cek otomatis hanya berjalan kalau `PACEUpdatesURLOverride` diisi.
  - Menemukan versi baru: HUD sekali per versi ("PACE Launcher 1.1.0 is available. Download it from the menu bar or with “Check for Updates”."), item menu bar "Download PACE Launcher 1.1.0…" di paling atas, baris di Settings, dan subtitle perintah launcher. Versi yang sudah diumumkan disimpan di UserDefaults (`announcedUpdateVersion`), jadi HUD tidak muncul lagi setelah relaunch.
- **Manual:** item menu bar "Check for Updates…", perintah launcher "Check for Updates" (alias `update`, `updates`, `pembaruan`, `version`, `versi`), dan tombol "Check Now" di Settings › General. Selalu boleh, walau cek otomatis mati. Hasilnya berupa dialog:
  - Ada versi baru: "PACE Launcher 1.1.0 is available" dengan tombol **Download** (membuka halaman unduhan di browser) dan **Later**.
  - Sudah terbaru: "PACE Launcher 1.0.0 is up to date."
  - Belum ada rilis: "No release is published on GitHub yet."
  - Gagal: "Couldn’t check for updates" dengan alasannya.
  - Kalau cek otomatis sedang berjalan saat tombol ditekan, dialog muncul begitu cek itu selesai (tidak ada dua permintaan).
- **Settings › General › Updates:** toggle otomatis, versi sekarang, kapan terakhir dicek, tombol "Check Now", dan baris versi baru dengan tombol "Download…" kalau ada.
- **Uji tanpa GitHub:** `PACEUpdatesURLOverride` mengarahkan permintaan ke server lokal, seperti `PACERatesURLOverride` untuk kurs.

## Dokumen
- `docs/INSTALL.md`: jendela sambutan saat pertama dibuka; cek update (apa yang dikirim, cara mematikan); daftar lengkap koneksi internet PACE (kurs dan cek update).
- `docs/RELEASING.md`: app membaca rilis terbaru yang bukan draft/prerelease; tag harus `v<versi>` dengan versi `x.y.z`, sama dengan `CFBundleShortVersionString`.
- `HANDOFF.md`: status tahap 23, keputusan internet diperbarui, kunci uji baru, dan cara membersihkannya.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- Cek update **default menyala**, tapi tidak pernah sebelum jendela sambutan (yang menampilkan toggle-nya) ditutup.
- Repo `ahmadrio/pace-launcher`.
- Cek sekali sehari, dicoba tiap jam saat jatuh tempo; HUD sekali per versi; tanpa "Skip This Version".
- Cek manual memakai dialog; cek otomatis tidak pernah memunculkan dialog atau membuka browser.
- Pengaturan cek update ikut `settings.json` (sync); tanda waktu dan versi yang diumumkan per Mac (UserDefaults).
- Jendela sambutan sekali per Mac, ditandai saat tampil; tanda terpisah selama data uji dipakai.
- Automation hanya dijelaskan, tidak dicek.
- Alias `permissions` pindah ke "Welcome & Permissions".
