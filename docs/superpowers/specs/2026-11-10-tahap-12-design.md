# Desain Tahap 12: Skin Tone Emoji, Perbaikan yang Ditunda

## Maksud
Isi tahap ini adalah minor yang ditunda di ledger tahap 11, ditambah skin tone untuk emoji, yang merupakan usulan Claude. Pace memilih langsung mulai ("langsung mulai aja", 10 Nov 2026) tanpa menjawab pertanyaan soal izin baru. Karena itu Restart, Shut Down, Empty Trash, dan Toggle Dark Mode **tetap tidak dibuat**. Semua keputusan di dokumen ini adalah **keputusan Claude** dan bisa dikoreksi.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - Emoji tangan dan orang ditempel dengan warna kulit pilihan Pace.
  - Minor dari review tahap 11 diperbaiki.
- **Bukan sasaran**
  - Warna kulit per emoji.
  - Emoji keluarga atau pasangan dengan dua warna kulit.
  - Perintah sistem yang butuh izin baru.
- **Anti-sasaran**
  - Mengganti warna kulit menghapus urutan emoji yang sering dipakai.
  - Emoji yang tidak punya varian warna kulit (❤️, 🔥, bendera) ikut berubah.

## Batasan teknis
Sama seperti tahap 11. Tidak ada izin baru.

## Fitur 1: Skin tone emoji
- **Pilihan:** Default (kuning), Light 🏻, Medium-Light 🏼, Medium 🏽, Medium-Dark 🏾, Dark 🏿. Disimpan sebagai `emojiSkinTone` di `settings.json`, sehingga ikut sync. Nilai yang tidak dikenal kembali ke Default.
- **Yang berubah:** hanya 134 emoji dasar yang menurut data Unicode bisa diberi warna kulit (👍 👋 🙏 👏 …).
  - Modifier ditambahkan di belakang emoji dasar.
  - Emoji berbasis teks (☝ ✌ ✍) tidak memakai variation selector lagi saat diberi warna kulit: ☝️ menjadi ☝🏽.
- **Tempat memilih:**
  - di mode Emoji, ⌘T menggilir pilihan, dan footer menampilkan pilihan yang aktif ("Skin tone: Medium 🏽")
  - Settings › General › Emoji skin tone
- **Urutan pemakaian** dicatat per emoji dasar, jadi tidak hilang saat warna kulit diganti.

## Fitur 2: Perbaikan yang ditunda (ledger tahap 11)
- **Konfirmasi Log Out** hanya diterima selama footer masih menampilkan "Press ↩ again to log out". Mengetik atau membuka ulang panel membatalkannya.
- **Pemakaian Log Out** baru dihitung saat perintahnya benar-benar dijalankan, bukan saat ⏎ pertama.
- **`browser`** disimpan setelah spasi dan baris baru di awal/akhir dihapus.
- **HUD fallback browser** memeriksa hasil membuka browser default. Kalau gagal juga, pesannya "Could not open this quicklink."
- **Mode uji perintah sistem** dicek sebelum izin Accessibility, sehingga uji tanpa izin hanya mencatat ke log dan tidak memunculkan prompt.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- Satu warna kulit untuk semua emoji, dengan default kuning.
- ⌘T di mode Emoji menggilir warna kulit.
- Pemakaian emoji dicatat per emoji dasar.
- **Minor yang tetap ditunda:**
  - gambar dibaca di main thread sebelum cek 20 MB
  - konflik dengan app yang memakai event tap
  - shortcut skrip yang hilang tidak memberi tanda saat ditekan
- **Perintah butuh izin baru** (Restart, Shut Down, Empty Trash, Dark Mode) menunggu persetujuan Pace.
