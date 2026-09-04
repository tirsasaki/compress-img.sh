#!/usr/bin/env bash
#
# compress-img.sh — Kompres banyak gambar (PNG, JPG/JPEG, WebP) paralel, multi-core
# Mendukung BANYAK FOLDER sekaligus, mode rekursif, dan hapus otomatis file asli.
#
# Tool yang dipakai per format:
#   PNG        -> pngquant
#   JPG/JPEG   -> jpegoptim
#   WebP       -> cwebp
#
# Cara pakai:
#   ./compress-img.sh [-q min-max] [-j quality] [-w quality] [-r] [-d] [folder1 folder2 ...]
#
# Opsi:
#   -q min-max   Quality pngquant untuk PNG (default: 85-95)
#   -j quality   Quality jpegoptim untuk JPG/JPEG, 0-100 (default: 85)
#   -w quality   Quality cwebp untuk WebP, 0-100 (default: 85)
#   -r           Mode rekursif: setiap argumen folder dianggap folder ROOT,
#                lalu semua subfolder yang berisi gambar ikut diproses.
#   -d           Hapus file asli setelah berhasil dikompres (hanya yang
#                berhasil dan tersimpan di folder compressed/ yang dihapus).
#
# Contoh:
#   ./compress-img.sh                              # folder saat ini, semua format
#   ./compress-img.sh ./foto                       # satu folder
#   ./compress-img.sh ./foto ./banner ./icon       # banyak folder sekaligus
#   ./compress-img.sh -q 70-90 -j 80 -w 80 ./foto  # custom quality tiap format
#   ./compress-img.sh -r ./assets                  # semua subfolder di dalam ./assets
#   ./compress-img.sh -d ./foto                    # kompres lalu hapus file asli
#   ./compress-img.sh -r -d ./assets               # rekursif + hapus file asli
#
# Hasil kompresi tiap folder disimpan di: <folder>/compressed/

set -euo pipefail

PNG_QUALITY="85-95"
JPG_QUALITY="85"
WEBP_QUALITY="85"
RECURSIVE=0
DELETE_ORIGINAL=0

# --- Parse opsi ---
while getopts ":q:j:w:rd" opt; do
  case "$opt" in
    q) PNG_QUALITY="$OPTARG" ;;
    j) JPG_QUALITY="$OPTARG" ;;
    w) WEBP_QUALITY="$OPTARG" ;;
    r) RECURSIVE=1 ;;
    d) DELETE_ORIGINAL=1 ;;
    \?) echo "❌ Opsi tidak dikenal: -$OPTARG" >&2; exit 1 ;;
    :) echo "❌ Opsi -$OPTARG butuh argumen." >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

# --- Ekstensi yang didukung ---
EXTS=(png PNG jpg JPG jpeg JPEG webp WEBP)

# --- Cek dependency (hanya warning di awal, dicek lagi per-file saat dipakai) ---
MISSING_TOOLS=()
command -v pngquant  &> /dev/null || MISSING_TOOLS+=("pngquant (untuk PNG)")
command -v jpegoptim  &> /dev/null || MISSING_TOOLS+=("jpegoptim (untuk JPG/JPEG)")
command -v cwebp      &> /dev/null || MISSING_TOOLS+=("cwebp (untuk WebP, biasanya dari paket libwebp)")

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  echo "⚠️  Tool berikut belum terinstall — file dengan format terkait akan DILEWATI:"
  printf '   - %s\n' "${MISSING_TOOLS[@]}"
  echo "   Install misalnya dengan: sudo pacman -S pngquant jpegoptim libwebp"
  echo ""
fi

# --- Kumpulkan daftar folder yang akan diproses ---
ROOTS=("${@:-.}")   # kalau tidak ada argumen, pakai folder saat ini
TARGET_DIRS=()

folder_has_image() {
  local d="$1" ext
  for ext in "${EXTS[@]}"; do
    compgen -G "$d"/*."$ext" > /dev/null 2>&1 && return 0
  done
  return 1
}

if [ "$RECURSIVE" -eq 1 ]; then
  for root in "${ROOTS[@]}"; do
    if [ ! -d "$root" ]; then
      echo "⚠️  Folder tidak ditemukan, dilewati: $root"
      continue
    fi
    while IFS= read -r -d '' dir; do
      TARGET_DIRS+=("$dir")
    done < <(find "$root" -type d -not -path '*/compressed*' -print0 | \
      while IFS= read -r -d '' d; do
        if folder_has_image "$d"; then
          printf '%s\0' "$d"
        fi
      done)
  done
else
  TARGET_DIRS=("${ROOTS[@]}")
fi

if [ ${#TARGET_DIRS[@]} -eq 0 ]; then
  echo "❌ Tidak ada folder dengan gambar (PNG/JPG/JPEG/WebP) yang ditemukan."
  exit 1
fi

echo "🗂️  Total folder yang akan diproses: ${#TARGET_DIRS[@]}"
printf '   - %s\n' "${TARGET_DIRS[@]}"
echo "🎚️  Quality PNG  : $PNG_QUALITY"
echo "🎚️  Quality JPG  : $JPG_QUALITY"
echo "🎚️  Quality WebP : $WEBP_QUALITY"
if [ "$DELETE_ORIGINAL" -eq 1 ]; then
  echo "🗑️  Mode hapus asli: AKTIF (file asli akan dihapus setelah sukses dikompres)"
fi
echo ""

TOTAL_BEFORE=0
TOTAL_AFTER=0

# --- Fungsi kompres satu folder ---
compress_one_folder() {
  local INPUT_DIR="$1"
  local OUTPUT_DIR="$INPUT_DIR/compressed"

  shopt -s nullglob
  local img_files=()
  local ext
  for ext in "${EXTS[@]}"; do
    img_files+=("$INPUT_DIR"/*."$ext")
  done

  if [ ${#img_files[@]} -eq 0 ]; then
    echo "⏭️  Lewati (tidak ada gambar): $INPUT_DIR"
    return
  fi

  mkdir -p "$OUTPUT_DIR"

  echo "──────────────────────────────────────────"
  echo "📂 Folder input   : $INPUT_DIR"
  echo "📦 Folder output  : $OUTPUT_DIR"
  echo "🔢 Jumlah file     : ${#img_files[@]}"
  echo ""

  local SIZE_BEFORE_BYTES
  SIZE_BEFORE_BYTES=$(du -cb "${img_files[@]}" 2>/dev/null | tail -1 | cut -f1)

  printf '%s\0' "${img_files[@]}" | xargs -0 -P"$(nproc)" -I{} bash -c '
    f="{}"
    name=$(basename "$f")
    ext="${name##*.}"
    ext_lower=$(echo "$ext" | tr "[:upper:]" "[:lower:]")
    ok=1

    case "$ext_lower" in
      png)
        if command -v pngquant &> /dev/null; then
          pngquant --quality='"$PNG_QUALITY"' --skip-if-larger --force \
            --output "'"$OUTPUT_DIR"'/$name" "$f" 2>/dev/null || ok=0
        else
          ok=0
        fi
        ;;
      jpg|jpeg)
        if command -v jpegoptim &> /dev/null; then
          cp -f -- "$f" "'"$OUTPUT_DIR"'/$name" && \
          jpegoptim --max='"$JPG_QUALITY"' --strip-all --quiet \
            "'"$OUTPUT_DIR"'/$name" || ok=0
        else
          ok=0
        fi
        ;;
      webp)
        if command -v cwebp &> /dev/null; then
          cwebp -quiet -q '"$WEBP_QUALITY"' "$f" -o "'"$OUTPUT_DIR"'/$name" || ok=0
        else
          ok=0
        fi
        ;;
      *)
        ok=0
        ;;
    esac

    if [ "$ok" -eq 1 ] && [ -s "'"$OUTPUT_DIR"'/$name" ]; then
      echo "✅ $name"
      if [ "'"$DELETE_ORIGINAL"'" -eq 1 ]; then
        rm -f -- "$f"
      fi
    else
      echo "⚠️  $name (dilewati — gagal/tool tidak ada/tidak lebih kecil, file asli TIDAK dihapus)"
      rm -f -- "'"$OUTPUT_DIR"'/$name" 2>/dev/null
    fi
  '

  local SIZE_AFTER_BYTES=0
  shopt -s nullglob
  local out_files=()
  for ext in "${EXTS[@]}"; do
    out_files+=("$OUTPUT_DIR"/*."$ext")
  done
  if [ ${#out_files[@]} -gt 0 ]; then
    SIZE_AFTER_BYTES=$(du -cb "${out_files[@]}" 2>/dev/null | tail -1 | cut -f1)
  fi

  echo ""
  echo "📊 Ukuran sebelum : $(numfmt --to=iec "$SIZE_BEFORE_BYTES" 2>/dev/null || echo "$SIZE_BEFORE_BYTES bytes")"
  echo "📊 Ukuran sesudah : $(numfmt --to=iec "$SIZE_AFTER_BYTES" 2>/dev/null || echo "$SIZE_AFTER_BYTES bytes")"
  echo ""

  TOTAL_BEFORE=$((TOTAL_BEFORE + SIZE_BEFORE_BYTES))
  TOTAL_AFTER=$((TOTAL_AFTER + SIZE_AFTER_BYTES))
}

# --- Proses semua folder satu per satu (tiap folder tetap kompres file secara paralel) ---
for dir in "${TARGET_DIRS[@]}"; do
  compress_one_folder "$dir"
done

echo "════════════════════════════════════════"
echo "🎉 Selesai! Total ${#TARGET_DIRS[@]} folder diproses."
echo "📊 Total ukuran sebelum : $(numfmt --to=iec "$TOTAL_BEFORE" 2>/dev/null || echo "$TOTAL_BEFORE bytes")"
echo "📊 Total ukuran sesudah : $(numfmt --to=iec "$TOTAL_AFTER" 2>/dev/null || echo "$TOTAL_AFTER bytes")"
