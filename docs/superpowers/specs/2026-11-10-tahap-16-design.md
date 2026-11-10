# Desain Tahap 16: Warna Kulit per Emoji

## Maksud
Tahap ini menambah pilihan warna kulit per emoji dan menutup minor yang ditunda di ledger tahap 15. Pace memilih langsung mulai ("langsung mulai aja", 10 Nov 2026) tanpa menjawab pertanyaan soal izin Automation. Karena itu Restart, Shut Down, Empty Trash, dan Dark Mode **tetap tidak dibuat**. Semua keputusan di dokumen ini adalah **keputusan Claude** dan bisa dikoreksi.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran:** satu emoji bisa punya warna kulit sendiri. Contohnya 👍 selalu 🏽, sementara emoji lain mengikuti warna default.
- **Bukan sasaran:**
  - Dua warna kulit dalam satu emoji (pasangan, keluarga).
  - Perintah sistem yang butuh izin baru.
- **Anti-sasaran:**
  - Emoji tanpa varian warna kulit (❤️, 👪, bendera) mendapat pilihan ini.
  - `settings.json` tidak terbaca karena data per emoji rusak.
  - Urutan emoji yang sering dipakai hilang.

## Batasan teknis
Sama seperti tahap 15. Tidak ada izin baru.

## Fitur 1: Warna kulit per emoji
- **Di picker emoji:** baris yang bisa diberi warna kulit punya aksi "Skin Tone for This Emoji" (⌘⇧T). Menekannya menggilir pilihan:
  1. Mengikuti default
  2. Default (kuning)
  3. Light
  4. Medium-Light
  5. Medium
  6. Medium-Dark
  7. Dark
  8. Kembali ke mengikuti default
- **Footer** menyebut pilihan yang aktif, misalnya "👍 skin tone: Medium 🏽" atau "👍 follows the default skin tone (Default)".
- **Penyimpanan:** `emojiSkinTones` di `settings.json` (ikut sync), dengan kunci emoji dasar. Nilai yang tidak dikenal dibuang, dan isi yang rusak dianggap kosong.
- **⌘T** tetap mengganti warna default untuk semua emoji yang tidak punya pilihan sendiri.
- **Settings › General › Emoji** menampilkan jumlah emoji yang punya warna sendiri, dengan tombol "Reset" untuk menghapus semuanya.
- **Pemakaian** tetap dicatat per emoji dasar.

- **Catatan implementasi (ruling di ledger):** aksi ini bernama "Own Tone" di footer, dan pesannya tanpa swatch di akhir (contoh "👍🏽 skin tone: Medium"), supaya footer muat. Selama ada pesan, petunjuk Navigate disembunyikan, dan pesan yang terlalu panjang boleh memakai dua baris.

## Fitur 2: Sisa minor tahap 15
- Komentar `onFocused` di form skrip dibetulkan.
- Pemindahan ketikan diuji pada form yang isian pertamanya password.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- Siklus pilihan per emoji dimulai dari "mengikuti default", lalu enam warna.
- Pilihan per emoji ikut sync lewat `settings.json`.
- **Minor yang tetap ditunda:**
  - Gambar clipboard dibaca di main thread sebelum cek 20 MB.
  - Konflik dengan app yang memakai event tap tidak terdeteksi.
  - `recordsUse` belum punya unit test.
  - Form dengan dropdown di isian pertama tidak mendapat fokus tanpa Full Keyboard Access.
