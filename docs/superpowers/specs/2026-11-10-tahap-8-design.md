# Desain Tahap 8: Emoji Picker, Paste sebagai Teks Polos, Perbaikan yang Ditunda

## Maksud
Isi tahap ini adalah minor yang ditunda di ledger tahap 7, ditambah dua fitur usulan Claude dari "Langkah berikutnya" di `HANDOFF.md`. Pace memilih langsung mulai ("langsung mulai aja", 10 Nov 2026), jadi semua keputusan di dokumen ini adalah **keputusan Claude** dan bisa dikoreksi.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - Mencari emoji dan menempelkannya ke app mana pun dari launcher.
  - Menempelkan clip dari Clipboard History tanpa format (font, warna, link).
  - Minor dari review tahap 7 diperbaiki.
- **Bukan sasaran**
  - Pilihan warna kulit (skin tone) dan emoji gabungan (keluarga, profesi dengan ZWJ).
  - Kata kunci emoji lengkap dari CLDR untuk semua emoji.
  - GIF dan sticker.
- **Anti-sasaran**
  - Menempelkan emoji meninggalkan emoji di clipboard Pace atau menambahkannya ke riwayat clipboard.
  - Paste teks polos mengubah clip yang tersimpan di riwayat.
  - Pemantauan folder skrip membuat DOT membaca ulang skrip setiap kali Notes atau folder lain disimpan.

## Batasan teknis
Sama seperti tahap 7:
- Swift 6.4, SwiftPM + CLT, tanpa dependensi.
- Core tanpa AppKit, dites dengan Swift Testing.
- Uji UI memakai folder data uji, ketikan dijaga fokus, dan clipboard Pace di-snapshot lalu dipulihkan.
- Tidak ada konten pengguna di log di atas `.debug`.

## Fitur 1: Emoji picker
- **Command "Search Emoji"** (alias `emoji`, `emoticon`) membuka mode Emoji. Command ini juga bisa diberi shortcut global di Settings › Shortcuts › Commands.
- **Isi:**
  - Emoji satu karakter dari data Unicode bawaan Swift. Emoji yang default-nya berbentuk teks (misalnya ❤ dan ☀) diberi variation selector, sehingga tampil berwarna.
  - Bendera negara dibentuk dari daftar kode wilayah, dengan nama Inggris dan Indonesia, misalnya "Flag: Indonesia", "Flag: Japan" (kata kunci "Jepang").
  - Tidak termasuk huruf regional indicator, modifier warna kulit, dan emoji gabungan.
- **Nama:** nama Unicode ditulis seperti kalimat ("Grinning face"). Sekitar 40 emoji yang paling sering dipakai mendapat nama yang lebih umum dan kata kunci Inggris + Indonesia, misalnya ❤️ "Red heart" (love, cinta), 😂 (lol, ketawa), dan 🙏 "Folded hands" (thanks, terima kasih).
- **Pencarian:** fuzzy berdasarkan nama dan kata kunci, dan emoji yang sering dipakai naik urutannya. Tanpa ketikan, daftar dimulai dari emoji yang baru dipakai, lalu emoji wajah, gambar lain, dan simbol. Urutan Unicode murni akan dimulai dari ™ dan panah.
- **Aksi:**
  - ⏎ menempelkan emoji ke app sebelumnya, lalu clipboard dikembalikan seperti semula, sama seperti snippet.
  - ⌘C menyalin emoji ke clipboard.
  - Penggunaan dicatat untuk urutan.

## Fitur 2: Paste sebagai teks polos
- Di Clipboard History, clip teks, rich text, dan file punya aksi **"Paste as Plain Text" (⌘⇧↩)**.
  - Yang ditempel hanya teks polosnya (untuk file: path-nya, satu per baris).
  - Teks polos itu tetap tinggal di clipboard, sama seperti paste biasa, tapi tidak masuk riwayat sebagai clip baru.
  - Clip aslinya tidak berubah, dan "terakhir dipakai" diperbarui.
- Clip gambar tidak punya aksi ini.

## Fitur 3: Perbaikan yang ditunda (ledger tahap 7)
- **Quicklink tulisan tangan**
  - Entri di `settings.json` tanpa `id` tidak lagi dilewati. Entri itu diberi id tetap yang diturunkan dari nama + URL, jadi tetap sama setiap kali dibaca, lalu ditulis saat file disimpan berikutnya.
  - Kalau dua entri punya `id` sama, entri berikutnya diberi id baru, sehingga Delete hanya menghapus satu.
- **Form quicklink** ditutup saat jendela Settings ditutup, jadi draf lama tidak muncul lagi atau menimpa data yang lebih baru.
- **URL quicklink**
  - URL dengan huruf non-ASCII (`https://bücher.de/?q={query}`, `søk`) dan `|` diterima, dan Foundation mengubahnya menjadi bentuk yang valid (punycode, percent-encoding).
  - URL dengan spasi tetap ditolak.
- **`settings.json`** menulis URL apa adanya (`https://…`), tanpa `\/`.
- **Pemantauan folder skrip**
  - Kalau folder Scripts utama belum ada, folder induknya yang dipantau. Begitu folder Scripts muncul (dari iCloud atau dibuat di Finder), daftar skrip dibaca ulang dan folder itu mulai dipantau.
  - Perubahan di folder tersembunyi (`.git`), di kedalaman lebih dari 3 subfolder, atau di luar folder skrip (misalnya Notes) tidak memicu pembacaan ulang.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- Data emoji dari properti Unicode Swift, bukan dari file emoji privat macOS, ditambah daftar kecil nama dan kata kunci populer.
- ⏎ di mode Emoji menempelkan emoji, dan ⌘C menyalinnya.
- Paste teks polos memakai ⌘⇧↩, dan hasilnya tetap di clipboard (sama seperti paste clip biasa).
- Id quicklink tanpa `id` diturunkan dari SHA-256 nama + URL.
- **Minor yang tetap ditunda:**
  - gambar dibaca di main thread sebelum cek 20 MB
  - konflik dengan app yang memakai event tap
  - shortcut skrip yang hilang tidak memberi tanda saat ditekan
