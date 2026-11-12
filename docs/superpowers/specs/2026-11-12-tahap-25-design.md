# Desain Tahap 25: Semua Emoji Unicode 17

## Maksud
Pace: "tolong daftarkan semua emoji karena saya cek masih ada beberapa emoji yang belum ada" (12 Nov 2026). Pace menyetujui rencana Claude tanpa koreksi, jadi semua keputusan di dokumen ini adalah **keputusan Claude** dan bisa dikoreksi.

## Temuan
- Katalog hanya membangun emoji **satu code point** dari properti Unicode Swift, ditambah bendera negara. Emoji gabungan sejak tahap 8 ada di "Bukan sasaran".
- Hasil diff dengan `emoji-test.txt` Unicode 17.0 (fully-qualified, tanpa varian skin tone): resmi **1914**, katalog **1648**, jadi **266 hilang**. Tidak ada entri katalog di luar daftar resmi.
  - ZWJ orang: profesi, aktivitas, keluarga, olahraga, gestur pria/wanita, fantasi, rambut, pasangan
  - ZWJ lain: 😮‍💨 😶‍🌫️ 😵‍💫 🙂‍↔️ ❤️‍🔥 ❤️‍🩹 👁️‍🗨️ 🐈‍⬛ 🐻‍❄️ 🐦‍🔥 🍋‍🟩 ⛓️‍💥, dan lainnya
  - Keycap #️⃣ *️⃣ 0️⃣–9️⃣, serta ©️ ®️
  - Bendera 🏳️‍🌈 🏳️‍⚧️ 🏴‍☠️ 🏴󠁧󠁢󠁥󠁮󠁧󠁿 🏴󠁧󠁢󠁳󠁣󠁴󠁿 🏴󠁧󠁢󠁷󠁬󠁳󠁿
- Pustaka standar Swift 6.4.2 di macOS 27.2.1 sudah Unicode 17, jadi emoji satu code point sampai Emoji 17 sudah lengkap.
- Apple Color Emoji menggambar semua sequence Unicode 17. Emoji 18.0 (🫫, 🛙) belum didukung (jatuh ke font cadangan, lebarnya berbeda).

## Sasaran, bukan sasaran, anti-sasaran
- **Sasaran**
  - Semua emoji RGI Unicode 17 bisa dicari dan ditempel.
  - Skin tone (⌘T, ⌘⇧T) berlaku untuk sequence yang punya bentuk berwarna kulit di Unicode.
- **Bukan sasaran**
  - Kombinasi tone campuran (🧑🏻‍🤝‍🧑🏿, 🫱🏻‍🫲🏿). Satu tone berlaku untuk semua orang dalam emoji.
  - Emoji 18.0, karena font macOS belum mendukungnya.
  - Kata kunci CLDR lengkap.
- **Anti-sasaran**
  - Id pemakaian (`emoji:<karakter>`), nama, urutan, dan kata kunci emoji yang sudah ada berubah, sehingga frecency dan `emojiSkinTones` Pace hilang.
  - Emoji yang tidak bisa digambar font Apple masuk katalog.

## Desain
- **Hibrida.** Emoji satu code point tetap dari properti Swift, jadi ikut naik otomatis saat Unicode di macOS diperbarui. Sequence (ZWJ, keycap, tag flag) diambil dari tabel hasil generator.
- **Generator `scripts/make-emoji-data.swift <emoji-test.txt>`.** Script tidak mengakses jaringan. Hasilnya dua file:
  - `Sources/PACELauncherCore/Emoji/EmojiSequences.swift`: satu string literal, satu baris per sequence: `HEX…;nama CLDR[;HEX bentuk medium]`.
  - `Tests/PACELauncherCoreTests/UnicodeEmojiList.swift`: semua emoji dasar dan semua bentuk dengan tone medium seragam, untuk tes.
  - Generator gagal kalau ada sequence atau bentuk bertone yang tidak digambar Apple Color Emoji selebar satu emoji.
- **©️ ®️** masuk lewat rentang `0xA9...0xAE` di akhir simbol. Karakter polos `©`, `#`, dan digit tetap tidak masuk.
- **Urutan**
  - Sequence ditaruh tepat setelah emoji tempatnya bermula (🤷 🤷‍♂️ 🤷‍♀️).
  - Keycap menutup bagian simbol.
  - Bendera England, Scotland, dan Wales diurutkan bersama bendera negara, dengan kata kunci nama tempatnya.
- **Nama** memakai nama CLDR dari emoji-test, huruf pertama dikapitalkan dan sisanya dibiarkan ("Man technologist", "Keycap: 1", "Flag: England").
- **Skin tone**
  - Sequence memakai bentuk Unicode dengan satu tone untuk semua orang: 🧑‍🤝‍🧑 → 🧑🏽‍🤝‍🧑🏽, 🏌️‍♂️ → 🏌🏽‍♂️.
  - Sequence tanpa bentuk itu tidak berubah (keluarga 👨‍👩‍👧, ❤️‍🔥, keycap, bendera).
  - **👯 dan 🤼 kini bisa diberi tone** karena baru resmi di Unicode 17 dan font Apple punya glyph-nya sendiri. 👪 tetap tidak.
- **Kata kunci baru**
  - 🧑‍💻: programmer, developer, coding, ngoding
  - 😮‍💨: sigh, lega, capek
  - 🏳️‍🌈: pride
  - Tabel kata kunci kini dikunci dengan karakter utuh tanpa FE0F, tidak lagi dengan code point pertama.

## Keputusan yang diambil Claude (bisa dikoreksi Pace)
- Data memakai Unicode 17.0, bukan 18.0.
- Pendekatan hibrida dipilih, bukan satu tabel penuh dari emoji-test. Akibatnya nama emoji lama tetap nama Unicode, misalnya "Shrug" berdampingan dengan "Man shrugging".
- ©️ ®️ dan keycap masuk katalog.
- 👯 🤼 bisa diberi tone.
- Rilis v1.0.1 dan push hanya setelah Pace setuju.
