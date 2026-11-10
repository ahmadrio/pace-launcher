# Desain Tahap 17: Restart, Shut Down, Empty Trash, Dark Mode

## Maksud
Pace mengizinkan DOT memakai izin **Automation** saja, tanpa Full Disk Access ("ya, lanjut tahap 17 pakai Automation saja", 10 Nov 2026). Empat perintah sistem yang tertunda sejak tahap 11 sekarang dibuat. Detail di bawah adalah **keputusan Claude** dan bisa dikoreksi.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran:** Restart, Shut Down, Empty Trash, dan Toggle Dark Mode bisa dijalankan dari launcher. Toggle Dark Mode juga bisa diberi shortcut global.
- **Bukan sasaran:**
  - Full Disk Access.
  - Membaca isi Trash, misalnya untuk menampilkan jumlah item.
  - Restart atau Shut Down tanpa dialog macOS.
- **Anti-sasaran:**
  - ↩ yang tidak sengaja me-restart, mematikan Mac, atau mengosongkan Trash.
  - Uji otomatis menjalankan perintah ini sungguhan.
  - Izin ditolak, tapi DOT diam saja.

## Batasan teknis
- Sama seperti tahap 16.
- **Izin baru hanya Automation**, yaitu mengirim Apple Event ke loginwindow, Finder, dan System Events.
- `Info.plist` wajib berisi `NSAppleEventsUsageDescription`. Tanpa kalimat itu macOS langsung menolak tanpa bertanya.

## Fitur
| Command | Cara kerja | Konfirmasi di DOT | Shortcut global |
|---|---|---|---|
| Restart | Apple Event "show restart dialog" ke loginwindow; macOS lalu menampilkan dialognya sendiri | ↩ dua kali ("Press ↩ again to restart") | tidak |
| Shut Down | Apple Event "show shutdown dialog" ke loginwindow | ↩ dua kali ("Press ↩ again to shut down") | tidak |
| Empty Trash | `tell application "Finder" to empty trash` | ↩ dua kali ("Press ↩ again to empty the Trash"); HUD "Emptied the Trash." | tidak |
| Toggle Dark Mode | `tell application "System Events" to tell appearance preferences to set dark mode to not dark mode` | tidak | bisa |

- **Pelaksanaan:** AppleScript dijalankan oleh `/usr/bin/osascript` sebagai proses anak DOT, sehingga main thread tidak tertahan. macOS mencatat izinnya atas nama DOT Launcher.
- **Pemakaian pertama:** macOS menampilkan "DOT Launcher wants access to control …". Setelah Pace mengizinkan, DOT tercantum di System Settings › Privacy & Security › Automation.
- **Kalau izin ditolak (error -1743):**
  - HUD menampilkan "Allow DOT Launcher to control <app> in Privacy & Security › Automation."
  - DOT membuka panel Automation di System Settings.
- **Cancel di dialog macOS (error -128):** tidak ada pesan.
- **Error lain:** HUD menampilkan "Could not <perintah>: <pesan singkat>".
- **Pencarian:** alias `reboot`, `mulai ulang`, `shutdown`, `matikan`, `trash`, `kosongkan sampah`, `dark mode`, `light mode`, `mode gelap`.
- **Mode uji:** dengan `DOTSystemCommandDryRun`, keempatnya hanya dicatat ke log.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- **Konfirmasi ganda untuk Restart dan Shut Down:** DOT meminta ↩ dua kali, lalu macOS tetap menampilkan dialognya. Dialog macOS berjalan sendiri setelah 60 detik kalau dibiarkan, jadi satu ↩ yang tidak sengaja tidak boleh langsung memunculkannya.
- **Empty Trash lewat Finder,** tidak menghapus `~/.Trash` langsung, karena cara langsung butuh Full Disk Access.
- **Uji otomatis hanya memakai mode uji.** Pace mencoba sendiri pemakaian pertamanya, yang juga memunculkan dialog izin.
