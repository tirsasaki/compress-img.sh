<h1 align="center">
  <img src="assets/logo.svg" alt="compress-img.sh" width="640">
</h1>

<p align="center">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-green">
  <img alt="Bash 4+" src="https://img.shields.io/badge/bash-4%2B-4EAA25?logo=gnubash&logoColor=white">
  <img alt="Platform: Linux" src="https://img.shields.io/badge/platform-linux-lightgrey?logo=linux&logoColor=white">
  <img alt="Formats: PNG, JPG, WebP" src="https://img.shields.io/badge/formats-PNG%20%7C%20JPG%20%7C%20WebP-blue">
</p>

<p align="center"><a href="README.id.md">🇮🇩 Bahasa Indonesia</a> · <b>English</b></p>

**compress-img.sh** squeezes every image in a folder below a size limit you choose (**2 MB** by default) — in parallel, across all your CPU cores — and never produces a file bigger than the original.

Drop a folder of screenshots, exports, or uploads on it; get a `compressed/` folder back with everything web-ready.

## ✨ Features

- **Target size per file** — keep going (lower quality → lower resolution) until each file fits under `-m`
- **Best of every attempt** — the smallest candidate always wins; files that can't shrink are copied unchanged
- **Parallel by default** — one worker per CPU core via `xargs -P`
- **PNG · JPG/JPEG · WebP** in a single run, each with its best-in-class compressor (`pngquant`, `jpegoptim`, `cwebp`)
- **Non-destructive by design** — originals are only removed after a verified, in-limit result is saved (opt out with `-k`)
- **Recursive mode** (`-r`) for whole directory trees; existing `compressed/` folders are never re-processed
- **Honest reporting** — per-file savings, per-folder totals, and a failure list for files that stayed over the limit

## ⚡ Quick start

```bash
git clone https://github.com/tirsasaki/compress-img.sh.git
cd compress-img.sh
chmod +x compress-img.sh

# install the compressors (Arch example)
sudo pacman -S pngquant jpegoptim libwebp imagemagick

# compress everything in ./photos → ./photos/compressed
./compress-img.sh ./photos
```

Want it on your `$PATH`?

```bash
sudo install -m 755 compress-img.sh /usr/local/bin/compress-img
```

## 📦 Requirements

| What | Why | Install (examples) |
|---|---|---|
| `bash` ≥ 4, `coreutils`, `findutils`, `awk` | script runtime | preinstalled on most distros |
| `pngquant` | PNG compression | `sudo pacman -S pngquant` / `sudo apt install pngquant` |
| `jpegoptim` | JPG/JPEG compression | `sudo pacman -S jpegoptim` / `sudo apt install jpegoptim` |
| `cwebp` (`libwebp`) | WebP compression | `sudo pacman -S libwebp` / `sudo apt install webp` |
| `imagemagick` *(optional, recommended)* | resolution-downscale fallback | `sudo pacman -S imagemagick` / `sudo apt install imagemagick` |

Missing a compressor? The script warns you and simply skips that format. Missing ImageMagick? Quality is still lowered, but the resolution fallback step is unavailable.

<details>
<summary><b>📋 Full install commands per distribution</b></summary>

```bash
# Debian / Ubuntu / Mint / Pop!_OS
sudo apt update && sudo apt install bash coreutils findutils gawk pngquant jpegoptim webp imagemagick

# Fedora / RHEL / Rocky / Alma (EPEL may be needed for pngquant/jpegoptim)
sudo dnf install bash coreutils findutils gawk pngquant jpegoptim libwebp-tools ImageMagick

# Arch / Manjaro / EndeavourOS / CachyOS
sudo pacman -S bash coreutils findutils gawk pngquant jpegoptim libwebp imagemagick

# openSUSE
sudo zypper install bash coreutils findutils gawk pngquant jpegoptim libwebp-tools ImageMagick

# Alpine (enable community repo if needed)
sudo apk add bash coreutils findutils gawk pngquant jpegoptim libwebp-tools imagemagick
```

Verify:

```bash
command -v pngquant jpegoptim cwebp && { command -v magick || command -v convert; }
```

</details>

## 🛠️ Usage

```text
./compress-img.sh [-q min-max] [-j quality] [-w quality] [-m MB] [-r] [-k] [-d] [folder ...]
```

No folder given → processes the current directory.

| Option | Description | Default |
|---|---|---|
| `-q min-max` | `pngquant` quality range for PNG, e.g. `70-90` | `85-95` |
| `-j quality` | `jpegoptim` quality for JPG/JPEG, `1–100` | `85` |
| `-w quality` | `cwebp` quality for WebP, `1–100` | `85` |
| `-m MB` | Max size per file in MB (decimals OK, e.g. `1.5`); `0` disables the limit | `2` |
| `-r` | Recurse: process every subfolder that contains images | off |
| `-k` | Keep originals — never delete source files | off |
| `-d` | Delete originals after success (already the default; kept for compatibility) | — |
| `-h` | Show help | — |

> [!IMPORTANT]
> **Originals are deleted by default** once a file is compressed, saved to `compressed/`, and within the `-m` limit. Files that fail or stay over the limit are **never** deleted. Pass `-k` to always keep your originals.

The `-m` limit is measured in MiB (`1 MB = 1024 × 1024 bytes`). Internally, JPG/WebP target 95% of the limit to leave a safety margin.

## 💡 Examples

```bash
# Current folder, 2 MB limit
./compress-img.sh

# Several folders at once
./compress-img.sh ./photos ./banners ./icons

# Strict 1.5 MB limit (e.g. upload constraints)
./compress-img.sh -m 1.5 ./photos

# Lower initial quality for smaller files, keep originals
./compress-img.sh -k -q 70-90 -j 80 -w 80 ./photos

# Whole tree, delete originals only where the 1 MB target was met
./compress-img.sh -m 1 -r ./assets

# No size limit — single quality pass only
./compress-img.sh -m 0 ./photos
```

## ⚙️ How it works

For every file, the script runs a ladder of attempts and **stops as soon as the result fits the limit**:

1. **Initial quality** — compress with your `-q` / `-j` / `-w` setting.
2. **Lower quality** — progressively reduce quality (or use the compressor's target-size mode).
3. **Lower resolution** — if ImageMagick is present, try `85% → 70% → 60% → 50% → 40% → 30% → 20%` of the original dimensions.
4. **Keep the best** — the smallest candidate wins and lands in `compressed/`. If nothing beat the original, the original is copied unchanged.

## 📁 Output

Each input folder gets its own `compressed/` subfolder — sources are never overwritten in place:

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

In recursive mode, folders named `compressed` are skipped automatically.

## 🛡️ Safety & exit codes

- A source file is deleted **only** when its output was saved, is non-empty, and meets the active `-m` limit.
- With `-m 0` (no limit), any saved output counts as success — test with `-k` first.
- **Exit `0`** — all files processed within the limit.
- **Exit `2`** — some files stayed over the limit (listed at the end; never deleted).
- **Exit `1`** — invalid options, or no folder containing images found.

## 📊 Sample run

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

> [!NOTE]
> Runtime messages are currently in Indonesian; the script logic and this README are language-independent.

## 🤝 Contributing

Issues and pull requests are welcome. The script is a single self-contained file — keep it dependency-light and POSIX-friendly where possible.

## 📄 License

Released under the [MIT License](LICENSE).
