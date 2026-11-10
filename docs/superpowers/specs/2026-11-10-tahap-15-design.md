# Desain Tahap 15: Form Skrip yang Andal, Konfirmasi yang Teruji

## Maksud
Tahap ini memperbaiki minor yang ditunda di ledger tahap 14. Pace memilih langsung mulai ("langsung mulai aja", 10 Nov 2026), jadi semua keputusan di dokumen ini adalah **keputusan Claude** dan bisa dikoreksi. Perintah yang butuh izin baru tetap tidak dibuat.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - Huruf yang diketik tepat setelah ↩ membuka form skrip masuk utuh ke isian pertama.
  - Form selalu mendapat fokus, juga saat dibuka ulang lewat shortcut.
  - Aturan konfirmasi "tekan lagi" punya unit test.
- **Bukan sasaran**
  - Mengubah tampilan form.
  - Fokus otomatis ke dropdown, yang tetap butuh Full Keyboard Access.
  - Perintah sistem yang butuh izin baru.
- **Anti-sasaran**
  - Skrip berjalan dengan argumen terpotong, misalnya `ello` padahal yang diketik `hello`.
  - Perilaku konfirmasi berubah saat dipindah ke Core.

## Batasan teknis
Sama seperti tahap 14. Tidak ada izin baru.

## Fitur 1: Ketikan awal di form
- **Masalah:** form baru bisa menerima fokus sekitar 0,1 detik setelah muncul. Huruf yang diketik dalam jeda itu masuk ke kolom pencarian.
- **Solusi:** begitu isian pertama mendapat fokus, teks di kolom pencarian dipindahkan ke isian itu seolah diketik di sana, lalu kolom pencarian dikosongkan. Hasilnya `hello` tetap `hello`.
- **Kalau isian pertama dropdown:** teks dibiarkan di kolom pencarian, sama seperti sekarang.

## Fitur 2: Form yang dibuka ulang
Setiap kali form disiapkan untuk sebuah skrip, tampilannya dibuat baru. Dengan begitu fokus otomatis berjalan lagi walau form sebelumnya masih terbuka atau panel sempat tersembunyi.

## Fitur 3: Konfirmasi di Core
`ConfirmationPrompt` dipindah ke Core dengan jam dan jeda yang bisa diganti saat test. Perilakunya sama persis dengan tahap 14, dan sekarang diuji:
- tekan basi tidak mengonfirmasi
- tekan yang mengonfirmasi menyembunyikan pesannya
- pesan hilang saat tekan pertama berakhir
- tekan baru memperpanjang pesan
- pesan lain tidak ikut disembunyikan

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- Ketikan awal dipindahkan, bukan ditahan. Jeda 0,1 detik tetap dipakai, karena form belum bisa menerima fokus lebih cepat dari itu.
- **Minor yang tetap ditunda:**
  - Gambar clipboard dibaca di main thread sebelum cek 20 MB.
  - Konflik dengan app yang memakai event tap tidak terdeteksi.
  - `recordsUse` belum punya unit test.
