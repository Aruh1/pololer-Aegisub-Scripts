# pololer Aegisub Scripts

Kumpulan automation scripts untuk Aegisub, terinspirasi dari fitur-fitur Subtitle Edit.

## 📦 Scripts

### Frame Gap (`polo.FrameGap.lua`)

Script untuk mengatur gap (jarak waktu) antar subtitle, mirip dengan fitur Frame Gap di Subtitle Edit.

#### Fitur

| Menu | Fungsi |
|------|--------|
| **Apply Frame Gap...** | Buat gap dengan pengaturan kustom |
| **Quick Apply (1 frame @ 23.976fps)** | Cepat buat gap 1 frame (~42ms) |
| **Apply to Selection** | Buat gap untuk line yang dipilih |
| **De-Frame Gap...** | Hapus gap dengan pengaturan kustom |
| **Quick De-Frame Gap (0ms)** | Cepat hapus semua gap |
| **De-Frame Gap Selection** | Hapus gap untuk line yang dipilih |

#### Frame Rate yang Didukung

- 23.976fps (Film/Anime)
- 24fps
- 25fps (PAL)
- 29.97fps (NTSC)
- 30fps
- 50fps (PAL HD)
- 59.94fps (NTSC HD)
- 60fps

#### Cara Kerja

**Frame Gap** memendekkan waktu akhir subtitle agar ada jarak minimum dengan subtitle berikutnya. Ini mencegah masalah tampilan pada beberapa video player yang tidak bisa menampilkan subtitle dengan benar jika timing-nya terlalu berdekatan.

**De-Frame Gap** memperpanjang waktu akhir subtitle agar menyentuh (atau mendekati) waktu mulai subtitle berikutnya. Berguna untuk subtitle yang ingin tampilannya kontinyu.

---

### KaraSplitter (`polo.KaraSplitter.lua`)

Script untuk membagi teks menjadi karaoke timing, port dari [karasplitter-web](https://github.com/Yurasubs/karasplitter-web).

#### Fitur

| Menu | Fungsi |
|------|--------|
| **Split...** | Bagi karaoke dengan pengaturan kustom |
| **Split by Character** | Bagi per karakter |
| **Split by Word** | Bagi per kata |
| **Split by Syllable** | Bagi per suku kata (romaji Jepang) |
| **De-Ktime** | Hapus semua tag karaoke timing |

#### Mode Split

- **Character**: Setiap karakter mendapat timing sendiri (punctuation digabung ke karakter sebelumnya)
- **Word**: Setiap kata (dipisah spasi) mendapat timing sendiri
- **Syllable**: Romaji Jepang dibagi per suku kata (mendukung pola: ka, ki, ku, ke, ko, sha, shi, shu, chi, tsu, dll.)

#### K-Time Options

- **Calculated**: Timing dihitung berdasarkan durasi line dibagi jumlah karakter
- **Fixed {\\k1}**: Setiap bagian mendapat `{\\k1}` (untuk editing manual)

## 🔧 Instalasi

1. Copy file `.lua` ke folder Aegisub automation:
   - **Windows**: `%APPDATA%\Aegisub\automation\autoload\`
   - **Portable**: `[Aegisub folder]\automation\autoload\`
   
2. Restart Aegisub atau pilih **Automation → Rescan Autoload Dir**

## 📋 Penggunaan

1. Buka subtitle file di Aegisub
2. Pilih line yang ingin diproses
3. Pilih **Automation → [Script Name] → [pilih menu]**
4. Atur parameter sesuai kebutuhan
5. Klik **Apply**

## 📝 Changelog

### Frame Gap

#### v1.2
- **Optimisasi performa**: Lazy loading selection set, pre-calculated dialogue count
- **Bug fix**: Menambahkan `return sel` yang hilang pada semua fungsi macro
- **Bug fix**: Early exit untuk file dengan < 2 dialogue lines
- **Refactor**: Ganti `goto continue` dengan control flow yang lebih bersih
- **Dokumentasi**: Tambah LuaDoc annotations untuk fungsi utama

#### v1.1
- Tambah fitur De-Frame Gap
- Perbaikan bug perhitungan waktu (ms vs cs)
- Perbaikan dropdown frame rate

#### v1.0
- Rilis awal dengan fitur Frame Gap

### KaraSplitter

#### v1.0
- Rilis awal
- Split modes: character, word, syllable (Japanese romaji)
- K-timing options: calculated atau fixed {\\k1}
- De-Ktime: Hapus semua tag karaoke timing
- Full UTF-8 support

## 👤 Author

**pololer**

## 📄 License

MIT License - Bebas digunakan dan dimodifikasi.
