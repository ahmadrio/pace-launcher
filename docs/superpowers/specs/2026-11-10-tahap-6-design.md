# Desain Tahap 6: Shortcut Skrip, Singkatan Angka, Perbaikan yang Ditunda

## Maksud
DOT Launcher sekarang satu-satunya launcher Pace. Isi tahap ini diambil dari "Langkah berikutnya" di `HANDOFF.md`. Pace memilih langsung mulai ("langsung mulai aja", 10 Nov 2026), jadi semua keputusan di dokumen ini adalah **keputusan Claude** dan bisa dikoreksi.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - Script command bisa diberi shortcut global, sama seperti command bawaan.
  - Kalkulator dan konversi memahami singkatan angka (`1jt`, `10rb`, `10k`).
  - Minor dari review tahap 4 dan 5 yang berdampak ke pemakaian sehari-hari diperbaiki.
- **Bukan sasaran**
  - Shortcut untuk app, snippet, atau note tertentu.
  - Singkatan huruf tunggal yang ambigu (`M`, `B`, `T`).
  - Kripto.
- **Anti-sasaran**
  - Shortcut skrip hilang diam-diam karena file skrip dipindah ke folder lain atau iCloud sedang mengunduh.
  - Skrip yang butuh argumen atau konfirmasi berjalan tanpa Pace melihatnya.
  - `10k to c` (kelvin) atau `1 m to ft` (meter) berubah arti karena singkatan.
  - Mengubah "Keep history" menghapus banyak clip tanpa peringatan.

## Batasan teknis
Sama seperti tahap 5:
- Swift 6.4, SwiftPM + CLT, tanpa dependensi.
- Core tanpa AppKit, dites dengan Swift Testing.
- Uji UI memakai `DOTDataRootOverride`, dan clipboard Pace di-snapshot lalu dipulihkan.
- Tidak ada konten pengguna di log di atas `.debug`.

## Fitur 1: Shortcut untuk script command
- **Settings › Shortcuts** mendapat grup **Scripts** di antara Commands dan Window. Isinya satu baris per skrip yang ditemukan, diurutkan menurut judul. Defaultnya tanpa shortcut.
  - Kalau dua skrip punya judul sama, barisnya diberi keterangan nama foldernya.
  - Shortcut milik skrip yang tidak ditemukan tetap disimpan dan tampil di akhir grup dengan keterangan "Not found on this Mac", beserta tombol untuk menghapusnya. Shortcut itu tidak didaftarkan ke macOS. Begitu skripnya muncul lagi (misalnya selesai diunduh dari iCloud), shortcut-nya otomatis aktif kembali.
- **Id di `settings.json`:** `script.<kunci>`.
  - Skrip di folder Scripts utama memakai path relatif terhadap folder itu (`script.tools/deploy.sh`). Kuncinya tidak berubah saat sync dinyalakan atau dimatikan, dan ikut tersinkron ke Mac lain bersama folder Scripts.
  - Skrip di folder tambahan memakai path lengkapnya (`script./Users/pace/bin/x.sh`), karena folder tambahan hanya ada di Mac ini.
  - Mengganti nama atau memindahkan file skrip memutus shortcut-nya. Shortcut lama lalu tampil sebagai "Not found on this Mac".
- **Perilaku saat shortcut ditekan** (daftar skrip dibaca ulang dulu, supaya mode dan argumen yang dipakai selalu yang terbaru):

  | Skrip | Yang terjadi |
  |---|---|
  | Tidak executable | HUD merah: "Not executable. Select it in DOT and press ⌘⇧X." |
  | Punya argumen | Panel terbuka di form argumen, sama seperti memilih skrip itu di launcher. Konfirmasi (kalau ada) ditanyakan saat form dikirim. |
  | `needsConfirmation` | Tekanan pertama menampilkan HUD "Press ⌃⌥D again to run Deploy". Tekanan kedua dalam 3 detik menjalankannya. |
  | `fullOutput` | Panel terbuka dan menampilkan output skrip. |
  | `compact`, `silent`, `inline` | Skrip berjalan tanpa panel, lalu HUD muncul saat selesai, sama seperti dari launcher. |
  | Skrip tidak ditemukan | HUD merah: "Script not found: <nama file>". |

- **Aturan kombinasi** sama dengan shortcut lain: butuh ⌘/⌃/⌥, tidak boleh dipakai DOT di tempat lain, oleh macOS, atau kombinasi standar app.
- **Perbaikan pendukung:**
  - Hotkey didaftarkan berdasarkan id, bukan judul. Dengan begitu dua skrip berjudul sama tidak saling menimpa. Menu bar tetap menampilkan judulnya.
  - Daftar skrip dibaca saat app dibuka, bukan baru saat panel pertama kali muncul, sehingga shortcut skrip langsung aktif. Settings membaca ulang daftar skrip setiap kali dibuka.

## Fitur 2: Singkatan angka
- **Akhiran** (huruf besar/kecil tidak dibedakan):

  | Akhiran | Kali |
  |---|---|
  | `k`, `rb`, `ribu`, `thousand` | 1.000 |
  | `jt`, `juta`, `million` | 1.000.000 |
  | `miliar`, `milyar`, `billion` | 1.000.000.000 |
  | `triliun`, `trillion` | 1.000.000.000.000 |

- **Bentuk:** menempel ke angka (`10k`, `1,5jt`) atau dipisah spasi (`1 juta`). Akhiran harus berdiri sebagai kata utuh: `10kg` tetap kilogram.
- **Kalkulator:** `1jt + 500rb` = 1.500.000, `10k * 3` = 30.000. Angka bersingkatan tanpa operator (`10k`) bukan perhitungan, sama seperti `42`, jadi tidak memunculkan baris kalkulator.
- **Konversi:** jumlah boleh bersingkatan: `10k usd to idr`, `Rp 50rb`, `1,5jt idr`, `1 juta rupiah to usd`.
  - Unit selalu dicek lebih dulu, jadi `10k to c` tetap kelvin dan `1 m to ft` tetap meter.
  - Pemisah ribuan mengikuti locale seperti tahap 5: di en_ID `1.500jt idr` = 1.500 juta.
- **Tidak didukung:** `m`/`M` (meter, dan "M" berarti juta dalam bahasa Inggris tetapi miliar dalam bahasa Indonesia), `b`/`B` (bit/byte), `t` (ton).

## Fitur 3: Perbaikan yang ditunda
- **AI chat**
  - Jawaban berbahasa Indonesia yang dibatalkan saat diterjemahkan balik disimpan apa adanya (bahasa Inggris), dan Esc di tahap itu berhenti diam-diam, tanpa pesan "Could not translate the answer…".
  - Pembatalan saat menerjemahkan pertanyaan juga berhenti diam-diam.
  - Membuka chat yang sedang menjawab menampilkan jawaban parsialnya langsung.
  - AI Chats yang dibuka dari command root tidak lagi kembali ke chat saat Esc, walaupun sebelumnya pernah dibuka lewat ⌘Y.
- **Konversi**
  - Hasil kurs di bawah 1 memakai 3 digit signifikan: `1 idr to usd` = `0,0000553 USD`, bukan `0 USD`.
  - `Kb`, `Mb`, `Gb`, `Tb` (huruf b kecil, awalan huruf besar) adalah bit. Huruf kecil semua (`mb`) tetap byte, karena begitulah biasanya diketik.
  - Pengambilan kurs memakai `URLSession` ephemeral: tanpa cookie dan tanpa cache disk. `Accept-Language` dan `User-Agent` diisi nilai umum (`en`, `DOTLauncher`), bukan bahasa dan versi sistem Pace.
- **Clipboard**
  - TIFF untuk paste gambar dibuat hanya kalau app tujuan memintanya, tidak lagi selalu di main thread sebelum ⌘V.
  - Cache thumbnail dan ringkasan teks dibatasi (yang terakhir dipakai disimpan, yang lama dibuang).
  - Mempersingkat "Keep history" meminta konfirmasi dengan jumlah clip yang akan dihapus. Kalau tidak ada yang terhapus, langsung diterapkan. Perubahan dari `settings.json` (sync) tetap langsung diterapkan.
- **Shortcut**
  - Daftar kombinasi yang dipakai app ditambah ⌘⇧T/⌘⇧N/⌘⇧V, ⌘R/B/I/L/G/K/D/E/U, dan ⌘1–⌘9.
  - Kombinasi dari `settings.json` yang tidak lolos aturan rekam (tanpa ⌘/⌃/⌥, tombol tidak dikenal, atau kombinasi standar app) diabaikan saat didaftarkan, bukan hanya ditolak saat direkam. Shortcut itu kembali ke default-nya, atau tidak aktif kalau tidak punya default. Jadi `settings.json` yang diedit tangan tidak bisa mengambil ⌘V atau huruf `a` tanpa modifier.
- **Test:** `UsageStoreTests` menghapus file `-wal`/`-shm`, dan test retensi memeriksa file gambar clip yang di-pin tetap ada.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- Shortcut skrip dikunci ke path file: relatif untuk folder Scripts utama, lengkap untuk folder tambahan.
- Skrip yang butuh konfirmasi dikonfirmasi dengan menekan shortcut-nya sekali lagi (HUD), tanpa membuka panel.
- Shortcut skrip tidak bersifat toggle: setiap tekanan menjalankan skrip, sama seperti memilihnya lagi di launcher.
- Singkatan huruf tunggal hanya `k`. `M`/`B`/`T` ditolak karena ambigu.
- Hasil kurs di bawah 1 memakai 3 digit signifikan.
- `Mb` = megabit, `mb` = megabyte.
- **Minor yang tetap ditunda:**
  - daftar ISO statis (kode baru seperti XCG)
  - gambar dibaca di main thread sebelum cek 20 MB
  - konflik dengan app yang menangkap kombinasi lewat event tap
