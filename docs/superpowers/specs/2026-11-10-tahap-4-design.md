# Desain Tahap 4: Riwayat AI Chat, Clipboard Gambar + Preview + Pin/Hapus, Shortcut di Settings

## Maksud
Tiga hal ini adalah "Langkah berikutnya" di `HANDOFF.md` setelah tahap 3. Pace memilih langsung mulai tanpa tanya-jawab ("langsung mulai aja", 10 Nov 2026). Karena itu semua keputusan di dokumen ini adalah **keputusan Claude**, kecuali yang ditandai sebagai keputusan Pace dari tahap sebelumnya. Semuanya bisa dikoreksi Pace.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - **AI chat:** percakapan tersimpan, bisa dicari, dibuka lagi, dan dilanjutkan dengan konteks yang sama.
  - **Clipboard:**
    - gambar ikut tercatat dan bisa di-paste;
    - clip yang dipilih tampil sebagai preview;
    - pin dan hapus bisa dilakukan langsung dari panel.
  - **Shortcut:** semua shortcut global bisa diubah di Settings, dengan peringatan kalau bentrok.
- **Bukan sasaran**
  - Sync riwayat chat atau gambar clipboard ke iCloud.
  - Edit isi clip.
  - OCR gambar.
  - Shortcut untuk command lain selain yang sudah punya shortcut global, ditambah "Almost Maximize".
  - Batas ukuran atau umur riwayat.
- **Anti-sasaran** (gagal walaupun "jalan")
  - Riwayat chat atau gambar clipboard keluar dari Mac ini tanpa sync dinyalakan.
  - Shortcut baru membuat DOT tidak bisa dibuka lagi.
  - Gambar besar membuat panel tersendat.
  - Uji memakai data asli Pace.

## Batasan teknis (sama dengan tahap 3)
- macOS 27, Swift 6.4, SwiftPM + Command Line Tools.
- Tanpa dependensi eksternal, tanpa `@State`, `#Preview`, SwiftData, atau XCTest.
- Logika yang bisa dites ditaruh di `DOTLauncherCore` dan dites dengan Swift Testing. App target berisi lem AppKit/SwiftUI.
- SQLite dan file besar selalu di folder lokal (`AppPaths.localRoot`), tidak pernah di iCloud.
- Konten pengguna tidak pernah di-log di atas `.debug`.
- Uji di app memakai `DOTDataRootOverride` (folder uji), bukan data asli.

## Fitur 1: Riwayat AI chat
- **Penyimpanan:** `chat.sqlite` baru di folder lokal. File ini **tidak** ikut backup iCloud, karena backup tahap 3 khusus clipboard.
  - Tabel `chats`: id UUID, judul, waktu dibuat, waktu diubah.
  - Tabel `chat_messages`: chat, urutan, peran (`user`/`assistant`), teks yang tampil, dan teks Inggris asli kalau lewat jembatan terjemahan.
  - Hapus chat ikut menghapus pesannya.
- **Yang disimpan:** setiap pasangan tanya-jawab yang **selesai**. Jawaban yang dihentikan dengan Esc tetap disimpan apa adanya. Jawaban gagal tidak disimpan, begitu juga pertanyaannya.
  - Penyimpanan terjadi setelah jawaban selesai, termasuk setelah diterjemahkan.
  - Chat baru baru dibuat di database saat pasangan pertama selesai.
- **Judul:** baris pertama pertanyaan pertama yang tidak kosong, maksimal 80 karakter, diakhiri "…" kalau dipotong.
- **Melanjutkan chat:** membuka chat lama mengisi tampilan dengan pesannya, lalu membuat `LanguageModelSession(transcript:)`.
  - Transcript berisi instruksi yang sama, lalu prompt dan respons untuk setiap pesan.
  - Isinya teks Inggris yang dilihat model (`original` kalau ada, kalau tidak `text`).
  - Untuk pertanyaan berbahasa Indonesia, `original` berisi terjemahan Inggris yang dikirim ke model.
- **Tampilan:**
  - Command baru **"AI Chat History"** di root membuka mode daftar **AI Chats**.
  - Setiap baris berisi judul dan subtitle "N messages · 2h ago". Urutannya dari yang terakhir diubah.
  - Kolom pencarian mencari di judul dan isi pesan.
  - ⏎ membuka chat di mode AI. ⌃X menghapus (tekan dua kali). ⌘⇧⌫ "Delete All Chats" (tekan dua kali).
  - Di mode AI, ⌘Y membuka daftar riwayat. ⌘N tetap memulai chat baru, dan chat lama sudah tersimpan.
- Setelah app dibuka ulang, mode AI mulai kosong. Riwayat dibuka lewat daftar.
- **Logika yang dites di Core:**
  - `ChatStore`: simpan/tambah pesan, urutan, cari, hapus satu, hapus semua, muat pesan.
  - `ChatTitle`.
  - Pemetaan pesan ke giliran model (`modelText`).

## Fitur 2: Clipboard
### Gambar
- **Kapan dianggap gambar:** pasteboard punya gambar (`public.png` atau `public.tiff`), tidak ada file URL, dan **teks polosnya kosong**.
  - Salinan dari spreadsheet, yang membawa teks dan gambar sekaligus, tetap dicatat sebagai teks.
  - Penanda rahasia (Concealed/Transient) tetap membuat salinan diabaikan.
- **Penyimpanan:**
  - Gambar diubah ke PNG dan disimpan sebagai file `<hash>.png` di `Clipboard Images/` di folder lokal. Thumbnail 128 px disimpan sebagai `<hash>-thumb.png`.
  - Baris SQLite menyimpan `kind = image` dan teks "Image 1440 × 900" agar bisa dicari. Tidak ada blob dan tidak ada perubahan skema, karena nama file sama dengan kolom `hash`.
  - Hash dihitung dari jenis clip ditambah isi PNG, jadi gambar yang sama disalin ulang hanya menaikkan pemakaian.
  - Gambar di atas **20 MB** (data mentah di pasteboard) dilewati.
- **Hapus clip gambar** ikut menghapus kedua file-nya.
- **Backup iCloud:** tetap hanya SQLite. Setelah restore, clip gambar yang file-nya tidak ada tampil sebagai "Image unavailable" dan tidak bisa di-paste.
- **Paste:** menulis PNG dan TIFF ke pasteboard.

### Preview
- Di mode Clipboard History, daftar menyempit (sekitar 45%) dan di kanannya tampil preview clip yang dipilih:
  - **teks:** isi lengkap, bisa diseleksi, bisa di-scroll;
  - **gambar:** dimuat di luar main thread, pas di area preview;
  - **file:** daftar path dengan ikon.
- Di bawahnya ada metadata: app asal, waktu disalin, berapa kali dipakai, dan jumlah karakter/baris atau dimensi gambar.
- Rich text ditampilkan sebagai teks polos.

### Pin dan hapus
- **⌘P Pin/Unpin.** Clip yang di-pin selalu di atas, dan kolom kanan barisnya menampilkan "Pinned".
- **⌃X Delete** (tekan dua kali), sama seperti snippet dan notes.

## Fitur 3: Shortcut di Settings
- Bagian baru **Settings › Shortcuts**, di sidebar setelah Appearance. Daftarnya:
  - Open DOT Launcher
  - Clipboard History
  - setiap aksi jendela, termasuk "Almost Maximize" yang awalnya tanpa shortcut
- **Setiap baris berisi:**
  - nama aksi;
  - tombol perekam yang menampilkan shortcut ("⌃⌥←") atau "None";
  - tombol reset ke default, yang hanya muncul kalau berbeda dari default;
  - pesan status atau error di bawahnya.
- **Merekam shortcut:**
  - Klik tombol, lalu tekan kombinasi tombol. Esc membatalkan, ⌫ mengosongkan.
  - Selama merekam, semua hotkey DOT dijeda, supaya kombinasi yang sedang dipakai DOT juga bisa direkam.
- **Aturan validasi (Core):**
  - Harus ada ⌘, ⌃, atau ⌥. Pengecualiannya F1–F12, yang boleh tanpa modifier.
  - Tidak boleh sama dengan shortcut DOT lain. Error-nya: "Already used by Left Half".
  - Tidak boleh sama dengan shortcut macOS yang aktif. Error-nya: "Used by macOS".
  - **Open DOT Launcher tidak boleh kosong**, supaya DOT selalu bisa dibuka.
  - Kalau macOS menolak mendaftarkan shortcut (dipakai app lain), shortcut tetap tersimpan dan baris itu menampilkan "Couldn't register: another app uses it".
- **Penyimpanan:** `shortcuts` di `settings.json`, berupa peta id → string seperti `"ctrl+opt+left"`.
  - String kosong berarti tanpa shortcut. Id yang tidak ada berarti pakai default.
  - Id yang dipakai: `launcher`, `clipboardHistory`, dan `window.<rawValue WindowAction>`.
- **Gating Maccy/Rectangle tahap 1 hanya berlaku untuk shortcut default.** Kalau Pace memilih kombinasi lain, shortcut itu tetap aktif walaupun Maccy/Rectangle berjalan.
- Perubahan langsung berlaku tanpa restart. Status di menu bar ikut berubah.

## Pengujian dengan data uji
Sama seperti tahap 3. Uji di app memakai `DOTDataRootOverride` ke folder di scratchpad, sehingga `chat.sqlite`, `Clipboard Images/`, dan `settings.json` uji tidak menyentuh data asli. iCloud tidak disentuh karena sync mati. Clipboard Pace dicek (hash) sebelum dan sesudah uji yang menulis ke clipboard.

## Urutan pengerjaan
1. Core `ChatStore` dan `ChatTitle`.
2. App: simpan chat, mode AI Chats, lanjutkan chat.
3. Core: clip gambar (filter, draft, file, hapus).
4. App: tangkap dan paste gambar, thumbnail di baris.
5. App: preview, serta pin/hapus di panel.
6. Core: model shortcut (id, default, string, validasi) dan `SettingsData.shortcuts`.
7. App: Settings › Shortcuts, perekam, dan pendaftaran ulang langsung.
8. Penutup: test, smoke test di folder uji, HANDOFF.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- **Riwayat chat**
  - Disimpan lokal tanpa batas dan tidak ikut backup iCloud.
  - Tidak ada toggle untuk mematikan penyimpanan. Privasi dijaga lewat hapus satu dan hapus semua.
  - Jawaban yang gagal tidak disimpan.
- **Shortcut chat:** ⌘Y untuk riwayat di mode AI, ⌘⇧⌫ untuk hapus semua.
- **Clipboard gambar**
  - Batas 20 MB, format PNG, thumbnail 128 px.
  - Gambar tidak ikut backup iCloud.
  - Salinan yang membawa teks dan gambar sekaligus dicatat sebagai teks.
- **Preview** selalu tampil di mode clipboard, dan rich text ditampilkan sebagai teks polos.
- **Pin:** ⌘P.
- **Shortcut**
  - Ada bagian Shortcuts tersendiri di Settings.
  - Launcher wajib punya shortcut.
  - Hotkey dijeda saat merekam.
  - Gating Maccy/Rectangle hanya untuk kombinasi default.
  - Shortcut ikut `settings.json`, jadi ikut sync kalau sync menyala.
