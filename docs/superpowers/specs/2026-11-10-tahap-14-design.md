# Desain Tahap 14: Konfirmasi "Tekan Lagi" yang Konsisten

## Maksud
Tahap ini memperbaiki minor yang ditunda di ledger tahap 13. Pace memilih langsung mulai ("langsung mulai aja", 10 Nov 2026), jadi semua keputusan di dokumen ini adalah **keputusan Claude** dan bisa dikoreksi. Perintah yang butuh izin baru tetap tidak dibuat.

Saat memeriksa minor "HUD konfirmasi skrip 2,2 detik vs 3 detik", ternyata konfirmasi skrip di panel punya celah yang sama dengan Log Out sebelum tahap 13. Setelah ↩ pertama, kalau pesan "Press ↩ again to run …" hilang karena mengetik atau pindah baris, ↩ berikutnya dalam 3 detik tetap menjalankan skrip, padahal tidak ada pesan di layar. Celah ini ikut diperbaiki.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran:** setiap konfirmasi "tekan lagi" mengikuti satu aturan. Tekan kedua hanya berlaku selama pesannya masih tampil, dan pesan hilang tepat saat tekan pertama tidak berlaku lagi.
- **Bukan sasaran:**
  - konfirmasi Delete (⌃X) di daftar, yang arahnya sudah aman
  - perintah sistem yang butuh izin baru
- **Anti-sasaran:** skrip berjalan atau Mac ter-log-out tanpa pesan konfirmasi di layar.

## Batasan teknis
Sama seperti tahap 13. Tidak ada izin baru.

## Fitur 1: Satu aturan untuk empat konfirmasi
| Konfirmasi | Pesan | Tempat |
|---|---|---|
| Log Out | "Press ↩ again to log out" | footer panel |
| Skrip `needsConfirmation` di panel | "Press ↩ again to run <judul>" | footer panel |
| Skrip `needsConfirmation` dengan argumen | "Press ↩ again to run <judul>" | di bawah form |
| Shortcut global skrip `needsConfirmation` | "Press <shortcut> again to run <judul>" | HUD |

- **Tekan kedua** hanya berlaku kalau pesannya masih tampil dan masih dalam 3 detik.
- **Pesan hilang setelah 3 detik,** termasuk HUD. Sebelumnya HUD hilang lebih cepat, pada 2,2 detik.
- **Form argumen:** mengubah salah satu isian setelah pesan muncul membatalkan tekan pertama, karena konfirmasi itu untuk isian yang lama.
- **Jam Mac mundur:** kalau jam mundur di tengah jeda, tekan pertama dianggap sudah berakhir. Tekan berikutnya hanya memunculkan pesan lagi.

## Fitur 2: Skrip yang hilang di menu bar
"All Shortcuts" di menu bar dan pesan konflik di Settings menyebut skrip yang filenya hilang sebagai "<file> (not found)". Begitu filenya kembali, nama skripnya tampil lagi.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- Celah konfirmasi skrip di panel ikut diperbaiki di tahap ini, walau tidak ada di daftar minor.
- Mengubah isian form membatalkan tekan pertama.
- **Minor yang tetap ditunda:**
  - Gambar clipboard dibaca di main thread sebelum cek 20 MB.
  - Konflik dengan app yang memakai event tap tidak terdeteksi.
  - `recordsUse` belum punya unit test.
