# Handoff: Launcher macOS ala Raycast (gratis)

Ringkasan dari percakapan di claude.ai, untuk dilanjutkan di Claude Code.

## Konteks
- Pace sedang mempertimbangkan membuat sendiri aplikasi launcher macOS mirip Raycast, termasuk fitur yang di Raycast hanya ada di paket Pro, supaya bisa dipakai gratis.
- Alternatif yang sudah dicek:
  - Raycast Free: fitur inti gratis. AI, sync, clipboard tanpa batas, notes tanpa batas, dan custom window management masuk Pro.
  - Sol: open source, tapi fiturnya terbatas.
  - SuperCmd v2: berbayar sekali beli dan wajib macOS 26.
  - Brow: proprietary, status gratisnya tidak jelas.

## Stack (usulan)
Swift + SwiftUI/AppKit, native, tanpa Electron.

## Fitur & pendekatan teknis (usulan)
| Fitur | Tingkat | Pendekatan |
|---|---|---|
| Launcher + hotkey global | Mudah | `NSPanel` non-activating, cari app via `NSMetadataQuery` |
| Kalkulator & konversi | Mudah | Parser ekspresi sendiri, kurs dari API gratis |
| Clipboard history tanpa batas | Mudah–sedang | Polling `NSPasteboard.changeCount`, simpan ke SQLite/SwiftData |
| Notes, quicklinks, custom theme | Mudah | Penyimpanan lokal |
| AI chat | Mudah | API key sendiri (OpenAI/Claude) atau Ollama lokal |
| Translator | Mudah | Framework Translation Apple (macOS 15+), on-device |
| Window management custom | Sedang | Accessibility API (`AXUIElement`), butuh izin Accessibility |
| Snippet auto-expand | Sedang–sulit | `CGEventTap`, banyak edge case |
| Cloud sync | Sedang | CloudKit (butuh Apple Developer berbayar) atau folder iCloud Drive |

## Rekomendasi
- Jangan mengejar kompatibilitas extension Raycast karena terlalu kompleks. Gantinya, buat **script commands**: launcher menjalankan shell script milik pengguna.
- Jangan memakai nama, logo, atau kode Raycast.
- Kalau app akan dibagikan, notarisasi butuh Apple Developer Program ($99/tahun). Tanpa itu, pengguna akan kena peringatan Gatekeeper.

## Rencana bertahap (usulan, belum dikonfirmasi)
1. MVP: launcher, kalkulator, clipboard history, window snapping
2. Snippets, notes, AI chat, translate
3. Sync, tema, script commands

## Belum diputuskan
- Target minimal versi macOS. Ini menentukan API yang bisa dipakai.
- Nama aplikasi.
- Apakah akan open source / dibagikan publik.

## Langkah berikutnya
Konfirmasi target macOS dengan Pace, lalu buat skeleton proyek untuk MVP tahap 1.
