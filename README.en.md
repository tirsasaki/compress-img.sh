# compress-img.sh

A Bash script to batch-compress images (**PNG, JPG/JPEG, WebP**) in parallel (multi-core), with support for multiple folders, recursive mode, and an option to automatically delete the original files after successful compression.

## ✨ Features

- Compress **PNG**, **JPG/JPEG**, and **WebP** in a single command
- **Parallel** processing using all CPU cores (`xargs -P$(nproc)`)
- Process **multiple folders at once**
- **Recursive mode** (`-r`) — automatically finds every subfolder that contains images
- Option to **delete the original files** (`-d`) after successful compression — no need to delete them manually one by one
- Original files are **never deleted** if compression fails or the result isn't smaller
- Compressed output is saved separately in a `compressed/` subfolder, never overwriting the originals
- Before/after size summary per folder and for the whole run

## 📦 Requirements

The script calls an external tool depending on the image format:

| Format | Tool | Install (Arch/Manjaro) |
|---|---|---|
| PNG | [`pngquant`](https://pngquant.org/) | `sudo pacman -S pngquant` |
| JPG/JPEG | [`jpegoptim`](https://github.com/tjko/jpegoptim) | `sudo pacman -S jpegoptim` |
| WebP | [`cwebp`](https://developers.google.com/speed/webp/docs/cwebp) (from `libwebp`) | `sudo pacman -S libwebp` |

Install all three at once:

```bash
sudo pacman -S pngquant jpegoptim libwebp
```

> For other distros, use your package manager instead (`apt`, `dnf`, `brew`, etc.). Package names are usually the same.

If one of the tools isn't installed, the script still runs — only files of that format will be skipped, with a warning shown at the start.

## 🚀 Installation

1. Clone or download this repo
2. Make it executable:

```bash
chmod +x compress-img.sh
```

3. (Optional) Move it into a folder that's on your `$PATH` so you can run it from anywhere:

```bash
sudo mv compress-img.sh /usr/local/bin/compress-img
```

## 🛠️ Usage

```bash
./compress-img.sh [-q min-max] [-j quality] [-w quality] [-r] [-d] [folder1 folder2 ...]
```

### Options

| Option | Description | Default |
|---|---|---|
| `-q min-max` | `pngquant` quality for PNG | `85-95` |
| `-j quality` | `jpegoptim` quality for JPG/JPEG (0–100) | `85` |
| `-w quality` | `cwebp` quality for WebP (0–100) | `85` |
| `-r` | Recursive mode — process every subfolder that contains images | off |
| `-d` | Delete original files after successful compression | off |

If no folder is given, the script processes the current folder (`.`).

### Examples

```bash
# Current folder, all formats, default quality
./compress-img.sh

# One folder
./compress-img.sh ./photos

# Multiple folders at once
./compress-img.sh ./photos ./banner ./icon

# Custom quality per format
./compress-img.sh -q 70-90 -j 80 -w 80 ./photos

# Recursive mode — every subfolder inside ./assets gets processed
./compress-img.sh -r ./assets

# Compress and immediately delete the originals (no manual cleanup)
./compress-img.sh -d ./photos

# Full combo: recursive + custom quality + delete originals
./compress-img.sh -q 70-90 -j 80 -w 80 -r -d ./assets
```

## 📁 Output Structure

Compressed output is saved in a `compressed/` subfolder inside the input folder, keeping the same file names:

```
photos/
├── banner.png
├── logo.jpg
├── icon.webp
└── compressed/
    ├── banner.png
    ├── logo.jpg
    └── icon.webp
```

When `-d` is used, the original file (`photos/banner.png`, etc.) is deleted **after** its compressed version has been successfully saved to `compressed/`.

## ⚠️ Safety Notes

- Original files are **only deleted** when `-d` is enabled **and** compression for that specific file succeeded.
- If compression fails (missing tool, corrupt file, etc.) or the result isn't smaller than the original, the original file is **not** deleted.
- It's recommended to first run **without** `-d` on a small test folder to confirm the compression results look right, before running `-d` on many folders at once.

## 📊 Example Output

```
🗂️  Total folders to process: 1
   - ./photos
🎚️  PNG quality  : 85-95
🎚️  JPG quality  : 85
🎚️  WebP quality : 85
🗑️  Delete-original mode: ON (originals will be removed after successful compression)

──────────────────────────────────────────
📂 Input folder   : ./photos
📦 Output folder  : ./photos/compressed
🔢 File count      : 12

✅ banner.png
✅ logo.jpg
✅ icon.webp
...

📊 Size before : 24M
📊 Size after  : 9.1M

════════════════════════════════════════
🎉 Done! Processed 1 folder(s) in total.
📊 Total size before : 24M
📊 Total size after  : 9.1M
```

## 📄 License

Free to use and modify as needed.
