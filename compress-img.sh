#!/usr/bin/env bash
#
# compress-img.sh — Compress multiple images (PNG, JPG/JPEG, WebP) in parallel
# across multiple CPU cores, with a MAXIMUM TARGET SIZE per file (default: 2 MB).
#
# Tools by format:
#   PNG        -> pngquant
#   JPG/JPEG   -> jpegoptim
#   WebP       -> cwebp (libwebp)
#   (optional) -> ImageMagick, used as a final step to reduce resolution
#
# Per-file workflow (stops as soon as the size is within the -m limit):
#   1. Compress using the specified quality (-q / -j / -w)
#   2. If still over the limit -> gradually lower quality / use target-size mode
#   3. If still over the limit -> gradually reduce resolution (requires ImageMagick)
#   The SMALLEST result from all attempts is always kept. If no result is smaller
#   than the original, the original file is copied unchanged to compressed/.
#
# ORIGINAL FILE DELETION (default: ENABLED):
#   After an image has been compressed successfully, saved to compressed/, and
#   reduced to within the -m limit, the original file is deleted automatically.
#   Failed files or files still over the limit are NEVER deleted.
#   Use -k to keep the original files.
#
# Usage:
#   ./compress-img.sh [-q min-max] [-j quality] [-w quality] [-m MB] [-r] [-k] [folder ...]
#
# Options:
#   -q min-max   pngquant quality for PNG files (default: 85-95)
#   -j quality   jpegoptim quality for JPG/JPEG files, 1-100 (default: 85)
#   -w quality   cwebp quality for WebP files, 1-100 (default: 85)
#   -m MB        Maximum size per file in MB; decimals are allowed (default: 2).
#                Use -m 0 to disable the size limit.
#   -r           Recursive: treat each argument as a ROOT folder and process every
#                subfolder that contains images.
#   -k           KEEP: do not delete original files (only create results in compressed/).
#   -d           Delete original files after successful compression (already the default;
#                retained for backward compatibility).
#   -h           Show this help message.
#
# Examples:
#   ./compress-img.sh                          # current folder
#   ./compress-img.sh ./photos ./banners       # multiple folders
#   ./compress-img.sh -m 1.5 ./photos          # 1.5 MB limit
#   ./compress-img.sh -r ./assets              # recursive; originals are deleted automatically
#   ./compress-img.sh -k ./photos              # compress only; keep original files
#
# Results for each folder are saved to: <folder>/compressed/

set -uo pipefail

PNG_QUALITY="85-95"
JPG_QUALITY="85"
WEBP_QUALITY="85"
MAX_MB="2"
RECURSIVE=0
# Setting: delete original files after successful compression? 1 = yes (default), 0 = no.
# Change it here permanently or per invocation with the -k / -d options.
DELETE_ORIGINAL=1

usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
}

# --- Parse options ---
while getopts ":q:j:w:m:rdkh" opt; do
  case "$opt" in
    q) PNG_QUALITY="$OPTARG" ;;
    j) JPG_QUALITY="$OPTARG" ;;
    w) WEBP_QUALITY="$OPTARG" ;;
    m) MAX_MB="$OPTARG" ;;
    r) RECURSIVE=1 ;;
    d) DELETE_ORIGINAL=1 ;;
    k) DELETE_ORIGINAL=0 ;;
    h) usage; exit 0 ;;
    \?) echo "❌ Unknown option: -$OPTARG" >&2; exit 1 ;;
    :)  echo "❌ Option -$OPTARG requires an argument." >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

# --- Validation ---
if ! [[ "$MAX_MB" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "❌ The -m value must be a number in MB, for example: 2 or 1.5" >&2; exit 1
fi
for v in "$JPG_QUALITY" "$WEBP_QUALITY"; do
  if ! [[ "$v" =~ ^[0-9]+$ ]] || [ "$v" -lt 1 ] || [ "$v" -gt 100 ]; then
    echo "❌ The -j / -w quality must be a number from 1 to 100." >&2; exit 1
  fi
done
if ! [[ "$PNG_QUALITY" =~ ^[0-9]+-[0-9]+$ ]]; then
  echo "❌ The -q quality must use the min-max format, for example: 85-95" >&2; exit 1
fi

MAX_BYTES=$(awk -v m="$MAX_MB" 'BEGIN { printf "%d", m * 1024 * 1024 }')

# --- Check dependencies ---
MISSING_TOOLS=()
command -v pngquant  &> /dev/null || MISSING_TOOLS+=("pngquant (for PNG)")
command -v jpegoptim &> /dev/null || MISSING_TOOLS+=("jpegoptim (for JPG/JPEG)")
command -v cwebp     &> /dev/null || MISSING_TOOLS+=("cwebp (for WebP, from the libwebp package)")

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  echo "⚠️  The following tools are not installed — files in the related formats will be SKIPPED:"
  printf '   - %s\n' "${MISSING_TOOLS[@]}"
  echo "   Install them, for example, with: sudo pacman -S pngquant jpegoptim libwebp"
  echo ""
fi

IM=""
if command -v magick &> /dev/null; then
  IM="magick"
elif command -v convert &> /dev/null; then
  IM="convert"
fi
if [ "$MAX_BYTES" -gt 0 ] && [ -z "$IM" ]; then
  echo "⚠️  ImageMagick was not found — the 'reduce resolution' step is unavailable."
  echo "   Files still over the limit after lowering quality will be reported as failed."
  echo "   Install: sudo pacman -S imagemagick"
  echo ""
fi

# --- Temporary working directory ---
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT
STATS_FILE="$TMP_ROOT/stats"
FAIL_FILE="$TMP_ROOT/fail"
: > "$STATS_FILE"
: > "$FAIL_FILE"

# Resolution scale sequence (percentage of original size) to try when needed
SCALES="85 70 60 50 40 30 20"

IMG_FIND=( \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) )

list_images() {
  find "$1" -maxdepth 1 -type f "${IMG_FIND[@]}" -print0
}

folder_has_image() {
  [ -n "$(find "$1" -maxdepth 1 -type f "${IMG_FIND[@]}" -print -quit 2>/dev/null)" ]
}

# ============================================================
#  Worker function (runs once per file in a separate process)
# ============================================================

hsize() { numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "${1}B"; }

# Compare the candidate ($CAND) with the best result so far ($BEST)
consider() {
  if [ ! -s "$CAND" ]; then rm -f -- "$CAND"; return 0; fi
  local sz
  sz=$(stat -c%s -- "$CAND")
  if [ "$sz" -lt "$BEST_SIZE" ]; then
    mv -f -- "$CAND" "$BEST"
    BEST_SIZE=$sz
    HAVE_BEST=1
    NOTE="$STAGE_NOTE"
  else
    rm -f -- "$CAND"
  fi
  return 0
}

# True when the limit is enabled and the best result is still over the limit
over_limit() {
  [ "$MAX_BYTES" -gt 0 ] && [ "$BEST_SIZE" -gt "$MAX_BYTES" ]
}

# resize_img SRC DST PERCENT
resize_img() {
  [ -n "$IM" ] || return 1
  "$IM" "$1" -auto-orient -resize "$3%" "$2" >/dev/null 2>&1
}

process_file() {
  F="$1"
  local dir name ext outdir tool pct q
  dir=$(dirname -- "$F")
  name=$(basename -- "$F")
  ext="${name##*.}"
  EXT="${ext,,}"
  outdir="$dir/compressed"

  case "$EXT" in
    png)      tool=pngquant ;;
    jpg|jpeg) tool=jpegoptim ;;
    webp)     tool=cwebp ;;
    *) return 0 ;;
  esac
  if ! command -v "$tool" > /dev/null 2>&1; then
    echo "⚠️  $name — skipped ($tool is not installed)"
    return 0
  fi

  WORK=$(mktemp -d "$TMP_ROOT/w.XXXXXX") || return 0
  BEFORE=$(stat -c%s -- "$F")
  BEST="$WORK/best.$EXT"
  CAND="$WORK/cand.$EXT"
  BEST_SIZE=$BEFORE
  HAVE_BEST=0
  NOTE=""
  STAGE_NOTE=""
  local TARGET=$(( MAX_BYTES * 95 / 100 ))   # target 95% of the limit to leave some margin
  local JOPTS="--strip-com --strip-iptc --strip-xmp --all-progressive --quiet"

  case "$EXT" in
    # ---------------- PNG ----------------
    png)
      local ladder="$PNG_QUALITY 65-85 45-70 25-55"
      [ -z "$IM" ] && ladder="$ladder 0-40"
      local first=1
      for q in $ladder; do
        [ "$first" -eq 0 ] && STAGE_NOTE="quality lowered"
        first=0
        pngquant --quality="$q" --strip --force --output "$CAND" -- "$F" > /dev/null 2>&1
        consider
        over_limit || break
      done
      if over_limit && [ -n "$IM" ]; then
        for pct in $SCALES; do
          STAGE_NOTE="${pct}% resolution"
          resize_img "$F" "$WORK/r.$EXT" "$pct" || break
          pngquant --quality=0-70 --strip --force --output "$CAND" -- "$WORK/r.$EXT" > /dev/null 2>&1
          consider
          over_limit || break
        done
      fi
      ;;

    # ---------------- JPG / JPEG ----------------
    jpg|jpeg)
      cp -f -- "$F" "$CAND"
      jpegoptim --max="$JPG_QUALITY" $JOPTS "$CAND" > /dev/null 2>&1
      consider
      if over_limit; then
        STAGE_NOTE="quality lowered"
        cp -f -- "$F" "$CAND"
        jpegoptim --size="$(( TARGET / 1000 ))k" $JOPTS "$CAND" > /dev/null 2>&1
        consider
      fi
      if over_limit && [ -n "$IM" ]; then
        for pct in $SCALES; do
          STAGE_NOTE="${pct}% resolution"
          resize_img "$F" "$WORK/r.$EXT" "$pct" || break
          cp -f -- "$WORK/r.$EXT" "$CAND"
          jpegoptim --size="$(( TARGET / 1000 ))k" $JOPTS "$CAND" > /dev/null 2>&1
          consider
          over_limit || break
        done
      fi
      ;;

    # ---------------- WebP ----------------
    webp)
      cwebp -quiet -m 6 -q "$WEBP_QUALITY" "$F" -o "$CAND" > /dev/null 2>&1
      consider
      if over_limit; then
        STAGE_NOTE="quality lowered"
        cwebp -quiet -m 6 -size "$TARGET" "$F" -o "$CAND" > /dev/null 2>&1
        consider
      fi
      if over_limit && [ -n "$IM" ]; then
        for pct in $SCALES; do
          STAGE_NOTE="${pct}% resolution"
          resize_img "$F" "$WORK/r.$EXT" "$pct" || break
          cwebp -quiet -m 6 -size "$TARGET" "$WORK/r.$EXT" -o "$CAND" > /dev/null 2>&1
          consider
          over_limit || break
        done
      fi
      ;;
  esac

  # --- Save the result to compressed/ ---
  mkdir -p "$outdir"
  local after
  if [ "$HAVE_BEST" -eq 1 ]; then
    mv -f -- "$BEST" "$outdir/$name"
    after=$BEST_SIZE
  else
    cp -f -- "$F" "$outdir/$name"
    after=$BEFORE
  fi
  printf '%s %s\n' "$BEFORE" "$after" >> "$STATS_FILE"

  local saved info
  saved=$(awk -v b="$BEFORE" -v a="$after" 'BEGIN { if (b > 0) printf "%.0f", (1 - a / b) * 100; else print 0 }')
  info="$(hsize "$BEFORE") → $(hsize "$after") (-${saved}%)"
  [ -n "$NOTE" ] && info="$info · $NOTE"

  if over_limit; then
    echo "❌ $name  $info  — STILL over $(hsize "$MAX_BYTES"); the original file was NOT deleted"
    printf '%s\n' "$F" >> "$FAIL_FILE"
  else
    [ "$HAVE_BEST" -eq 0 ] && info="$info · already optimal, copied unchanged"
    echo "✅ $name  $info"
    if [ "$DELETE_ORIGINAL" -eq 1 ] && [ -s "$outdir/$name" ]; then
      rm -f -- "$F"
    fi
  fi

  rm -rf -- "$WORK"
  return 0
}

export -f hsize consider over_limit resize_img process_file
export PNG_QUALITY JPG_QUALITY WEBP_QUALITY MAX_BYTES DELETE_ORIGINAL \
       STATS_FILE FAIL_FILE TMP_ROOT IM SCALES

# ============================================================
#  Collect folders to process
# ============================================================
ROOTS=("${@:-.}")
TARGET_DIRS=()

if [ "$RECURSIVE" -eq 1 ]; then
  for root in "${ROOTS[@]}"; do
    if [ ! -d "$root" ]; then
      echo "⚠️  Folder not found, skipping: $root"
      continue
    fi
    while IFS= read -r -d '' d; do
      if folder_has_image "$d"; then
        TARGET_DIRS+=("$d")
      fi
    done < <(find "$root" -type d -name compressed -prune -o -type d -print0)
  done
else
  for root in "${ROOTS[@]}"; do
    if [ ! -d "$root" ]; then
      echo "⚠️  Folder not found, skipping: $root"
      continue
    fi
    if folder_has_image "$root"; then
      TARGET_DIRS+=("$root")
    else
      echo "⏭️  No images directly inside: $root  (use -r to include subfolders)"
    fi
  done
fi

if [ ${#TARGET_DIRS[@]} -eq 0 ]; then
  echo "❌ No folders containing images (PNG/JPG/JPEG/WebP) were found."
  echo "   Tip: try adding -r to search subfolders."
  exit 1
fi

echo "🗂️  Total folders to process: ${#TARGET_DIRS[@]}"
printf '   - %s\n' "${TARGET_DIRS[@]}"
echo "🎚️  Quality PNG  : $PNG_QUALITY"
echo "🎚️  Quality JPG  : $JPG_QUALITY"
echo "🎚️  Quality WebP : $WEBP_QUALITY"
if [ "$MAX_BYTES" -gt 0 ]; then
  echo "🎯 Size limit per file: $(hsize "$MAX_BYTES")"
else
  echo "🎯 Size limit per file: disabled"
fi
if [ "$DELETE_ORIGINAL" -eq 1 ]; then
  echo "🗑️  Delete original files: ENABLED (only successful files within the limit; use -k to disable)"
else
  echo "🗑️  Delete original files: DISABLED (original files are kept)"
fi
echo ""

TOTAL_BEFORE=0
TOTAL_AFTER=0
JOBS=$(nproc 2>/dev/null || echo 2)

for dir in "${TARGET_DIRS[@]}"; do
  count=$(find "$dir" -maxdepth 1 -type f "${IMG_FIND[@]}" | wc -l)
  echo "──────────────────────────────────────────"
  echo "📂 Input folder  : $dir"
  echo "📦 Output folder : $dir/compressed"
  echo "🔢 File count    : $count"
  echo ""

  : > "$STATS_FILE"
  list_images "$dir" | xargs -0 -n1 -P"$JOBS" bash -c 'process_file "$1"' _ || true

  read -r b a < <(awk '{ b += $1; a += $2 } END { printf "%d %d\n", b, a }' "$STATS_FILE")
  echo ""
  echo "📊 Size before : $(hsize "$b")"
  echo "📊 Size after  : $(hsize "$a")"
  echo ""
  TOTAL_BEFORE=$((TOTAL_BEFORE + b))
  TOTAL_AFTER=$((TOTAL_AFTER + a))
done

echo "════════════════════════════════════════"
echo "🎉 Done! Processed ${#TARGET_DIRS[@]} folders in total."
echo "📊 Total size before : $(hsize "$TOTAL_BEFORE")"
echo "📊 Total size after  : $(hsize "$TOTAL_AFTER")"

if [ -s "$FAIL_FILE" ]; then
  n=$(wc -l < "$FAIL_FILE")
  echo ""
  echo "❌ $n files are still over the $(hsize "$MAX_BYTES") limit:"
  sed 's/^/   - /' "$FAIL_FILE"
  if [ -z "$IM" ]; then
    echo "   Install ImageMagick (sudo pacman -S imagemagick) to reduce resolution automatically."
  fi
  exit 2
fi
