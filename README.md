# compress-img.sh

A Bash script for compressing **PNG, JPG/JPEG, and WebP** images in parallel. It tries to bring every file below a configurable size limit (**2 MB** by default) and never saves a result larger than the original.

[Versi Bahasa Indonesia](README.id.md)

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

The script is distribution-independent and works on any Linux system that provides the required commands. It does not depend on a specific package manager.

### Runtime commands

- Bash 4 or newer
- GNU Coreutils: `stat`, `numfmt`, `nproc`, and `mktemp`
- GNU Findutils: `find` and `xargs`
- An `awk` implementation

Minimal distributions and containers may require these utilities to be installed explicitly. On most desktop and server distributions they are already available.

### Image compression commands

Install the compressor for every format you want to process:

| Format | Required command | Project |
|---|---|---|
| PNG | `pngquant` | [`pngquant`](https://pngquant.org/) |
| JPG/JPEG | `jpegoptim` | [`jpegoptim`](https://github.com/tjko/jpegoptim) |
| WebP | `cwebp` | [`libwebp`](https://developers.google.com/speed/webp/docs/cwebp) |

If a compressor is unavailable, the script continues but skips files in the corresponding format.

[`ImageMagick`](https://imagemagick.org/) is optional but recommended. Its `magick` or legacy `convert` command is used as a final fallback to reduce image dimensions when lowering quality is not enough to reach the `-m` limit. Without it, files that remain above the limit are retained at their source location and reported as not meeting the limit.

### Package names by distribution

Package names differ between distribution families:

| Distribution family | PNG | JPG/JPEG | WebP tools | Resize fallback |
|---|---|---|---|---|
| Debian, Ubuntu, Linux Mint, Pop!_OS | `pngquant` | `jpegoptim` | `webp` | `imagemagick` |
| Fedora, RHEL, Rocky Linux, AlmaLinux | `pngquant` | `jpegoptim` | `libwebp-tools` | `ImageMagick` |
| Arch Linux, Manjaro, EndeavourOS | `pngquant` | `jpegoptim` | `libwebp` | `imagemagick` |
| openSUSE | `pngquant` | `jpegoptim` | `libwebp-tools` | `ImageMagick` |
| Alpine Linux | `pngquant` | `jpegoptim` | `libwebp-tools` | `imagemagick` |

Install all compressors and the recommended resize fallback with the command for your distribution:

```bash
# Debian / Ubuntu and derivatives
sudo apt update
sudo apt install bash coreutils findutils gawk pngquant jpegoptim webp imagemagick

# Fedora, or RHEL/Rocky/Alma after enabling the required repositories
sudo dnf install bash coreutils findutils gawk pngquant jpegoptim libwebp-tools ImageMagick

# Arch Linux / Manjaro and derivatives
sudo pacman -S bash coreutils findutils gawk pngquant jpegoptim libwebp imagemagick

# openSUSE
sudo zypper install bash coreutils findutils gawk pngquant jpegoptim libwebp-tools ImageMagick

# Alpine Linux (enable the community repository if a package is unavailable)
sudo apk add bash coreutils findutils gawk pngquant jpegoptim libwebp-tools imagemagick
```

On RHEL and compatible enterprise distributions, `pngquant` or `jpegoptim` may require an additional repository such as EPEL. On openSUSE Leap, some image tools may require the graphics repository. Package availability can differ by release.

For any distribution not listed above, use its package search to find packages that provide `pngquant`, `jpegoptim`, and `cwebp`. The script checks command availability rather than the distribution name, so source builds and alternative package managers work as well.

Verify the installation:

```bash
command -v bash find xargs awk stat numfmt nproc
command -v pngquant jpegoptim cwebp
command -v magick || command -v convert  # optional resize fallback
```

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
