# Desain Tahap 13: Perbaikan yang Ditunda

## Maksud
Tahap ini memperbaiki minor yang ditunda di ledger tahap 12 dan satu sisa lama. Pace memilih langsung mulai ("langsung mulai aja", 10 Nov 2026), jadi semua keputusan di dokumen ini adalah **keputusan Claude** dan bisa dikoreksi. Perintah yang butuh izin baru (Restart, Shut Down, Empty Trash, Dark Mode) **tetap tidak dibuat**.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - Pesan konfirmasi Log Out dan masa berlakunya selalu sama.
  - Emoji berwarna kulit selalu berupa urutan resmi Unicode (RGI).
  - Shortcut skrip yang filenya hilang memberi tanda saat ditekan.
- **Bukan sasaran**
  - **Profil browser per quicklink:** ditunda. Di Mac Pace, Chrome dan Brave masing-masing hanya punya satu profil ("Ahmad" dan "Work"), dan pilihan browser per quicklink sudah memisahkan keduanya. Fitur ini baru berguna kalau ada browser dengan lebih dari satu profil.
  - Perintah sistem yang butuh izin baru.
- **Anti-sasaran**
  - ↩ yang tidak sengaja me-log-out Pace.
  - `settings.json` lama tidak terbaca setelah nama pilihan diubah.

## Batasan teknis
Sama seperti tahap 12. Tidak ada izin baru.

## Fitur 1: Konfirmasi Log Out
- **Pesan dan ↩ pertama berakhir bersamaan:** "Press ↩ again to log out" hilang dari footer begitu masa 3 detiknya habis. Setelah itu ↩ hanya memunculkan pesan lagi.
- **↩ kedua dihitung** hanya kalau pesan itu masih tampil dan masih dalam 3 detik. Aturan ini sekarang ada di Core dan punya unit test.

## Fitur 2: Emoji
- **Tiga emoji dasar tidak diberi warna kulit:** 👪 (family), 👯 (people with bunny ears), dan 🤼 (wrestlers). Unicode mendaftarkannya sebagai emoji dasar, tapi tidak punya urutan resmi berwarna kulit, sehingga app yang memakai gambar emoji sendiri bisa menampilkan emoji plus kotak warna.
- **Nama pilihan di kode menjadi `.default`.** Nilai di `settings.json` tetap `"none"`, jadi file lama tetap terbaca.

## Fitur 3: Shortcut skrip yang filenya hilang
- **Shortcut-nya tetap didaftarkan.** Saat ditekan muncul HUD merah "Script not found: <nama file>", bukan diam saja. Ini mengubah keputusan tahap 6, yang sengaja tidak mendaftarkan shortcut itu.
- **Settings › Shortcuts tetap menampilkan baris "Not found on this Mac"** dengan tombol Remove.
- **Begitu filenya kembali,** shortcut langsung menjalankan skripnya lagi, dan judulnya ikut diperbarui.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- Profil browser ditunda dengan alasan di atas.
- **Shortcut skrip yang hilang ikut memakai kombinasi tombolnya.** Kalau `settings.json` tersinkron ke Mac lain yang tidak punya skrip itu, kombinasi tersebut tetap dipakai DOT di sana dan hanya memunculkan HUD.
- **Minor yang tetap ditunda:**
  - Gambar clipboard dibaca di main thread sebelum cek 20 MB. Memindahkannya butuh kepastian bahwa NSPasteboard aman dibaca di luar main thread.
  - Konflik dengan app yang memakai event tap tidak bisa dideteksi.
  - Pencatatan pemakaian (`recordsUse`) belum punya unit test karena ada di target app.
