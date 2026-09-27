<h1 align="center">
  <img src="assets/logo.svg" alt="compress-img.sh" width="640">
</h1>

<p align="center">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-green">
  <img alt="Bash 4+" src="https://img.shields.io/badge/bash-4%2B-4EAA25?logo=gnubash&logoColor=white">
  <img alt="Platform: Linux" src="https://img.shields.io/badge/platform-linux-lightgrey?logo=linux&logoColor=white">
  <img alt="Formats: PNG, JPG, WebP" src="https://img.shields.io/badge/formats-PNG%20%7C%20JPG%20%7C%20WebP-blue">
</p>

<p align="center"><b>🇮🇩 Bahasa Indonesia</b> · <a href="README.md">English</a></p>

**compress-img.sh** memampatkan setiap gambar di sebuah folder hingga di bawah batas ukuran pilihanmu (default **2 MB**) — secara paralel, memakai semua core CPU — dan tidak pernah menghasilkan file yang lebih besar dari aslinya.

Taruh saja folder berisi screenshot, hasil ekspor, atau gambar upload; kamu dapat kembali folder `compressed/` yang siap untuk web.

## ✨ Fitur

- **Target ukuran per file** — terus berusaha (turunkan kualitas → turunkan resolusi) sampai tiap file muat di bawah `-m`
- **Hasil terbaik selalu menang** — kandidat terkecil dari semua percobaan yang disimpan; file yang tidak bisa menyusut disalin apa adanya
- **Paralel secara default** — satu worker per core CPU via `xargs -P`
- **PNG · JPG/JPEG · WebP** dalam satu perintah, masing-masing dengan kompresor terbaik di kelasnya (`pngquant`, `jpegoptim`, `cwebp`)
- **Aman secara desain** — file asli hanya dihapus setelah hasil terverifikasi tersimpan dan memenuhi batas (matikan dengan `-k`)
- **Mode rekursif** (`-r`) untuk seluruh pohon direktori; folder `compressed/` yang sudah ada tidak pernah diproses ulang
- **Laporan jujur** — penghematan per file, total per folder, dan daftar file yang gagal memenuhi batas

## ⚡ Mulai cepat

```bash
git clone https://github.com/tirsasaki/compress-img.sh.git
cd compress-img.sh
chmod +x compress-img.sh

# instal kompresor (contoh Arch)
sudo pacman -S pngquant jpegoptim libwebp imagemagick

# kompres semua gambar di ./photos → ./photos/compressed
./compress-img.sh ./photos
```

Mau tersedia di `$PATH`?

```bash
sudo install -m 755 compress-img.sh /usr/local/bin/compress-img
```

## 📦 Kebutuhan

| Kebutuhan | Fungsi | Contoh instalasi |
|---|---|---|
| `bash` ≥ 4, `coreutils`, `findutils`, `awk` | runtime script | umumnya sudah terinstal |
| `pngquant` | kompresi PNG | `sudo pacman -S pngquant` / `sudo apt install pngquant` |
| `jpegoptim` | kompresi JPG/JPEG | `sudo pacman -S jpegoptim` / `sudo apt install jpegoptim` |
| `cwebp` (`libwebp`) | kompresi WebP | `sudo pacman -S libwebp` / `sudo apt install webp` |
| `imagemagick` *(opsional, disarankan)* | fallback penurunan resolusi | `sudo pacman -S imagemagick` / `sudo apt install imagemagick` |

Kompresor tidak ada? Script memberi peringatan dan format tersebut dilewati saja. ImageMagick tidak ada? Kualitas tetap diturunkan, hanya langkah penurunan resolusi yang tidak tersedia.

<details>
<summary><b>📋 Perintah instalasi lengkap per distribusi</b></summary>

```bash
# Debian / Ubuntu / Mint / Pop!_OS
sudo apt update && sudo apt install bash coreutils findutils gawk pngquant jpegoptim webp imagemagick

# Fedora / RHEL / Rocky / Alma (mungkin butuh EPEL untuk pngquant/jpegoptim)
sudo dnf install bash coreutils findutils gawk pngquant jpegoptim libwebp-tools ImageMagick

# Arch / Manjaro / EndeavourOS / CachyOS
sudo pacman -S bash coreutils findutils gawk pngquant jpegoptim libwebp imagemagick

# openSUSE
sudo zypper install bash coreutils findutils gawk pngquant jpegoptim libwebp-tools ImageMagick

# Alpine (aktifkan repo community bila perlu)
sudo apk add bash coreutils findutils gawk pngquant jpegoptim libwebp-tools imagemagick
```

Verifikasi:

```bash
command -v pngquant jpegoptim cwebp && { command -v magick || command -v convert; }
```

</details>

## 🛠️ Penggunaan

```text
./compress-img.sh [-q min-max] [-j quality] [-w quality] [-m MB] [-r] [-k] [-d] [folder ...]
```

Tanpa argumen folder → memproses direktori saat ini.

| Opsi | Keterangan | Default |
|---|---|---|
| `-q min-max` | Rentang kualitas `pngquant` untuk PNG, mis. `70-90` | `85-95` |
| `-j quality` | Kualitas `jpegoptim` untuk JPG/JPEG, `1–100` | `85` |
| `-w quality` | Kualitas `cwebp` untuk WebP, `1–100` | `85` |
| `-m MB` | Batas ukuran per file dalam MB (desimal boleh, mis. `1.5`); `0` menonaktifkan batas | `2` |
| `-r` | Rekursif: proses setiap subfolder yang berisi gambar | mati |
| `-k` | Simpan file asli — jangan pernah hapus file sumber | mati |
| `-d` | Hapus file asli setelah sukses (sudah default; dipertahankan untuk kompatibilitas) | — |
| `-h` | Tampilkan bantuan | — |

> [!IMPORTANT]
> **File asli dihapus secara default** setelah berhasil dikompres, tersimpan di `compressed/`, dan memenuhi batas `-m`. File yang gagal atau masih di atas batas **tidak pernah** dihapus. Gunakan `-k` untuk selalu menyimpan file aslimu.

Batas `-m` dihitung dalam MiB (`1 MB = 1024 × 1024 byte`). Secara internal, target JPG/WebP diset ke 95% dari batas sebagai margin aman.

## 💡 Contoh

```bash
# Folder saat ini, batas 2 MB
./compress-img.sh

# Beberapa folder sekaligus
./compress-img.sh ./photos ./banners ./icons

# Batas ketat 1,5 MB (mis. syarat upload)
./compress-img.sh -m 1.5 ./photos

# Kualitas awal lebih rendah agar file lebih kecil, file asli disimpan
./compress-img.sh -k -q 70-90 -j 80 -w 80 ./photos

# Seluruh pohon direktori, hapus file asli hanya bila target 1 MB tercapai
./compress-img.sh -m 1 -r ./assets

# Tanpa batas ukuran — hanya satu putaran kompresi kualitas
./compress-img.sh -m 0 ./photos
```

## ⚙️ Cara kerja

Untuk setiap file, script menjalankan serangkaian percobaan dan **berhenti segera setelah hasilnya memenuhi batas**:

1. **Kualitas awal** — kompres dengan pengaturan `-q` / `-j` / `-w` milikmu.
2. **Turunkan kualitas** — kualitas diturunkan bertahap (atau memakai mode target-size bawaan kompresor).
3. **Turunkan resolusi** — bila ImageMagick tersedia, coba `85% → 70% → 60% → 50% → 40% → 30% → 20%` dari dimensi asli.
4. **Ambil yang terbaik** — kandidat terkecil menang dan disimpan di `compressed/`. Bila tidak ada yang mengalahkan aslinya, file asli disalin apa adanya.

## 📁 Hasil

Setiap folder input mendapat subfolder `compressed/` sendiri — file sumber tidak pernah ditimpa di tempat:

```text
photos/
├── banner.png
├── logo.jpg
├── icon.webp
└── compressed/
    ├── banner.png
    ├── logo.jpg
    └── icon.webp
```

Dalam mode rekursif, folder bernama `compressed` dilewati secara otomatis.

## 🛡️ Keamanan & kode keluar

- File sumber dihapus **hanya** bila hasilnya tersimpan, tidak kosong, dan memenuhi batas `-m` yang aktif.
- Dengan `-m 0` (tanpa batas), setiap hasil tersimpan dianggap sukses — uji dulu dengan `-k`.
- **Keluar `0`** — semua file diproses dalam batas.
- **Keluar `2`** — ada file yang tetap di atas batas (dicantumkan di akhir; tidak dihapus).
- **Keluar `1`** — opsi tidak valid, atau tidak ada folder berisi gambar yang ditemukan.

## 📊 Contoh keluaran

```text
🗂️  Total folders to process: 1
   - ./photos
🎚️  Quality PNG  : 85-95
🎚️  Quality JPG  : 85
🎚️  Quality WebP : 85
🎯 Size limit per file: 2.0MB
🗑️  Delete original files: ENABLED (only successful files within the limit; use -k to disable)

──────────────────────────────────────────
📂 Input folder  : ./photos
📦 Output folder : ./photos/compressed
🔢 File count    : 3

✅ banner.png  3.2MB → 1.8MB (-44%) · quality lowered
✅ logo.jpg    4.1MB → 1.9MB (-54%)
✅ icon.webp   900KB → 420KB (-53%)

📊 Size before : 8.2MB
📊 Size after  : 4.1MB

════════════════════════════════════════
🎉 Done! Processed 1 folders in total.
📊 Total size before : 8.2MB
📊 Total size after  : 4.1MB
```

## 🤝 Kontribusi

Issue dan pull request sangat diterima. Script ini satu file mandiri — usahakan tetap ringan dan minim dependensi.

## 📄 Lisensi

Dirilis di bawah [Lisensi MIT](LICENSE).
