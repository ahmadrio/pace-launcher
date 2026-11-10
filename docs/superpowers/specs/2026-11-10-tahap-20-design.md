# Desain Tahap 20: Sisa Perbaikan Kecil

## Maksud
- **Konfirmasi Pace (10 Nov 2026, 22:45):** Restart yang dipicu lagi saat dialognya masih terbuka diabaikan dengan aman ("untuk restart sudah aman").
- Tahap ini menutup minor yang ditunda di ledger tahap 19 dan dua sisa lama di form skrip. Pace memilih langsung mulai ("langsung mulai aja"), jadi detail di bawah adalah **keputusan Claude** dan bisa dikoreksi. Tidak ada izin baru.

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - Log kegagalan perintah sistem tersimpan permanen.
  - Pesan "sedang berjalan" yang jelas.
  - Form skrip berisi password bisa dijalankan dengan satu ↩.
  - Form yang isian pertamanya dropdown langsung fokus ke isian teks.
- **Bukan sasaran**
  - Fitur baru.
  - Izin baru.
- **Anti-sasaran**
  - Isi password muncul di log.
  - Mengetik ke tempat yang salah.

## Fitur 1: Log kegagalan
Baris "finished" yang hasilnya bukan `done` (izin ditolak, timeout, gagal, dibatalkan, sudah berjalan) dicatat di level `.notice`, sehingga tersimpan dan bisa dibaca dengan `log show`. Hasil `done` tetap di level `.info`.

## Fitur 2: Pesan "sedang berjalan"
| Perintah | HUD |
|---|---|
| Restart | "The restart dialog is already open." |
| Shut Down | "The shutdown dialog is already open." |
| Empty Trash | "Empty Trash is already running." |
| Toggle Dark Mode | tidak pernah, karena mengantre |

## Fitur 3: Form skrip
- **Isian password:** diberi jenis isi "one-time code", sehingga macOS tidak menampilkan popup AutoFill "Passwords…" yang menelan ↩. Ini sudah diuji: popupnya hilang, dan ketikan awal plus satu ↩ menjalankan skrip dengan nilai utuh.
- **Dropdown di isian pertama:** fokus pindah ke isian teks atau password pertama, dan ketikan awal masuk ke sana. Form yang hanya berisi dropdown tetap seperti sekarang.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- **"One-time code" dipakai untuk mematikan AutoFill password.** Akibatnya:
  - AutoFill dari Keychain/Passwords tidak lagi ditawarkan di isian password skrip.
  - Kalau ada kode verifikasi baru dari Messages atau Mail, macOS bisa menawarkannya selama beberapa menit, dan ↩ pertama bisa tertelan lagi. Kasus ini belum diuji dengan kode sungguhan (catatan review akhir).
- **Minor lama yang tetap ditunda:**
  - Gambar clipboard dibaca di main thread.
  - Konflik event tap.
  - `recordsUse` belum punya unit test.
  - Runner hanya diverifikasi dengan membaca kode.
