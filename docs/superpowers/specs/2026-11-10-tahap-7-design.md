# Desain Tahap 7: Quicklinks, Hasil Kalkulator Berkelompok, Perbaikan yang Ditunda

## Maksud
Isi tahap ini diambil dari "Langkah berikutnya" di `HANDOFF.md`, ditambah quicklinks, yang merupakan usulan Claude. Pace memilih langsung mulai ("lanjutkan", 10 Nov 2026), jadi semua keputusan di dokumen ini adalah **keputusan Claude** dan bisa dikoreksi.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - Membuka pencarian atau situs yang sering dipakai langsung dari launcher: `gh dot launcher` membuka pencarian GitHub.
  - Hasil kalkulator mudah dibaca: `1.500.000`, bukan `1500000`.
  - Minor dari review tahap 6, serta daftar kode mata uang yang usang dari tahap 5, diperbaiki.
- **Bukan sasaran**
  - Quicklink dengan lebih dari satu isian, atau isian bernama.
  - Membuka quicklink di browser tertentu.
  - Import quicklink dari app lain.
  - Fallback "cari di Google" untuk setiap ketikan yang tidak cocok dengan apa pun.
- **Anti-sasaran**
  - Quicklink membuka URL tanpa Pace menekan ⏎.
  - Teks yang diketik masuk ke URL tanpa di-encode, sehingga `&` atau `#` mengubah arti URL.
  - Mengetik kata biasa di root (misalnya `g`) memunculkan baris quicklink di atas app yang dicari.
  - Nilai yang disalin dari kalkulator memakai pemisah ribuan, sehingga tidak bisa ditempel sebagai angka.

## Batasan teknis
Sama seperti tahap 6:
- Swift 6.4, SwiftPM + CLT, tanpa dependensi.
- Core tanpa AppKit, dites dengan Swift Testing.
- Uji UI memakai `DOTDataRootOverride`, dan clipboard Pace di-snapshot lalu dipulihkan.
- Tidak ada konten pengguna di log di atas `.debug`. Ini termasuk teks yang diketik ke quicklink dan URL hasilnya.
- Ketikan uji hanya dikirim saat panel DOT punya fokus.

## Fitur 1: Quicklinks
- **Isi quicklink:** nama, keyword (opsional, satu kata tanpa spasi), dan URL. URL boleh berisi `{query}` sebagai tempat teks yang diketik.
- **Penyimpanan:** daftar `quicklinks` di `settings.json`, jadi ikut tersinkron bersama pengaturan lain.
  - Kalau kuncinya belum ada, DOT mengisi empat quicklink awal: Google (`g`), YouTube (`yt`), GitHub (`gh`), dan Google Maps (`maps`).
  - Daftar yang sengaja dikosongkan tetap kosong.
  - Entri yang rusak dilewati tanpa membuang yang lain.
- **Di launcher:**
  - Quicklink muncul di pencarian root berdasarkan nama dan keyword, seperti command.
  - Quicklink tanpa `{query}`: ⏎ langsung membuka URL-nya.
  - Quicklink dengan `{query}`: ⏎ membuka mode isian, tempat kolom pencarian menjadi teks quicklink. Barisnya menulis "Search GitHub for “…”" dan ⏎ membuka URL. Esc kembali ke root.
  - **Cara cepat:** `<keyword> <teks>` di root, misalnya `gh dot launcher`, memunculkan baris "Search GitHub for “dot launcher”" di urutan pertama, sesudah baris kalkulator atau konversi kalau ada. Keyword harus cocok penuh (huruf besar/kecil tidak dibedakan) dan harus diikuti spasi dan teks. Kalau hanya mengetik `g`, baris ini tidak muncul.
- **Encode:** teks di-percent-encode, sehingga hanya huruf, angka, `-`, `.`, `_`, dan `~` yang dibiarkan. Spasi menjadi `%20`, dan `&`, `#`, `?`, `/`, `+`, `=` ikut di-encode.
- **Settings › Quicklinks** (bagian baru):
  - Berisi daftar nama, keyword, dan URL, dengan tombol Edit dan Delete.
  - "Add Quicklink" membuka form Name, Keyword, URL dengan tombol Save dan Cancel.
  - Delete langsung menghapus, karena quicklink mudah dibuat ulang.
- **Validasi** (pesan di bawah form):
  - Nama kosong: "Add a name."
  - Keyword berisi spasi: "A keyword is one word, without spaces."
  - Keyword sudah dipakai quicklink lain (huruf besar/kecil tidak dibedakan): "Another quicklink uses this keyword."
  - URL tidak bisa dibuka setelah `{query}` diganti teks contoh, atau tidak punya skema: "Enter a full URL, such as https://example.com/search?q={query}."
- **Command baru "Create Quicklink":** membuka Settings › Quicklinks dengan form Add yang sudah terbuka.
- **Skema URL:** skema apa pun yang punya nama boleh, misalnya `https`, `mailto`, atau skema app seperti `obsidian://`. DOT membukanya lewat `NSWorkspace`.
- **Frecency:** quicklink yang sering dibuka naik urutannya, sama seperti app.

## Fitur 2: Hasil kalkulator berkelompok
- Judul baris kalkulator memakai pemisah ribuan dan desimal locale: `1.500.000`, `1.234,5678`, `-1.234`. Notasi ilmiah tetap untuk angka sangat besar atau kecil, dengan desimal locale.
- ⏎ tetap menyalin angka **tanpa** pemisah ribuan, dengan desimal locale. Perilaku ini tidak berubah.

## Fitur 3: Perbaikan yang ditunda
- **Skrip**
  - Folder skrip (utama dan tambahan) dipantau dengan FSEvents. Begitu file skrip ditambah, diubah, atau dihapus, daftar skrip dibaca ulang setelah jeda 0,5 detik. Dengan begitu, shortcut skrip yang filenya kembali langsung aktif, tanpa menunggu launcher dibuka. Ini memenuhi kata "otomatis" di spec tahap 6.
  - Shortcut hanya didaftarkan ulang kalau isi skrip yang relevan berubah, yaitu kunci atau judulnya. Membuka panel tidak lagi mengacak urutan submenu shortcut.
  - Entri shortcut yang dimatikan selama Maccy/Rectangle berjalan tidak ditulis ulang kalau tidak berubah.
  - Konfirmasi dari ⏎ di launcher dan dari shortcut tidak lagi berbagi status: masing-masing harus ditekan dua kali.
  - Keterangan folder untuk skrip berjudul sama memakai jalur foldernya, misalnya `Scripts`, `Scripts/sub`, atau `~/bin`, bukan hanya nama foldernya. Urutan dua skrip berjudul sama tetap, diurutkan menurut kunci.
- **Retensi clipboard**
  - Tombol Delete di konfirmasi memakai pilihan yang sedang ditampilkan alert, tidak bergantung pada urutan event SwiftUI.
  - Kalau menghitung clip gagal, retensi tidak diubah dan muncul pesan "Could not count the clips to delete."
- **Kurs:** daftar ISO ditambah kode baru `XCG`, `ZWG`, dan `VED`. Kode lama tetap diterima.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- Quicklink disimpan di `settings.json`, bukan satu file per quicklink seperti snippet. Daftarnya pendek dan memang termasuk pengaturan.
- Empat quicklink awal: Google, YouTube, GitHub, dan Google Maps.
- Placeholder hanya `{query}`, satu per URL, dan boleh muncul lebih dari sekali.
- Delete quicklink tanpa konfirmasi.
- Cara cepat `<keyword> <teks>` hanya berlaku untuk keyword yang cocok penuh.
- **Minor yang tetap ditunda:**
  - gambar dibaca di main thread sebelum cek 20 MB
  - konflik dengan app yang menangkap kombinasi lewat event tap
  - shortcut skrip yang hilang tetap tidak memberi tanda saat ditekan, karena tidak didaftarkan
