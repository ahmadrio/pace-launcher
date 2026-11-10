# Desain Tahap 10: Selisih Tanggal, Browser per Quicklink, Perbaikan yang Ditunda

## Maksud
Isi tahap ini adalah minor yang ditunda di ledger tahap 9, ditambah dua fitur usulan Claude dari "Langkah berikutnya" di `HANDOFF.md`. Pace memilih langsung mulai ("langsung mulai aja", 10 Nov 2026), jadi semua keputusan di dokumen ini adalah **keputusan Claude** dan bisa dikoreksi. Ini termasuk arti singkatan zona waktu, yang di ledger tahap 9 dicatat butuh keputusan.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - Menghitung jumlah hari antara dua tanggal.
  - Membuka quicklink tertentu di browser tertentu.
  - Singkatan zona waktu memberi jam yang benar, dengan label yang jujur.
  - Minor dari review tahap 9 diperbaiki.
- **Bukan sasaran**
  - Selisih dalam bulan atau tahun ("1 year 3 months").
  - Profil browser (misalnya profil Chrome tertentu).
- **Anti-sasaran**
  - Label zona yang tidak sesuai jam yang ditampilkan (misalnya "AEST" padahal yang dipakai AEDT).
  - Kata biasa setelah jam (`5pm to eat`) terbaca sebagai zona waktu.
  - Quicklink dengan browser yang sudah di-uninstall gagal dibuka tanpa penjelasan.

## Batasan teknis
Sama seperti tahap 9.

## Fitur 1: Selisih dua tanggal
- **Bentuk:**
  - `<tanggal> - <tanggal>`, misalnya `17 aug - 1 jan`, `2026-12-25 - today`, `17 aug 2027 - 17 aug 2026`
  - `days between <tanggal> and <tanggal>` atau `hari antara <tanggal> dan <tanggal>`
- **Tanggal:** bentuknya sama seperti countdown tahap 9 (kata dasar, ISO, atau hari + bulan Inggris/Indonesia). Tanggal tanpa tahun memakai **tahun ini**.
- **Hasil:** jumlah hari absolut ("228 days", "1 day", atau "Same day"). ⏎ menyalin angkanya. Muncul di baris pertama dengan accessory "Date".
- **Tidak bertabrakan dengan kalkulator:** `2026-12-25 - 2026-01-01` dibaca sebagai selisih tanggal (baris tanggal ada di atas kalkulator). Angka biasa seperti `25 - 1` tetap kalkulator.

## Fitur 2: Browser per quicklink
- Form quicklink mendapat pilihan **"Open with"**: "Default browser" (default), atau salah satu app yang bisa membuka `https://` di Mac ini (Chrome, Safari, Firefox, Brave, dan seterusnya).
- Disimpan sebagai `browser` (bundle id) di entri quicklink dalam `settings.json`. Entri tanpa `browser` memakai browser default.
- Kalau browser yang dipilih tidak ditemukan (sudah di-uninstall, atau `settings.json` tersinkron dari Mac lain), quicklink dibuka di browser default, lalu muncul HUD "<Browser> not found; opened in the default browser."

## Fitur 3: Perbaikan dan keputusan dari ledger tahap 9
- **Singkatan zona waktu (keputusan Claude):** singkatan selalu berarti **jam yang berlaku sekarang di kota acuannya**, termasuk musim panas. Label menunjukkan kota dan offset yang benar, misalnya `time in est` di bulan Juli → "10.53 New York (UTC−4)".
  - Singkatan yang dikenali hanya daftar tetap berikut, tidak lagi semua singkatan Foundation:
    - PT/PST/PDT, MT/MST/MDT, CT/CST/CDT, ET/EST/EDT, AKST, HST
    - GMT/UTC, BST, WET, CET/CEST, EET/EEST, MSK
    - IST, GST, ICT, PHT, MYT, SGT, HKT, JST, KST
    - AEST/AEDT, ACST/ACDT, AWST, NZST/NZDT
    - WIB/WITA/WIT
  - Kata biasa seperti `eat`, `cat`, `art`, dan `wet` tidak lagi menjadi zona.
  - WIB, WITA, WIT, dan UTC/GMT tetap berlabel singkatannya, karena offsetnya tidak berubah.
- **Kota:** `kolkata`, `bengaluru`, `bangalore`, dan `india` → Asia/Kolkata. macOS menyimpan nama lama `Asia/Calcutta`.
- **29 Februari tanpa tahun:** `days until 29 feb` memakai 29 Februari berikutnya yang valid (2028), dan `days since 29 feb` memakai yang terakhir.
- **Folder skrip yang hilang lebih dari satu tingkat:** path diresolusi dari folder terdalam yang sudah ada, lalu sisa komponennya ditambahkan kembali.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- Singkatan zona = jam yang berlaku di kota acuan, dengan offset di label. CST berarti Chicago, bukan China.
- Tanggal tanpa tahun dalam selisih memakai tahun ini.
- Selisih ditampilkan sebagai hari absolut.
- Browser yang hilang → browser default + HUD.
- **Minor yang tetap ditunda:**
  - gambar dibaca di main thread sebelum cek 20 MB
  - konflik dengan app yang memakai event tap
  - shortcut skrip yang hilang tidak memberi tanda saat ditekan
