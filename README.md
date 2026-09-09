# compress-img.sh

Script Bash untuk kompres banyak gambar (**PNG, JPG/JPEG, WebP**) sekaligus, secara paralel (multi-core), mendukung banyak folder, mode rekursif, dan opsi hapus otomatis file asli setelah berhasil dikompres.

## ✨ Fitur

- Kompres **PNG**, **JPG/JPEG**, dan **WebP** dalam satu perintah
- Proses **paralel** memakai semua core CPU (`xargs -P$(nproc)`)
- Bisa proses **banyak folder sekaligus**
- Mode **rekursif** (`-r`) — otomatis cari semua subfolder yang berisi gambar
- Opsi **hapus file asli** (`-d`) setelah berhasil dikompres — jadi tidak perlu hapus manual satu-satu
- File asli **tidak akan terhapus** kalau kompresi gagal atau hasilnya tidak lebih kecil
- Hasil kompresi disimpan terpisah di subfolder `compressed/`, tidak menimpa file asli
- Ringkasan ukuran sebelum/sesudah kompresi per folder dan total keseluruhan

## 📦 Requirement

Script ini memanggil tool eksternal sesuai format gambar:

| Format | Tool | Install (Arch/Manjaro) |
|---|---|---|
| PNG | [`pngquant`](https://pngquant.org/) | `sudo pacman -S pngquant` |
| JPG/JPEG | [`jpegoptim`](https://github.com/tjko/jpegoptim) | `sudo pacman -S jpegoptim` |
| WebP | [`cwebp`](https://developers.google.com/speed/webp/docs/cwebp) (dari `libwebp`) | `sudo pacman -S libwebp` |

Install ketiganya sekaligus:

```bash
sudo pacman -S pngquant jpegoptim libwebp
```

> Untuk distro lain, ganti dengan package manager masing-masing (`apt`, `dnf`, `brew`, dll). Nama paketnya biasanya sama.

Kalau salah satu tool belum terinstall, script **tetap jalan** — hanya file dengan format terkait yang akan dilewati, dan akan muncul peringatan di awal.

## 🚀 Instalasi

1. Clone atau download repo ini
2. Beri izin eksekusi:

```bash
chmod +x compress-img.sh
```

3. (Opsional) Pindahkan ke folder yang ada di `$PATH` supaya bisa dipanggil dari mana saja:

```bash
sudo mv compress-img.sh /usr/local/bin/compress-img
```

## 🛠️ Cara Pakai

```bash
./compress-img.sh [-q min-max] [-j quality] [-w quality] [-r] [-d] [folder1 folder2 ...]
```

### Opsi

| Opsi | Deskripsi | Default |
|---|---|---|
| `-q min-max` | Quality `pngquant` untuk PNG | `85-95` |
| `-j quality` | Quality `jpegoptim` untuk JPG/JPEG (0–100) | `85` |
| `-w quality` | Quality `cwebp` untuk WebP (0–100) | `85` |
| `-r` | Mode rekursif — proses semua subfolder yang berisi gambar | nonaktif |
| `-d` | Hapus file asli setelah berhasil dikompres | nonaktif |

Kalau tidak ada folder yang diberikan, script memproses folder saat ini (`.`).

### Contoh

```bash
# Folder saat ini, semua format, quality default
./compress-img.sh

# Satu folder
./compress-img.sh ./foto

# Banyak folder sekaligus
./compress-img.sh ./foto ./banner ./icon

# Custom quality tiap format
./compress-img.sh -q 70-90 -j 80 -w 80 ./foto

# Mode rekursif — semua subfolder di dalam ./assets ikut diproses
./compress-img.sh -r ./assets

# Kompres lalu langsung hapus file asli (biar tidak hapus manual)
./compress-img.sh -d ./foto

# Kombinasi lengkap: rekursif + custom quality + hapus asli
./compress-img.sh -q 70-90 -j 80 -w 80 -r -d ./assets
```

## 📁 Struktur Output

Hasil kompresi disimpan di subfolder `compressed/` di dalam folder input, dengan nama file yang sama:

```
foto/
├── banner.png
├── logo.jpg
├── icon.webp
└── compressed/
    ├── banner.png
    ├── logo.jpg
    └── icon.webp
```

Kalau opsi `-d` dipakai, file asli (`foto/banner.png`, dst.) akan dihapus **setelah** versi terkompresinya berhasil tersimpan di `compressed/`.

## ⚠️ Catatan Keamanan

- File asli **hanya dihapus** ketika `-d` diaktifkan **dan** proses kompresi untuk file tersebut sukses.
- Jika kompresi gagal (tool tidak ada, file korup, dll.) atau hasil kompresi tidak lebih kecil dari aslinya, file asli **tidak** akan dihapus.
- Disarankan untuk mencoba dulu **tanpa** `-d` pada satu folder kecil untuk memastikan hasil kompresinya sesuai harapan, sebelum menjalankan `-d` secara massal di banyak folder.

## 📊 Contoh Output

```
🗂️  Total folder yang akan diproses: 1
   - ./foto
🎚️  Quality PNG  : 85-95
🎚️  Quality JPG  : 85
🎚️  Quality WebP : 85
🗑️  Mode hapus asli: AKTIF (file asli akan dihapus setelah sukses dikompres)

──────────────────────────────────────────
📂 Folder input   : ./foto
📦 Folder output  : ./foto/compressed
🔢 Jumlah file     : 12

✅ banner.png
✅ logo.jpg
✅ icon.webp
...

📊 Ukuran sebelum : 24M
📊 Ukuran sesudah : 9.1M

════════════════════════════════════════
🎉 Selesai! Total 1 folder diproses.
📊 Total ukuran sebelum : 24M
📊 Total ukuran sesudah : 9.1M
```

## 📄 Lisensi

Bebas digunakan dan dimodifikasi sesuai kebutuhan.
ya bebas, sesuai deskripsi
kita lanjut ke tahap berikutnya
