# Desain Tahap 5: Konversi Unit dan Kurs, Shortcut Command, Umur Riwayat Clipboard, Perbaikan Tahap 4

## Maksud
Pace sudah meng-uninstall Raycast, jadi DOT Launcher sekarang satu-satunya launcher (10 Nov 2026). Isi tahap ini diambil dari "Langkah berikutnya" di `HANDOFF.md`. Pace memilih langsung mulai ("langsung mulai aja"), jadi semua keputusan di dokumen ini adalah **keputusan Claude** dan bisa dikoreksi.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - Kalkulator mengonversi unit (`10 km to mi`) dan mata uang (`100 usd to idr`, `$25`).
  - Command bawaan bisa diberi shortcut global.
  - Riwayat clipboard bisa dibatasi umurnya dan dibersihkan.
  - Minor dari review tahap 4 yang bisa dites diperbaiki.
- **Bukan sasaran**
  - Kurs real-time atau grafik kurs.
  - Kripto.
  - Singkatan angka (`1jt`, `10k`).
  - Shortcut untuk script command.
  - Unit selain daftar di bawah.
- **Anti-sasaran**
  - DOT menghubungi internet tanpa Pace mengetik konversi mata uang.
  - Hasil kurs yang sudah lama ditampilkan seolah-olah baru.
  - Batas umur riwayat menghapus clip yang di-pin.
  - Shortcut baru mengambil alih ⌘C/⌘V di semua app.

## Batasan teknis
Sama seperti tahap 4:
- Swift 6.4, SwiftPM + CLT, tanpa dependensi.
- Core tanpa AppKit, dites dengan Swift Testing.
- Uji UI memakai `DOTDataRootOverride`, dan clipboard Pace di-snapshot lalu dipulihkan.
- Tidak ada konten pengguna di log di atas `.debug`.

## Fitur 1: Konversi unit
- **Bentuk:** `<jumlah> <unit> <pemisah> <unit>`.
  - Jumlah boleh berupa ekspresi (`2*5 km to m`) dan boleh menempel ke unit (`10km to mi`).
  - Pemisah: `to`, `in`, `as`, `ke`, `=`, `->`, `→`.
  - Kalau kata `in` muncul dua kali (`10 in in cm`), pemisahnya diambil dari kanan.
- **Kategori dan unit** (huruf besar/kecil tidak dibedakan, kecuali satuan data `b` dan `B`):
  - Panjang: mm, cm, m, km, in, ft, yd, mi, nmi
  - Massa: mg, g, kg, t, oz, lb, st
  - Suhu: c/°c, f/°f, k
  - Volume: ml, l, tsp, tbsp, cup, floz, pt, qt, gal
  - Luas: mm², cm², m², km², ha, acre, ft², in² (`m2` juga diterima)
  - Kecepatan: m/s, km/h (kph), mph, knot
  - Waktu: ms, s, min, h, day, week
  - Data: b (bit), B, KB, MB, GB, TB (1000), KiB, MiB, GiB, TiB (1024)
  - Nama panjang (meter, kilometers, pounds, celsius, …) diterima untuk unit yang umum.
- **Kategori berbeda** (`10 km to kg`) tidak menghasilkan baris.
- **Konversi memakai `Measurement`** dari Foundation.
- **Tampilan:**
  - Judul berisi angka dengan 6 digit signifikan, dikelompokkan sesuai locale (`6,21371 mi`).
  - Subtitle berisi query.
  - ⏎ menyalin angka tanpa pemisah ribuan, dengan desimal sesuai locale (sama seperti kalkulator).

## Fitur 2: Kurs
- **Bentuk:**
  - `100 usd to idr`, `€50 in usd`, `$25` (tanpa target berarti ke mata uang locale, untuk Pace IDR), `100 idr` (ke USD kalau mata uang locale sama dengan sumbernya), `rp 50000 to sgd`.
  - Kode ISO 3 huruf diterima kalau ada di data kurs.
  - Simbol: $, US$, €, £, ¥, Rp, S$, RM, ₩, ₹, ฿, ₱.
  - Nama: dollar, euro, rupiah, yen, pound, ringgit, baht, won, rupee, riyal, dirham.
  - Kalau ada bentrok, nama unit menang (`cup` adalah volume, bukan peso Kuba).
- **Sumber:** `https://open.er-api.com/v6/latest/USD` (ExchangeRate-API open access).
  - Gratis, tanpa akun, sekitar 160 mata uang, diperbarui sekali sehari.
  - Syaratnya mencantumkan sumber, jadi subtitle berisi "Rates by ExchangeRate-API · <tanggal>".
- **Privasi:** DOT hanya mengambil kurs ketika sedang ditampilkan konversi mata uang dan data yang ada sudah lebih dari 12 jam (atau belum ada).
  - Tidak ada permintaan di latar belakang.
  - Yang dikirim hanya permintaan `GET` tanpa data Pace.
- **Cache:** respons disimpan ke `exchange-rates.json` di folder lokal (tidak ikut iCloud).
  - Offline: cache dipakai, dengan tanggalnya di subtitle.
  - Cache lebih dari 7 hari: subtitle juga menulis "rates may be outdated".
  - Belum ada cache dan sedang mengambil: baris "Fetching exchange rates…". Daftar diperbarui setelah selesai kalau query-nya masih sama.
  - Gagal tanpa cache: baris "Exchange rates unavailable (offline?)".
- **Tampilan:** judul berisi angka maksimal 2 desimal dengan pemisah ribuan locale, ditambah kode (`1.807.700 IDR`). ⏎ menyalin angka tanpa pemisah ribuan.

## Fitur 3: Shortcut untuk command
- **Command yang bisa diberi shortcut** (default: tidak ada):
  - Translate
  - AI Chat
  - AI Chat History
  - Open Notes
  - Create Note
  - Search Notes
  - Search Snippets
  - Create Snippet
  - Settings
- **Id di `settings.json`:** `command.<id command>`, misalnya `command.translate`.
- **Settings › Shortcuts** dikelompokkan menjadi **Launcher** (Open DOT Launcher, Clipboard History), **Commands**, dan **Window**.
- **Perilaku:** sama seperti memilih command di launcher. Command yang membuka mode akan membuka panel di mode itu (toggle). Command yang menjalankan sesuatu langsung dijalankan.

## Fitur 4: Umur riwayat clipboard
- **Settings › General › Clipboard History:** "Keep history" dengan pilihan Forever (default), 1 year, 6 months, 3 months, 1 month, 1 week, 1 day.
- **Yang dihapus:** clip yang **tidak di-pin** dan terakhir dipakai sebelum batas itu, beserta file gambarnya.
- **Kapan dijalankan:** saat app dibuka, setiap jam, dan saat pilihan diubah.
- **"Clear History…"** menghapus semua clip yang tidak di-pin. Tombolnya harus ditekan dua kali, lalu muncul jumlah yang dihapus.
- **Penyimpanan:** `clipboardRetention` di `settings.json`.

## Fitur 5: Perbaikan minor tahap 4
Hanya minor yang bisa dibuktikan dengan test (Core) atau reproducer UI. Sisanya tetap di daftar tunda.
- **Shortcut**
  - Menolak kombinasi standar app: ⌘ + C/V/X/Z/A/S/Q/W/N/T/O/P/F/H/M/Tab/Space/`,`, dengan atau tanpa ⇧ (⌘⇧Z redo, ⌘⇧S). Pesannya: "Used by apps for ⌘X-style shortcuts.". Teks persisnya ditentukan di rencana.
  - Pendaftaran ulang melepas dulu semua shortcut yang berubah, baru mendaftarkan yang baru.
  - Selama merekam, modifier yang sedang ditekan tampil di tombol ("⌃⌥…").
- **AI chat**
  - Jawaban yang sedang berjalan disimpan ke chat lamanya ketika Pace pindah chat atau menekan ⌘N.
  - Task lama tidak bisa mengosongkan penanda generation yang baru.
  - Task yang dibatalkan saat menerjemahkan tidak mengirim apa pun ke model.
  - Menghapus chat yang sedang terbuka mengosongkan mode AI **sebelum** menghapus.
  - Esc di AI Chats yang dibuka dengan ⌘Y kembali ke chat.
  - Daftar chat tidak dibatasi 100.
- **Clipboard**
  - ⌘P membalik status pin langsung di database, sehingga dua tekanan cepat tetap benar.
  - Gambar di atas 50 megapiksel ditolak sebelum di-decode.
  - File gambar yatim dibersihkan saat app dibuka.
- **Privasi:** `PRAGMA secure_delete` untuk `chat.sqlite` dan `clipboard.sqlite`.
- **Test:** folder sementara dihapus.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- **Kurs**
  - Sumbernya ExchangeRate-API open access, karena cakupan 160 mata uang termasuk IDR/SAR/AED, tanpa akun.
  - Diambil sesuai permintaan, cache 12 jam, peringatan setelah 7 hari.
  - `$25` tanpa target dikonversi ke mata uang locale.
- **Format:** 6 digit signifikan untuk unit dan 2 desimal untuk kurs. Yang disalin adalah angka tanpa pemisah ribuan.
- **Singkatan** (`1jt`, `10k`) belum didukung.
- **Shortcut command:** default kosong, dan hanya untuk command bawaan.
- **Retensi:** default Forever. Clip yang di-pin tidak pernah dihapus otomatis. Pembersihan berjalan setiap jam.
- **Minor yang ditunda:**
  - TIFF dibuat lazy saat paste
  - gambar dibaca di main thread sebelum cek ukuran
  - batas ukuran cache thumbnail
- **Minor yang tidak lagi relevan:** modifier tanpa tombol, yang kini ditangani lewat tampilan modifier yang sedang ditekan.
