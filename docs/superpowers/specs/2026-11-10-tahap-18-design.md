# Desain Tahap 18: Tema Mengikuti Sistem, Perbaikan yang Ditunda

## Maksud
- **Konfirmasi Pace (10 Nov 2026):**
  - Keempat perintah tahap 17 berhasil dijalankan.
  - System Settings › Automation mencantumkan "DOT Launcher", jadi izin Automation tercatat atas nama DOT, bukan osascript.
- **Bug yang dilaporkan Pace:** saat macOS diganti ke mode Light, tema DOT Launcher tidak ikut berubah.
- Tahap ini memperbaiki bug itu dan minor yang ditunda di ledger tahap 16 dan 17. Pace memilih langsung mulai ("langsung mulai aja"), jadi detail di bawah adalah **keputusan Claude** dan bisa dikoreksi.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - Dengan Appearance "System", panel, Notes, dan editor snippet berganti terang/gelap begitu macOS berganti, tanpa relaunch.
  - Minor tahap 16 dan 17 beres.
- **Bukan sasaran**
  - Tema baru.
  - Izin baru.
- **Anti-sasaran**
  - Mode Light/Dark yang dipaksa di Settings ikut berubah karena sistem.
  - Data `settings.json` hilang karena satu nilai rusak.

## Batasan teknis
Sama seperti tahap 17. Tidak ada izin baru.

## Fitur 1: Tema mengikuti sistem
- **Penyebab (dugaan, dibuktikan di uji):** warna tint kaca untuk mode System dihitung sekali dari `windowBackgroundColor` saat jendela didaftarkan, lalu tidak dihitung ulang.
- **Perbaikan:** DOT memantau perubahan tampilan macOS. Untuk mode System, tint dihitung ulang dengan tampilan yang baru, lalu diterapkan ke semua jendela DOT.
- Mode Light dan Dark yang dipaksa tidak berubah.

## Fitur 2: Minor tahap 17
- **Alias `appearance` dan `tema`** dihapus dari Toggle Dark Mode, supaya mencari tema DOT tidak mengganti tampilan Mac.
- **AppleEvent timeout (-1712):** Empty Trash memakai batas 1 jam (`with timeout of 3600 seconds`). Kalau tetap timeout, HUD-nya berbunyi "<App> is still working…", bukan "Could not…".
- **Pesan gagal:** pesan tanpa isi diganti "osascript exited with status N", dan awalan "35:52: execution error: " dibuang.
- **Toggle Dark Mode cepat dua kali:** setiap perintah AppleScript menunggu jalannya sebelumnya selesai, sehingga dua tekan selalu kembali ke tampilan semula.

## Fitur 3: Minor tahap 16
- **Satu nilai rusak** di `emojiSkinTones` hanya membuang entri itu, bukan semuanya.
- **Settings** hanya menghitung emoji yang benar-benar bisa diberi warna kulit.
- **⌘T pada emoji yang punya warna sendiri:** footer menambahkan keterangan "· 👍 keeps its own tone".

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- **Uji tema** mengganti tampilan Mac sebentar dengan Toggle Dark Mode DOT, lalu mengembalikannya.
- **Batas 1 jam** hanya untuk Empty Trash; perintah lain tetap 2 menit (default osascript).
