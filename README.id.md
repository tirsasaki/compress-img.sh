# compress-img.sh

Script Bash untuk mengompres banyak gambar **PNG, JPG/JPEG, dan WebP** secara paralel. Setiap file diusahakan berada di bawah batas ukuran yang ditentukan (default **2 MB**) tanpa pernah menyimpan hasil yang lebih besar daripada file asli.

[English version](README.md)

## ✨ Fitur

- Memproses PNG, JPG/JPEG, dan WebP dalam satu perintah
- Menargetkan ukuran maksimum per file melalui opsi `-m`
- Menurunkan kualitas dan, jika perlu, resolusi secara bertahap sampai batas ukuran tercapai
- Memilih hasil terkecil dari seluruh percobaan; jika tidak ada hasil yang lebih kecil, file asli disalin apa adanya
- Memproses file secara paralel menggunakan semua core CPU yang tersedia
- Mendukung banyak folder dan pencarian subfolder secara rekursif
- Menyimpan hasil di subfolder `compressed/` tanpa menimpa file sumber
- Dapat menghapus file sumber hanya setelah output berhasil dibuat dan memenuhi batas ukuran yang aktif
- Menampilkan statistik ukuran per file, per folder, dan keseluruhan

## 📦 Persyaratan

Script ini tidak bergantung pada distribusi tertentu dan dapat berjalan di sistem Linux apa pun yang menyediakan perintah yang dibutuhkan. Script tidak terikat pada package manager tertentu.

### Perintah runtime

- Bash 4 atau lebih baru
- GNU Coreutils: `stat`, `numfmt`, `nproc`, dan `mktemp`
- GNU Findutils: `find` dan `xargs`
- Implementasi `awk`

Distribusi minimal dan container mungkin mengharuskan utilitas ini dipasang secara eksplisit. Pada sebagian besar distribusi desktop dan server, utilitas tersebut sudah tersedia.

### Perintah kompresi gambar

Pasang kompresor untuk setiap format yang ingin diproses:

| Format | Perintah wajib | Proyek |
|---|---|---|
| PNG | `pngquant` | [`pngquant`](https://pngquant.org/) |
| JPG/JPEG | `jpegoptim` | [`jpegoptim`](https://github.com/tjko/jpegoptim) |
| WebP | `cwebp` | [`libwebp`](https://developers.google.com/speed/webp/docs/cwebp) |

Jika kompresor tidak tersedia, script tetap berjalan tetapi melewati file dengan format terkait.

[`ImageMagick`](https://imagemagick.org/) bersifat opsional tetapi direkomendasikan. Perintah `magick` atau `convert` versi lama digunakan sebagai langkah terakhir untuk memperkecil resolusi apabila penurunan kualitas belum mencapai batas `-m`. Tanpa ImageMagick, file yang masih melampaui batas dipertahankan di lokasi sumber dan dilaporkan tidak memenuhi batas.

### Nama paket berdasarkan distribusi

Nama paket berbeda antar-keluarga distribusi:

| Keluarga distribusi | PNG | JPG/JPEG | Tool WebP | Fallback resize |
|---|---|---|---|---|
| Debian, Ubuntu, Linux Mint, Pop!_OS | `pngquant` | `jpegoptim` | `webp` | `imagemagick` |
| Fedora, RHEL, Rocky Linux, AlmaLinux | `pngquant` | `jpegoptim` | `libwebp-tools` | `ImageMagick` |
| Arch Linux, Manjaro, EndeavourOS | `pngquant` | `jpegoptim` | `libwebp` | `imagemagick` |
| openSUSE | `pngquant` | `jpegoptim` | `libwebp-tools` | `ImageMagick` |
| Alpine Linux | `pngquant` | `jpegoptim` | `libwebp-tools` | `imagemagick` |

Pasang semua kompresor dan fallback resize yang direkomendasikan dengan perintah untuk distribusi Anda:

```bash
# Debian / Ubuntu dan turunannya
sudo apt update
sudo apt install bash coreutils findutils gawk pngquant jpegoptim webp imagemagick

# Fedora, atau RHEL/Rocky/Alma setelah mengaktifkan repository yang diperlukan
sudo dnf install bash coreutils findutils gawk pngquant jpegoptim libwebp-tools ImageMagick

# Arch Linux / Manjaro dan turunannya
sudo pacman -S bash coreutils findutils gawk pngquant jpegoptim libwebp imagemagick

# openSUSE
sudo zypper install bash coreutils findutils gawk pngquant jpegoptim libwebp-tools ImageMagick

# Alpine Linux (aktifkan repository community jika ada paket yang tidak tersedia)
sudo apk add bash coreutils findutils gawk pngquant jpegoptim libwebp-tools imagemagick
```

Pada RHEL dan distribusi enterprise yang kompatibel, `pngquant` atau `jpegoptim` mungkin memerlukan repository tambahan seperti EPEL. Pada openSUSE Leap, beberapa tool gambar mungkin memerlukan repository graphics. Ketersediaan paket dapat berbeda menurut versi distribusi.

Untuk distribusi lain yang tidak tercantum, gunakan pencarian paketnya untuk menemukan paket yang menyediakan `pngquant`, `jpegoptim`, dan `cwebp`. Script memeriksa ketersediaan perintah, bukan nama distribusi, sehingga build dari source dan package manager alternatif juga dapat digunakan.

Verifikasi instalasi:

```bash
command -v bash find xargs awk stat numfmt nproc
command -v pngquant jpegoptim cwebp
command -v magick || command -v convert  # fallback resize opsional
```

## 🚀 Instalasi

```bash
git clone https://github.com/tirsasaki/compress-img.sh.git
cd compress-img.sh
chmod +x compress-img.sh
```

Opsional, pasang ke direktori yang ada di `$PATH`:

```bash
sudo install -m 755 compress-img.sh /usr/local/bin/compress-img
```

## 🛠️ Cara pakai

```text
./compress-img.sh [-q min-max] [-j quality] [-w quality] [-m MB] [-r] [-d] [folder ...]
```

Jika tidak ada folder yang diberikan, script memproses folder saat ini (`.`).

### Opsi

| Opsi | Deskripsi | Default |
|---|---|---|
| `-q min-max` | Rentang kualitas awal `pngquant` untuk PNG | `85-95` |
| `-j quality` | Kualitas awal `jpegoptim` untuk JPG/JPEG, `1-100` | `85` |
| `-w quality` | Kualitas awal `cwebp` untuk WebP, `1-100` | `85` |
| `-m MB` | Batas ukuran maksimum tiap file dalam MB; boleh desimal, gunakan `0` untuk menonaktifkan batas | `2` |
| `-r` | Cari semua subfolder yang berisi gambar; subfolder `compressed/` dilewati | nonaktif |
| `-d` | Hapus file sumber setelah output tersimpan dan memenuhi batas ukuran yang aktif | nonaktif |
| `-h` | Tampilkan bantuan | — |

Nilai `-m` dihitung sebagai MiB (`1 MB = 1024 × 1024 byte`). Saat batas aktif, target internal JPG/JPEG dan WebP dibuat sebesar 95% dari batas untuk memberi sedikit margin.

### Contoh

```bash
# Folder saat ini, batas default 2 MB per file
./compress-img.sh

# Banyak folder sekaligus
./compress-img.sh ./foto ./banner ./icon

# Batas maksimum 1,5 MB per file
./compress-img.sh -m 1.5 ./foto

# Kualitas awal khusus untuk setiap format
./compress-img.sh -q 70-90 -j 80 -w 80 ./foto

# Semua subfolder di dalam ./assets
./compress-img.sh -r ./assets

# Rekursif dan hapus sumber yang berhasil memenuhi batas 1 MB
./compress-img.sh -m 1 -r -d ./assets

# Nonaktifkan batas ukuran; hanya lakukan kompresi kualitas awal
./compress-img.sh -m 0 ./foto
```

## ⚙️ Cara kerja

Untuk setiap file, script:

1. mencoba kompresi dengan kualitas yang diberikan melalui `-q`, `-j`, atau `-w`;
2. jika masih di atas `-m`, menurunkan kualitas secara bertahap atau memakai mode target-size;
3. jika masih terlalu besar dan ImageMagick tersedia, mencoba skala resolusi `85%`, `70%`, `60%`, `50%`, `40%`, `30%`, lalu `20%`;
4. menyimpan kandidat terkecil ke `compressed/`, atau menyalin file asli apabila tidak ada kandidat yang lebih kecil.

Pemrosesan berhenti lebih awal segera setelah kandidat terbaik sudah memenuhi batas. Dengan `-m 0`, tahap penurunan kualitas lanjutan dan resize tidak dijalankan.

## 📁 Struktur output

Setiap folder input memperoleh subfolder `compressed/` sendiri:

```text
foto/
├── banner.png
├── logo.jpg
├── icon.webp
└── compressed/
    ├── banner.png
    ├── logo.jpg
    └── icon.webp
```

File yang sudah ada dengan nama sama di `compressed/` akan diganti. Dalam mode rekursif, direktori bernama `compressed` beserta isinya tidak diproses kembali.

## ⚠️ Penghapusan file dan status keluar

- Tanpa `-d`, file sumber selalu dipertahankan.
- Dengan `-d`, file sumber hanya dihapus jika output nonkosong sudah tersimpan dan tidak melebihi batas `-m` yang aktif.
- File yang tidak mencapai batas tidak pernah dihapus dan dicantumkan dalam ringkasan kegagalan.
- Dengan `-m 0`, tidak ada batas ukuran yang harus dipenuhi; karena itu `-d` akan menghapus sumber setelah output berhasil disimpan, termasuk ketika file disalin apa adanya karena sudah optimal.
- Script keluar dengan status `2` jika ada file yang masih di atas batas, dan status `1` untuk input/opsi tidak valid atau ketika tidak ada folder berisi gambar yang ditemukan.

Sebaiknya uji tanpa `-d` pada folder kecil sebelum menghapus banyak file sumber.

## 📊 Contoh output

```text
🗂️  Total folder yang akan diproses: 1
   - ./foto
🎚️  Quality PNG  : 85-95
🎚️  Quality JPG  : 85
🎚️  Quality WebP : 85
🎯 Batas ukuran per file: 2.0MB

──────────────────────────────────────────
📂 Folder input  : ./foto
📦 Folder output : ./foto/compressed
🔢 Jumlah file   : 3

✅ banner.png  3.2MB → 1.8MB (-44%) · kualitas diturunkan
✅ logo.jpg  4.1MB → 1.9MB (-54%)
✅ icon.webp  900KB → 420KB (-53%)

📊 Ukuran sebelum : 8.2MB
📊 Ukuran sesudah : 4.1MB

════════════════════════════════════════
🎉 Selesai! Total 1 folder diproses.
📊 Total ukuran sebelum : 8.2MB
📊 Total ukuran sesudah : 4.1MB
```

## 📄 Lisensi

Bebas digunakan dan dimodifikasi sesuai kebutuhan.
