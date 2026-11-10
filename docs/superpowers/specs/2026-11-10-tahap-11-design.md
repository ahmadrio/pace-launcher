# Desain Tahap 11: Perintah Sistem, Perbaikan yang Ditunda

## Maksud
Isi tahap ini adalah minor yang ditunda di ledger tahap 10, ditambah perintah sistem, yang merupakan usulan Claude. Pace memilih langsung mulai ("langsung mulai aja", 10 Nov 2026), jadi semua keputusan di dokumen ini adalah **keputusan Claude** dan bisa dikoreksi.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - Mengunci layar, tidur, dan log out dari launcher atau dengan shortcut global.
  - Minor dari review tahap 10 diperbaiki.
- **Bukan sasaran (ditunda sampai Pace setuju memberi izin baru)**
  - **Restart, Shut Down:** butuh Apple Events ke loginwindow, yang bisa memunculkan permintaan izin Automation.
  - **Empty Trash:** butuh izin Automation untuk Finder, atau Full Disk Access.
  - **Toggle Dark Mode:** butuh izin Automation untuk System Events.
  - **Show Desktop / Mission Control:** shortcut-nya bisa diubah pengguna, jadi tidak andal.
- **Anti-sasaran**
  - Satu ⏎ yang tidak sengaja langsung me-log-out Pace.
  - DOT meminta izin baru tanpa bertanya.
  - Uji otomatis mengunci atau menidurkan Mac Pace.

## Batasan teknis
Sama seperti tahap 10. Perintah sistem hanya memakai izin Accessibility yang sudah ada, atau tidak memakai izin sama sekali.

## Fitur 1: Perintah sistem
| Command | Cara kerja | Konfirmasi |
|---|---|---|
| Lock Screen | mengirim ⌃⌘Q, shortcut kunci layar macOS (butuh Accessibility, yang sudah diberikan) | tidak |
| Sleep | `pmset sleepnow` | tidak |
| Sleep Displays | `pmset displaysleepnow` | tidak |
| Start Screen Saver | membuka `ScreenSaverEngine.app` | tidak |
| Log Out | mengirim ⇧⌘Q, sehingga macOS menampilkan dialog log out-nya sendiri | ⏎ dua kali dalam 3 detik ("Press ↩ again to log out") |

- **Pencarian:** command ini muncul di root seperti command lain, dengan alias `lock`, `kunci`, `sleep`, `tidur`, `screensaver`, `logout`, dan `keluar`.
- **Shortcut global:** Lock Screen, Sleep, Sleep Displays, dan Start Screen Saver bisa diberi shortcut di Settings › Shortcuts › Commands. Log Out tidak, karena butuh konfirmasi.
- **Tanpa Accessibility:** Lock Screen dan Log Out tidak bisa mengirim tombol. Panel lalu menampilkan pesan, dan prompt izin muncul seperti saat paste.
- **Mode uji:** kalau `DOTSystemCommandDryRun` di UserDefaults diisi true, DOT hanya mencatat perintah ke log tanpa menjalankannya. Uji UI memakai mode ini, sehingga Mac Pace tidak pernah terkunci, tertidur, atau ter-log-out.

## Fitur 2: Perbaikan yang ditunda (ledger tahap 10)
- **Browser pilihan gagal diluncurkan:**
  - Sebelum dipakai, DOT memastikan file app-nya masih ada.
  - Kalau peluncuran gagal (lewat callback), quicklink dibuka di browser default, lalu muncul HUD "<Browser> could not open it; opened in the default browser."
- **`browser` tulisan tangan:**
  - Nilai kosong atau berisi spasi saja dianggap tanpa browser.
  - Picker membandingkan bundle id tanpa membedakan huruf besar/kecil, dan daftar browser tidak berisi id ganda.
- **Nama kota yang juga kata biasa:** sesudah jam (`5pm to wake`, `5pm in center`), nama kota seperti wake, center, reunion, resolute, easter, palmer, troll, midway, phoenix, dan jersey tidak dibaca sebagai zona. Bentuk `time in phoenix` tetap bisa.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- Daftar perintah sistem dibatasi pada yang tidak butuh izin baru.
- Lock memakai ⌃⌘Q dan Log Out memakai ⇧⌘Q, yaitu shortcut macOS sendiri.
- Hanya Log Out yang butuh dua kali ⏎. macOS juga masih menampilkan dialognya sendiri.
- Perintah sistem tidak pernah dijalankan sungguhan saat uji; uji memakai mode uji.
- **Minor yang tetap ditunda:**
  - gambar dibaca di main thread sebelum cek 20 MB
  - konflik dengan app yang memakai event tap
  - shortcut skrip yang hilang tidak memberi tanda saat ditekan
