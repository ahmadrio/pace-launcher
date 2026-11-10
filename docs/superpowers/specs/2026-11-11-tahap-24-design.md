# Desain Tahap 24: Siap Publik

## Maksud
Tahap terakhir dari rencana rilis publik (keputusan Pace, 10 Nov 2026): PACE Launcher menjadi repo open source `ahmadrio/pace-launcher` di GitHub dengan rilis pertama v1.0.0. Tahap ini menyiapkan semua yang dilihat orang di halaman GitHub dan memastikan tidak ada rahasia yang ikut publik. **Membuat repo, push, dan merilis hanya dilakukan setelah Pace bilang ya saat itu**, karena tidak bisa ditarik kembali. Pace memilih langsung mulai, jadi detail di bawah adalah **keputusan Claude** dan bisa dikoreksi.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - Pengunjung halaman GitHub langsung paham: apa PACE, seperti apa tampilannya, syaratnya (macOS 27, Apple silicon), cara memasang, dan bahwa app tidak dinotarisasi.
  - Lisensi GPL-3.0 yang sah, dan kebijakan privasi yang sesuai dengan perilaku app.
  - Tidak ada kunci, token, atau kredensial di seluruh riwayat git.
  - DMG v1.0.0 dibuat dari commit yang di-tag, dengan checksum.
  - Kekurangan kecil skrip rilis dari tahap 22 dibereskan.
- **Bukan sasaran**
  - Homebrew, situs web, CI, notarisasi.
  - Menulis ulang riwayat git (Pace memilih "Repo ini apa adanya").
  - Menerjemahkan dokumen internal (`HANDOFF.md`, `docs/superpowers/`) ke bahasa Inggris.
- **Anti-sasaran**
  - Repo menjadi publik atau rilis terunggah tanpa ya dari Pace saat itu.
  - README yang menjanjikan sesuatu yang tidak dilakukan app, atau kebijakan privasi yang tidak cocok dengan kode.
  - Memakai nama Raycast untuk memasarkan PACE.

## Halaman repo
- **README.md** (bahasa Inggris), dari atas:
  1. Ikon app, nama, dan satu kalimat: launcher gratis dan open source untuk macOS yang bekerja di Mac pengguna.
  2. Screenshot launcher dan jendela sambutan, diambil dari data uji (`docs/images/`).
  3. Syarat dan peringatan singkat: macOS 27 di Apple silicon; tidak dinotarisasi, jadi pertama kali dibuka lewat Open Anyway.
  4. Instal: tautan ke rilis terbaru dan ke `docs/INSTALL.md`.
  5. Fitur, ringkas per kelompok: launcher dan pencarian app, kalkulator (unit, kurs, tanggal/zona waktu), clipboard history, snippets dan auto-expand, window snapping, notes, quicklinks, script commands, AI chat dan terjemahan on-device, emoji, perintah sistem, tema, shortcut, sync iCloud opsional, cek update.
  6. Privasi: ringkasan dan tautan ke `PRIVACY.md`.
  7. Build dari source, struktur repo singkat, dan lisensi.
  - Format header skrip `@raycast.*` disebut hanya sebagai fakta teknis (header yang ikut dibaca), bukan sebagai perbandingan produk.
- **LICENSE:** teks resmi GPL-3.0 (dari API lisensi GitHub, sama dengan yang dipakai GitHub untuk mengenali lisensi).
- **PRIVACY.md** (bahasa Inggris): data apa yang disimpan dan di mana (folder lokal; iCloud Drive hanya kalau sync dinyalakan; UserDefaults), clipboard history (isi password manager dilewati; tetap bisa berisi data sensitif), tanpa analitik atau pelacakan, dua koneksi internet (kurs, cek update) beserta isinya, AI dan terjemahan berjalan di Mac (model diunduh oleh macOS, bukan oleh PACE), izin yang diminta, dan cara menghapus data.
- **Catatan rilis v1.0.0** disimpan di `docs/releases/v1.0.0.md` dan dipakai sebagai isi GitHub Release: ringkasan fitur, syarat, langkah pasang (checksum, Open Anyway), SHA-256.
- **`docs/INSTALL.md`:** tautan langsung ke `https://github.com/ahmadrio/pace-launcher/releases/latest`.

## Skrip rilis (minor tahap 22)
1. `grep -q` di bawah `pipefail` bisa salah membaca "tidak ditemukan" (SIGPIPE): daftar identitas ditangkap ke variabel dulu (`build-app.sh`, `make-signing-identity.sh`).
2. `make-signing-identity.sh` mencari identitas yang sudah ada di semua keychain yang dipakai `codesign`, bukan hanya login keychain.
3. DMG dibuat dengan nama sementara dan baru diberi nama final setelah semua cek lolos; kalau gagal, file sementara dihapus.
4. Paket dari pohon yang belum di-commit (`PACE_ALLOW_DIRTY=1`) diberi akhiran `-dirty`; di luar checkout git, skrip menolak jalan.
5. Error `openssl` tidak disembunyikan, dan kegagalan `openssl rand` tidak tertutup oleh `export`.
6. Isi DMG dicek termasuk file tersembunyi (`ls -A`).
- `make-signing-identity.sh` **tidak dijalankan** untuk menguji: kalau ceknya salah, ia membuat identitas kedua di keychain Pace. Bagian ceknya diuji terpisah.

## Pemindaian akhir
- `gitleaks` atas seluruh riwayat git, ditambah pencarian pola sendiri: kunci privat, token (`ghp_`, `gho_`, `sk-`, `xox`), kata sandi, alamat email, path `/Users/`, alamat IP, dan nama orang.
- Hasilnya dilaporkan ke Pace sebelum publikasi. Yang memang ikut publik atas keputusannya (email di metadata commit, nama "Ahmad", sebutan app dan profil browser di dokumen internal) didaftar ulang supaya ia memutuskan dengan informasi terbaru.

## Publikasi (hanya setelah ya dari Pace)
1. `make release` dari commit di `main` yang akan di-tag.
2. `gh repo create ahmadrio/pace-launcher --public` dengan deskripsi singkat, lalu push `main`.
3. Tag `v1.0.0`, push tag.
4. `gh release create v1.0.0` dengan DMG, `.sha256`, dan catatan rilis.
5. Cek: halaman repo mengenali lisensi GPL-3.0, `releases/latest` di API mengembalikan `v1.0.0` (yang dibaca cek update app), dan checksum file yang diunduh dari GitHub cocok.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- README dengan dua screenshot dari data uji; bahasa Inggris.
- Catatan rilis disimpan di repo (`docs/releases/`).
- Semua enam minor skrip dibereskan, tetapi skrip pembuat sertifikat tidak dijalankan.
- Deskripsi repo: "A free, open-source launcher for macOS 27: apps, calculator, clipboard history, snippets, window snapping and more."
- Tidak ada topik, wiki, atau GitHub Pages; Issues dibiarkan menyala (bawaan GitHub).
