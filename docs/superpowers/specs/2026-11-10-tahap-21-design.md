# Desain Tahap 21: DOT Launcher Menjadi PACE Launcher

## Maksud
Persiapan rilis publik. Pace memutuskan (10 Nov 2026, 23:00–23:12) bahwa app dirilis sebagai **PACE Launcher**: open source di GitHub (akun `ahmadrio`), GPL-3.0, lewat GitHub Releases, tanpa Apple Developer Program. Tahap ini hanya mengganti nama dan memindahkan data lama; paket rilis menyusul di tahap 22–24. Detail di bawah adalah **keputusan Claude** dan bisa dikoreksi.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - Semua yang terlihat pengguna bernama PACE Launcher.
  - Kode, modul, dan file build ikut berganti nama.
  - Data dan pengaturan lama Pace pindah utuh pada pembukaan pertama.
- **Bukan sasaran**
  - Paket rilis, sertifikat self-signed, README, dan lisensi (tahap 22–24).
  - Menulis ulang dokumen sejarah (spec/plan/ledger lama tetap memakai nama DOT).
- **Anti-sasaran**
  - Data lama hilang atau tertimpa.
  - iCloud Drive disentuh saat sync tidak aktif.
  - Dua app (DOT dan PACE) berebut shortcut di Mac Pace.

## Nama dan identitas
| Hal | Lama | Baru |
|---|---|---|
| Nama app | DOT Launcher | PACE Launcher |
| Bundle ID | `com.pace.DOTLauncher` | `io.github.ahmadrio.PACELauncher` |
| Executable dan modul | `DOTLauncher`, `DOTLauncherCore` | `PACELauncher`, `PACELauncherCore` |
| Folder data | `~/Library/Application Support/DOT Launcher` | `…/PACE Launcher` |
| Folder iCloud | `iCloud Drive/DOT Launcher` | `iCloud Drive/PACE Launcher` |
| Jendela Notes | DOT Notes | PACE Notes |
| Header skrip | `@dot.*`, `@raycast.*` | `@pace.*` (baru, dipakai template); `@dot.*` dan `@raycast.*` tetap diterima |
| Kunci uji | `DOTDataRootOverride`, dll. | `PACEDataRootOverride`, dll. |

## Pemindahan data saat pertama dibuka
- **Pengaturan (UserDefaults):** isi domain lama disalin sekali ke domain baru.
  - Posisi jendela ikut, dengan nama baru.
  - Kunci uji tidak ikut.
  - Penandanya adalah `migratedFromDOTLauncher`.
- **Folder lokal:** kalau folder lama ada dan folder baru belum ada, folder lama **dipindahkan** (bukan disalin) ke nama baru. Kalau keduanya ada, tidak ada yang disentuh; folder baru yang dipakai, dan kejadian ini dicatat di log.
- **Folder iCloud:** dipindahkan dengan aturan yang sama, tapi **hanya kalau sync aktif**. Saat sync mati, iCloud Drive tidak disentuh.
- **Saat folder uji dipakai** (kunci override): tidak ada pemindahan.
- **Izin** Accessibility, Input Monitoring, dan Automation terikat pada bundle ID, jadi perlu diberi ulang sekali. Login item lama juga perlu diaktifkan ulang kalau sebelumnya aktif.

## Di Mac Pace
1. Backup lengkap folder data dan pengaturan lama dibuat di scratchpad.
2. DOT Launcher.app dipindahkan dari `~/Applications` ke scratchpad, sehingga bisa dikembalikan.
3. PACE Launcher dipasang. Pemindahan dicek dengan membandingkan jumlah clip, snippet, catatan, dan isi `settings.json`.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- **Folder dipindahkan, bukan disalin,** supaya database SQLite beserta file WAL-nya tetap utuh dan tidak ada dua salinan yang membingungkan.
- **Nama modul dan kunci uji ikut diganti** supaya repo publik konsisten.
- **`@pace.*` menjadi header resmi,** tapi `@dot.*` tetap diterima supaya skrip lama tetap jalan.
