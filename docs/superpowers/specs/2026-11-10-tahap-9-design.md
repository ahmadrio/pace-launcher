# Desain Tahap 9: Kalkulator Tanggal dan Waktu, Perbaikan yang Ditunda

## Maksud
Isi tahap ini adalah minor yang ditunda di ledger tahap 8, ditambah kalkulator tanggal/waktu, yang merupakan usulan Claude dari "Langkah berikutnya" di `HANDOFF.md`. Pace memilih langsung mulai ("langsung mulai aja", 10 Nov 2026), jadi semua keputusan di dokumen ini adalah **keputusan Claude** dan bisa dikoreksi.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - Menjawab pertanyaan tanggal dan jam sehari-hari langsung di launcher: tanggal setelah N hari, sisa hari menuju tanggal tertentu, dan jam di kota atau zona lain.
  - Minor dari review tahap 8 diperbaiki.
- **Bukan sasaran**
  - Kalender, pengingat, dan event.
  - Bahasa alami bebas ("next friday after lunch").
  - Selisih antara dua tanggal sembarang ("17 aug - 1 jan").
- **Anti-sasaran**
  - Kata biasa di root (`now`, `today`, `time`) memunculkan baris tanggal di atas app yang dicari.
  - Konversi unit atau kalkulator yang sudah ada berubah arti (`10 in in cm`, `5 min to s`).
  - Hasil jam yang salah karena zona waktu atau pergantian hari tidak ditampilkan.

## Batasan teknis
Sama seperti tahap 8. Perhitungan tanggal memakai `Calendar`, `TimeZone`, dan `DateFormatter` dari Foundation. Logika di Core dites dengan waktu, zona waktu, dan locale yang ditetapkan di test.

## Fitur 1: Kalkulator tanggal dan waktu
Hasilnya tampil sebagai baris pertama (accessory "Date"), sama seperti kalkulator: sesudah konversi unit/kurs, sebelum kalkulator angka. ⏎ menyalin hasilnya.

- **Tanggal ± jangka waktu:**
  - Bentuknya `<awal> + <angka> <satuan>` atau `-`, dan boleh berulang (`today + 1 week + 2 days`).
  - Awal: `now`/`sekarang` (dengan jam), atau `today`/`hari ini`, `tomorrow`/`besok`, `yesterday`/`kemarin` (tanggal saja).
  - Satuan: `min`/`minute(s)`/`menit`, `h`/`hour(s)`/`jam`, `d`/`day(s)`/`hari`, `w`/`week(s)`/`minggu`, `month(s)`/`bulan`, `y`/`year(s)`/`tahun`.
  - Hasil: tanggal lengkap sesuai locale ("Friday, 13 November 2026"), ditambah jam kalau awalnya `now` atau satuannya menit/jam.
- **Sisa hari:**
  - Bentuknya `days until <tanggal>` / `days since <tanggal>`, atau dalam bahasa Indonesia `hari menuju <tanggal>` / `hari sejak <tanggal>`.
  - Tanggal boleh ditulis `17 aug`, `17 agustus 2027`, `aug 17`, atau `2026-12-25`, dengan nama bulan Inggris dan Indonesia (lengkap atau singkat).
  - Tanpa tahun, dipakai tanggal itu yang berikutnya (until) atau yang terakhir (since).
  - Hasil: "280 days", "1 day", atau "Today". ⏎ menyalin angkanya.
- **Zona waktu:**
  - `time in tokyo` / `jam di tokyo` menampilkan jam sekarang di sana.
  - `5pm in london`, `17.00 wib in new york`, atau `9:30am jst to wib` mengubah jam dari zona asal (default zona Mac) ke zona tujuan, untuk hari ini.
  - Jam harus memakai am/pm atau menit (`5pm`, `17:00`, `17.00`). Angka saja (`5 in tokyo`) tidak dianggap jam.
  - Zona boleh berupa:
    - `WIB`, `WITA`, `WIT`
    - singkatan yang dikenal Foundation (`JST`, `SGT`, `PST`, `EST`, `CET`, `BST`, `KST`), ditambah `AEST`
    - `UTC`/`GMT`
    - nama kota dari daftar zona waktu (`tokyo`, `new york`, `london`, `jakarta`), ditambah alias `nyc`, `sf`, `bali`, `beijing`, `mumbai`.
  - Hasil: jam di zona tujuan sesuai locale, nama tempat, dan nama hari kalau harinya berbeda dari zona asal ("06.00 London · Tue"). ⏎ menyalin jamnya.
- **Tidak memunculkan baris:** `now`, `today`, `time`, `tokyo` saja, atau `days until` tanpa tanggal yang valid.

## Fitur 2: Perbaikan yang ditunda (ledger tahap 8)
- **Emoji**
  - Tujuh emoji yang hilang masuk daftar: ‼️ ⁉️ ℹ️ 〰️ 〽️ ㊗️ ㊙️.
  - Bendera tanpa gambar (🇪🇿, 🇶🇴) tidak lagi ditampilkan.
  - Kata baru: `pray`/`doa` → 🙏, `100` → 💯, `tada` → 🎉, `poop`/`tai` → 💩.
  - Kegagalan mencatat pemakaian emoji masuk log, seperti di pencarian root.
- **Quicklink**
  - `id` tulisan tangan yang bukan UUID (`"wiki"`) diperlakukan seperti tanpa id: entrinya mendapat id turunan, tidak dilewati.
  - Host non-ASCII tampil terbaca di baris quicklink (`bücher.de`, bukan `b%C3%BCcher.de`).
  - Id hasil pemisahan dicek ulang sampai unik.
- **Folder skrip lewat symlink, `/tmp`, atau `/var`:** path folder diresolusi (`realpath`) sebelum dibandingkan dengan path dari FSEvents. Kalau folder belum ada, induknya yang diresolusi, lalu nama foldernya ditambahkan kembali.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- Baris tanggal/waktu hanya muncul untuk bentuk di atas. Kata tunggal tidak memunculkan baris.
- Konversi jam selalu untuk hari ini di zona asal.
- ⏎ menyalin teks hasil, kecuali sisa hari yang menyalin angkanya.
- `minggu` dibaca sebagai satuan minggu (week), bukan hari Minggu.
- **Minor yang tetap ditunda:**
  - gambar dibaca di main thread sebelum cek 20 MB
  - konflik dengan app yang memakai event tap
  - shortcut skrip yang hilang tidak memberi tanda saat ditekan
