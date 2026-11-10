# Desain Tahap 19: Perbaikan yang Ditunda dari Tahap 18

## Maksud
Tahap ini memperbaiki minor yang ditunda di ledger tahap 18. Pace memilih langsung mulai ("langsung mulai aja", 10 Nov 2026), jadi semua keputusan di dokumen ini adalah **keputusan Claude** dan bisa dikoreksi. Tidak ada izin baru.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - Mencari tema DOT langsung membuka bagian Appearance.
  - Perintah sistem yang masih berjalan tidak dipicu dua kali.
  - Pesan timeout jujur.
  - Antrean AppleScript punya unit test.
  - Notes dan editor snippet terbukti ikut berganti terang/gelap.
- **Bukan sasaran**
  - Fitur baru.
  - Izin baru.
- **Anti-sasaran**
  - Dialog Restart muncul lagi setelah Pace menekan Cancel.
  - Pesan "masih bekerja" padahal sebenarnya tidak ada yang berjalan.

## Batasan teknis
Sama seperti tahap 18. Tidak ada izin baru.

## Fitur 1: Perintah "Appearance Settings"
- Perintah baru membuka Settings langsung di bagian Appearance.
- Aliasnya `theme`, `tema`, `appearance`, dan `tampilan`, dipindah dari perintah Settings.

## Fitur 2: Satu jalan per perintah
- **Toggle Dark Mode** tetap mengantre, sehingga dua tekan berjalan berurutan dan kembali ke posisi semula.
- **Restart, Shut Down, dan Empty Trash:** selama perintahnya masih berjalan, misalnya dialog macOS masih tampil, permintaan berikutnya **diabaikan**, dengan HUD "<Perintah> is already running."
- **Logika antrean ada di Core** dan diuji. Log mencatat kapan setiap jalan mulai dan selesai.

## Fitur 3: Pesan timeout
- **Empty Trash:** "Finder is still working on it." (bukan error).
- **Perintah lain:** "<app> did not answer in time." (error). Ini biasanya terjadi karena dialog izin Automation dibiarkan.

## Fitur 4: Uji Notes dan editor snippet
Screenshot Notes dan editor snippet diambil dalam mode Dark dan Light, dengan tampilan Mac diganti lewat Toggle Dark Mode DOT lalu dikembalikan.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- Permintaan ganda untuk Restart, Shut Down, dan Empty Trash diabaikan, tidak diantre.
- Perintah Appearance Settings tidak diberi shortcut global.
