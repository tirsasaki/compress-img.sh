# compress-img.sh

A Bash script for compressing **PNG, JPG/JPEG, and WebP** images in parallel. It tries to bring every file below a configurable size limit (**2 MB** by default) and never saves a result larger than the original.

[Versi Bahasa Indonesia](README.md)

## ✨ Features

- Processes PNG, JPG/JPEG, and WebP in one command
- Targets a maximum per-file size with the `-m` option
- Progressively lowers quality and, when needed, resolution until the size limit is met
- Keeps the smallest attempted result; if none is smaller, copies the original unchanged
- Processes files in parallel using all available CPU cores
- Supports multiple folders and recursive subfolder discovery
- Writes results to a separate `compressed/` subfolder without overwriting source files
- Can delete a source file only after its output is saved and meets the active size limit
- Reports size statistics per file, per folder, and for the full run

## 📦 Requirements

The script targets GNU/Linux environments with Bash and standard utilities such as `find`, `xargs`, `awk`, `stat`, `numfmt`, and `nproc`.

Install the compression tool for every format you want to process:

| Format | Tool | Arch/Manjaro package |
|---|---|---|
| PNG | [`pngquant`](https://pngquant.org/) | `pngquant` |
| JPG/JPEG | [`jpegoptim`](https://github.com/tjko/jpegoptim) | `jpegoptim` |
| WebP | [`cwebp`](https://developers.google.com/speed/webp/docs/cwebp) | `libwebp` |

Install all three on Arch/Manjaro:

```bash
sudo pacman -S pngquant jpegoptim libwebp
```

If a tool is unavailable, the script continues but skips files in the corresponding format.

### ImageMagick (optional, recommended)

[`ImageMagick`](https://imagemagick.org/) is used as a final fallback to reduce image dimensions when lowering quality is not enough to reach the `-m` limit.

```bash
sudo pacman -S imagemagick
```

Without ImageMagick, a file that remains above the limit after quality reduction is still written to `compressed/`, reported as not meeting the limit, and retained at its source location. The script supports both the `magick` and legacy `convert` commands.

On other distributions, use the appropriate package manager and package names.

## 🚀 Installation

```bash
git clone https://github.com/tirsasaki/compress-img.sh.git
cd compress-img.sh
chmod +x compress-img.sh
```

Optionally, install it in a directory on your `$PATH`:

```bash
sudo install -m 755 compress-img.sh /usr/local/bin/compress-img
```

## 🛠️ Usage

```text
./compress-img.sh [-q min-max] [-j quality] [-w quality] [-m MB] [-r] [-d] [folder ...]
```

When no folder is given, the script processes the current directory (`.`).

### Options

| Option | Description | Default |
|---|---|---|
| `-q min-max` | Initial `pngquant` quality range for PNG | `85-95` |
| `-j quality` | Initial `jpegoptim` quality for JPG/JPEG, `1-100` | `85` |
| `-w quality` | Initial `cwebp` quality for WebP, `1-100` | `85` |
| `-m MB` | Maximum size per file in MB; decimals are allowed, use `0` to disable the limit | `2` |
| `-r` | Find every subfolder containing images; `compressed/` subfolders are skipped | off |
| `-d` | Delete a source file after its output is saved and meets the active size limit | off |
| `-h` | Show help | — |

The `-m` value is calculated as MiB (`1 MB = 1024 × 1024 bytes`). With an active limit, the internal JPG/JPEG and WebP target is set to 95% of that limit to leave a small margin.

### Examples

```bash
# Current directory, default 2 MB limit per file
./compress-img.sh

# Multiple directories at once
./compress-img.sh ./photos ./banners ./icons

# Maximum 1.5 MB per file
./compress-img.sh -m 1.5 ./photos

# Custom initial quality for every format
./compress-img.sh -q 70-90 -j 80 -w 80 ./photos

# Every subfolder inside ./assets
./compress-img.sh -r ./assets

# Recurse and delete sources that successfully meet a 1 MB limit
./compress-img.sh -m 1 -r -d ./assets

# Disable the size limit; only perform the initial quality pass
./compress-img.sh -m 0 ./photos
```

## ⚙️ How it works

For each file, the script:

1. tries compression at the quality supplied through `-q`, `-j`, or `-w`;
2. if the result is still above `-m`, progressively lowers quality or uses the compressor's target-size mode;
3. if the result is still too large and ImageMagick is available, tries resolution scales of `85%`, `70%`, `60%`, `50%`, `40%`, `30%`, and `20%`;
4. saves the smallest candidate to `compressed/`, or copies the original when no candidate is smaller.

Processing stops early as soon as the best candidate meets the limit. With `-m 0`, additional quality reduction and resizing are skipped.

## 📁 Output structure

Each input directory gets its own `compressed/` subfolder:

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

An existing file with the same name in `compressed/` is replaced. In recursive mode, directories named `compressed` and their contents are not processed again.

## ⚠️ Deletion and exit status

- Without `-d`, source files are always retained.
- With `-d`, a source file is deleted only when a non-empty output has been saved and does not exceed the active `-m` limit.
- Files that do not meet the limit are never deleted and are listed in the failure summary.
- With `-m 0`, there is no size limit to meet, so `-d` removes the source after the output is saved—even when the file was copied unchanged because it was already optimal.
- The script exits with status `2` if any file remains above the limit, and status `1` for invalid input/options or when no directory containing images is found.

Test on a small directory without `-d` before deleting many source files.

## 📊 Example output

The script's runtime messages are currently in Indonesian:

```text
🗂️  Total folder yang akan diproses: 1
   - ./photos
🎚️  Quality PNG  : 85-95
🎚️  Quality JPG  : 85
🎚️  Quality WebP : 85
🎯 Batas ukuran per file: 2.0MB

──────────────────────────────────────────
📂 Folder input  : ./photos
📦 Folder output : ./photos/compressed
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

## 📄 License

Free to use and modify as needed.
