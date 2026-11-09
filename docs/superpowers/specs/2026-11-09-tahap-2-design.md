# Desain Tahap 2: Snippets, Notes, AI Chat, Translator

## Maksud
DOT Launcher (lihat `HANDOFF.md`) adalah launcher macOS pribadi milik Pace. Tujuannya meniru fitur Raycast, termasuk yang hanya ada di paket Pro, tanpa biaya. Tahap 1 sudah selesai: launcher, kalkulator, clipboard history, dan window snapping.

Tahap 2 menambahkan empat fitur yang sepenuhnya lokal, gratis, dan privat:
1. **Snippets**: potongan teks yang dicari dan di-paste dari launcher.
2. **Notes**: jendela floating dengan banyak catatan dan Markdown.
3. **AI chat**: memakai Foundation Models on-device.
4. **Translator**: Inggris ↔ Indonesia, on-device.

## Keputusan Pace
- Keempat fitur di atas masuk tahap 2.
- Snippets dipakai dari launcher dulu. **Tanpa auto-expand.**
- AI **hanya on-device** (Foundation Models), tanpa API eksternal.
- Bahasa Indonesia tidak didukung model on-device. Bahasa yang didukung ada 24: da, de, en, es, fr, it, ja, ko, nb, nl, pt, sv, tr, vi, zh, dan variannya. Karena itu dipakai **jembatan terjemahan**: pertanyaan berbahasa Indonesia diterjemahkan ke Inggris, dijawab, lalu jawabannya diterjemahkan balik. Semuanya on-device.
- Notes berupa **jendela floating**: banyak catatan, Markdown.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran:** keempat fitur bisa dipakai sepenuhnya dari keyboard, konsisten dengan launcher yang ada (⏎ aksi utama, Esc kembali), dan semua data tetap di Mac.
- **Bukan sasaran (sekarang):**
  - auto-expand snippet
  - sync
  - riwayat AI chat yang bertahan setelah app ditutup
  - penyedia AI eksternal
  - UI untuk mengunduh paket bahasa
  - gambar di clipboard
- **Anti-sasaran:**
  - data dikirim keluar Mac
  - dependensi eksternal
  - merusak perilaku tahap 1: panel non-activating, fokus kembali ke app sebelumnya, dan 74 test yang ada

## Batasan teknis
- macOS 27. Hanya Command Line Tools: tanpa `#Preview`, tanpa SwiftData.
- Swift 6 strict concurrency. Target app memakai `defaultIsolation(MainActor)`.
- `DOTLauncherCore` tanpa AppKit, dan dites dengan Swift Testing (TDD).
- Hasil cek di Mac ini:
  - `SystemLanguageModel.default.availability == .available`
  - Translation en→id `installed`
  - `TranslationSession(installedSource:target:)` tersedia, jadi terjemahan bisa dipanggil tanpa SwiftUI.

## Fondasi (dikerjakan pertama)
1. **Menu Edit.** App menu bar tidak punya `mainMenu`, sehingga ⌘C/⌘V/⌘A/⌘Z tidak berfungsi di kolom teks. Sudah dibuktikan: ⌘V di kolom pencarian tidak berpengaruh apa-apa. Pasang `NSApp.mainMenu` dengan menu Edit standar (Undo, Redo, Cut, Copy, Paste, Select All). Verifikasi ⌘V berfungsi di panel yang non-activating.
2. **Aksi sekunder.**
   - `LauncherResult` mendapat daftar aksi tambahan dengan shortcut, misalnya ⌘E edit dan ⌃X hapus. Mode juga bisa punya aksi sendiri, misalnya ⌘N.
   - `LauncherPanel.performKeyEquivalent` menangani shortcut ini sebelum diteruskan ke menu.
   - Footer menampilkan petunjuk aksi.
   - **Hapus memakai ⌃X**, seperti Raycast. ⌘⌫ tetap berarti "hapus sampai awal baris" di kolom teks, supaya kebiasaan ⌘⌫⌘⌫ tidak sampai menghapus item.
   - Hapus memakai **konfirmasi tekan dua kali**: tekan ⌃X sekali, footer menampilkan "Tekan ⌃X lagi untuk menghapus". Tidak ada dialog modal.
3. **Tampilan per mode.** Mode daftar (root, clipboard, snippets, notes) tetap memakai list. Mode `.ai` dan `.translate` punya view khusus di area hasil.
4. **Helper paste dan copy teks.** Dipakai bersama oleh snippets, translator, dan AI.
   - **Paste bersifat sementara.**
     1. Simpan isi clipboard saat ini (semua item dan tipe).
     2. Tulis teks, lalu kirim ⌘V.
     3. Sekitar 500 ms kemudian, kembalikan isi clipboard sebelumnya.
     - Penulisan maupun pengembalian **tidak** dicatat di clipboard history.
     - `{clipboard}` di snippet berisi clipboard *sebelum* paste.
   - **Copy bersifat permanen.** Hasil ⏎ "Copy" di kalkulator, translator, dan AI tetap di clipboard dan **dicatat** di history, seperti perilaku kalkulator sekarang.
   - Paste dari clipboard history tidak berubah: clip yang di-paste menjadi isi clipboard dan naik ke atas.
5. **Sembunyikan ikon menu bar** (permintaan Pace).
   - Menu bar mendapat item "Hide Menu Bar Icon" (`NSStatusItem.isVisible`). Pilihannya disimpan di UserDefaults.
   - Saat ikon tersembunyi, fungsi menu bar tetap tersedia lewat perintah launcher:
     - "Show Menu Bar Icon" / "Hide Menu Bar Icon"
     - "Quit DOT Launcher"
     - status izin, berupa baris info dengan aksi buka Settings
   - Membuka app lagi saat sedang berjalan (`applicationShouldHandleReopen`) langsung menampilkan panel launcher.

## Fitur 1: Translator
- **Cara masuk:** perintah "Translate" (alias: translate, terjemah, tr) membuka mode `.translate`.
- **Cara kerja:** ketik teks, lalu setelah jeda sekitar 300 ms terjemahan tampil di area besar di bawah kolom input, dengan label arah ("Indonesian → English").
- **Arah otomatis:** bahasa sumber dideteksi dengan NaturalLanguage. Sumber Indonesia → Inggris, selain itu → Indonesia. ⌘L membalik arah untuk teks yang sedang diketik.
- **Aksi:** ⏎ menyalin terjemahan lalu menutup panel. ⌘↩ mem-paste ke app sebelumnya.
- **Pasangan bahasa:** hanya yang sudah terpasang. Kalau belum terpasang, tampilkan cara memasangnya: System Settings → General → Language & Region → Translation Languages.

## Fitur 2: AI chat
- **Cara masuk:**
  - perintah "AI Chat" (alias: ai, ask, chat) membuka mode `.ai`
  - di root, kalau query tidak kosong, baris terakhir adalah **"Ask AI: “…”"**
  - **Tab** di root langsung mengirim query ke AI
- **Tampilan:**
  - Transkrip berupa pesan pengguna dan jawaban AI.
  - Jawaban di-stream dan dirender sebagai Markdown inline, dengan blok kode monospace.
  - Kolom pencarian menjadi input ("Ask anything…"), dan ⏎ mengirim.
- **Sesi:**
  - Satu `LanguageModelSession` dengan instruksi singkat dalam bahasa Inggris (jawab ringkas, pakai Markdown), dan konteks multi-turn.
  - ⌘N memulai chat baru.
  - Riwayat chat hanya tersimpan di memori: masih ada saat panel dibuka ulang, hilang saat app ditutup.
  - Panggil `prewarm()` saat masuk mode AI.
- **Jembatan bahasa:**
  - Deteksi bahasa setiap pertanyaan. Kalau didukung model, kirim langsung.
  - Kalau tidak didukung tapi pasangan terjemahan ke Inggris tersedia (misalnya Indonesia):
    1. terjemahkan pertanyaan ke Inggris
    2. kirim ke model
    3. setelah jawaban selesai, terjemahkan bagian prosanya saja kembali ke bahasa asal
  - Blok kode (` ``` `) dan kode inline tidak diterjemahkan.
  - **Saat jawaban dibuat:**
    1. Jawaban berbahasa Inggris tampil mengalir dengan gaya redup dan label "English", supaya tidak ada jeda 10–20 detik tanpa tampilan apa pun.
    2. Setelah selesai, status berubah menjadi "Translating…".
    3. Teks Inggris diganti dengan terjemahan Indonesianya.
  - ⌘⇧O menukar tampilan antara jawaban asli dan terjemahan.
- **Kesalahan ditampilkan sebagai pesan yang jelas:**
  - model tidak tersedia (beserta alasannya)
  - konteks penuh ("mulai chat baru, ⌘N")
  - guardrail
  - pasangan terjemahan tidak tersedia
- **Aksi:**
  - Esc saat jawaban sedang dibuat membatalkan jawaban. Esc berikutnya kembali ke root.
  - ⌘⇧C menyalin jawaban terakhir.
  - ⌘↩ mem-paste jawaban terakhir ke app sebelumnya.

## Fitur 3: Snippets
- **Penyimpanan:** satu file JSON per snippet di `~/Library/Application Support/DOT Launcher/Snippets/<UUID>.json`, berisi `name`, `keyword` (opsional), `content`, `createdAt`, `updatedAt`.
  - Format file dipilih seperti Notes, supaya sync lewat folder iCloud Drive di tahap 3 tidak perlu migrasi data. SQLite tidak aman ditaruh di folder sync.
  - Frecency tetap lokal di `UsageStore` dengan id `snippet:<UUID>`.
- **Placeholder** diproses saat paste:
  - `{date}`, `{time}`, `{datetime}` sesuai locale
  - `{clipboard}` berisi teks clipboard saat ini
  - placeholder yang tidak dikenal dibiarkan apa adanya
- **Launcher:**
  - Snippet ikut muncul di **pencarian root**, dicocokkan lewat nama dan keyword. Contoh: mengetik ";addr" menemukan snippet itu.
  - Perintah "Search Snippets" membuka mode `.snippets`.
  - Perintah "Create Snippet".
  - Di baris snippet: ⏎ mem-paste ke app sebelumnya, ⌘E mengedit, ⌃X menghapus dengan konfirmasi tekan dua kali, ⌘N membuat snippet baru.
- **Editor:**
  - Panel floating kecil berisi form: Name, Keyword, Content (multi-baris), dan teks bantuan placeholder.
  - ⌘S menyimpan, Esc membatalkan. Ada tombol hapus saat mengedit.
  - Membuka editor menyembunyikan panel launcher.

## Fitur 4: Notes
- **Penyimpanan:**
  - File Markdown di `~/Library/Application Support/DOT Launcher/Notes/<UUID>.md`. Dengan format file, sync lewat iCloud Drive di tahap 3 jadi mudah, dan catatan bisa dibuka di editor lain.
  - Judul diambil dari baris pertama yang tidak kosong, tanpa `#` di depannya. Kalau kosong, judulnya "Untitled".
  - Urutan berdasarkan waktu terakhir diubah.
  - Autosave sekitar 0,5 detik setelah berhenti mengetik, dan saat jendela ditutup.
  - Catatan kosong dihapus saat ditutup atau saat pindah catatan.
- **Jendela:**
  - Panel floating yang bisa di-resize dan tidak mengaktifkan app (sama seperti launcher), dan selalu di atas.
  - Toolbar berisi daftar catatan (⌘P, dengan pencarian), catatan baru (⌘N), dan hapus (⌃X dengan konfirmasi tekan dua kali).
  - Catatan yang dihapus **dipindah ke Trash**, sehingga masih bisa dipulihkan.
  - ⌘W menutup jendela.
  - Posisi dan ukuran jendela diingat.
- **Editor:**
  - `NSTextView` dengan styling Markdown langsung saat mengetik. Ukuran dan ketebalan heading berbeda, juga bold, italic, coret, kode inline dan blok kode monospace, tautan berwarna, serta penanda list, task, dan quote.
  - Penanda sintaks ditampilkan redup. Teks disimpan polos.
  - Logika pencarian rentang Markdown ada di Core (`MarkdownHighlighter`) dan dites. Pemberian font dan warna dikerjakan di app.
- **Launcher:**
  - "Open Notes" membuka catatan terakhir.
  - "Create Note".
  - "Search Notes" membuka mode `.notes`: ⏎ membuka catatan, ⌃X menghapus.
- **Hotkey global:** tidak ada secara default.

## Urutan pengerjaan
Urutannya: fondasi → Translator → AI chat → Snippets → Notes. Translator dikerjakan sebelum AI karena dipakai sebagai jembatan bahasa. Setiap milestone diakhiri dengan:
- test Core yang hijau
- uji UI otomatis lewat System Events dan screenshot (preferensi Pace)
- commit

## Bagian yang ditentukan builder
- Detail visual (ukuran, warna, ikon SF Symbols).
- Format tanggal yang tepat untuk placeholder.
- Jeda debounce.
- Struktur file kode.
- Teks pesan kesalahan.
- Cara menyimpan posisi jendela Notes.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- Snippets disimpan sebagai file JSON, Notes sebagai file Markdown. Keduanya siap untuk sync tahap 3.
- Hapus memakai ⌃X dengan konfirmasi tekan dua kali, bukan dialog. Catatan yang dihapus masuk Trash.
- Paste snippet, AI, atau terjemahan mengembalikan isi clipboard sebelumnya dan tidak dicatat di history. Copy tetap permanen dan dicatat.
- Jawaban AI berbahasa Inggris tampil mengalir lebih dulu, lalu diganti terjemahannya.
- Riwayat AI chat hanya di memori.
- Baris "Ask AI" di root, ditambah Tab untuk langsung bertanya.
- Arah Translator otomatis ID↔EN, dengan ⌘L untuk membalik.
- Tidak ada hotkey global baru.
