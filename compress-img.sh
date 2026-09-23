#!/usr/bin/env bash
#
# compress-img.sh — Kompres banyak gambar (PNG, JPG/JPEG, WebP) paralel, multi-core,
# dengan TARGET UKURAN MAKSIMUM per file (default 2 MB).
#
# Tool per format:
#   PNG        -> pngquant
#   JPG/JPEG   -> jpegoptim
#   WebP       -> cwebp (libwebp)
#   (opsional) -> ImageMagick, dipakai sebagai langkah terakhir: memperkecil resolusi
#
# Cara kerja per file (berhenti begitu ukuran <= batas -m):
#   1. Kompres dengan kualitas yang kamu tentukan (-q / -j / -w)
#   2. Kalau masih di atas batas -> turunkan kualitas bertahap / pakai mode target-size
#   3. Kalau masih di atas batas -> perkecil resolusi bertahap (butuh ImageMagick)
#   Hasil selalu yang TERKECIL dari semua percobaan. Kalau hasil tidak lebih kecil
#   dari aslinya, file asli disalin apa adanya ke compressed/.
#
# Cara pakai:
#   ./compress-img.sh [-q min-max] [-j quality] [-w quality] [-m MB] [-r] [-d] [folder ...]
#
# Opsi:
#   -q min-max   Quality pngquant untuk PNG (default: 85-95)
#   -j quality   Quality jpegoptim untuk JPG/JPEG, 1-100 (default: 85)
#   -w quality   Quality cwebp untuk WebP, 1-100 (default: 85)
#   -m MB        Batas ukuran maksimum per file dalam MB, boleh desimal (default: 2).
#                Pakai -m 0 untuk menonaktifkan batas.
#   -r           Rekursif: tiap argumen dianggap folder ROOT, semua subfolder
#                yang berisi gambar ikut diproses.
#   -d           Hapus file asli SETELAH berhasil dikompres dan mencapai batas -m.
#                File yang gagal mencapai batas TIDAK pernah dihapus.
#   -h           Tampilkan bantuan.
#
# Contoh:
#   ./compress-img.sh                          # folder saat ini
#   ./compress-img.sh ./foto ./banner          # banyak folder
#   ./compress-img.sh -m 1.5 ./foto            # batas 1.5 MB
#   ./compress-img.sh -r -d ./assets           # rekursif + hapus file asli
#
# Hasil tiap folder disimpan di: <folder>/compressed/

set -uo pipefail

PNG_QUALITY="85-95"
JPG_QUALITY="85"
WEBP_QUALITY="85"
MAX_MB="2"
RECURSIVE=0
DELETE_ORIGINAL=0

usage() {
  sed -n '2,42p' "$0" | sed 's/^# \{0,1\}//'
}

# --- Parse opsi ---
while getopts ":q:j:w:m:rdh" opt; do
  case "$opt" in
    q) PNG_QUALITY="$OPTARG" ;;
    j) JPG_QUALITY="$OPTARG" ;;
    w) WEBP_QUALITY="$OPTARG" ;;
    m) MAX_MB="$OPTARG" ;;
    r) RECURSIVE=1 ;;
    d) DELETE_ORIGINAL=1 ;;
    h) usage; exit 0 ;;
    \?) echo "❌ Opsi tidak dikenal: -$OPTARG" >&2; exit 1 ;;
    :)  echo "❌ Opsi -$OPTARG butuh argumen." >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

# --- Validasi ---
if ! [[ "$MAX_MB" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "❌ Nilai -m harus angka (MB), contoh: 2 atau 1.5" >&2; exit 1
fi
for v in "$JPG_QUALITY" "$WEBP_QUALITY"; do
  if ! [[ "$v" =~ ^[0-9]+$ ]] || [ "$v" -lt 1 ] || [ "$v" -gt 100 ]; then
    echo "❌ Quality -j / -w harus angka 1-100." >&2; exit 1
  fi
done
if ! [[ "$PNG_QUALITY" =~ ^[0-9]+-[0-9]+$ ]]; then
  echo "❌ Quality -q harus berbentuk min-max, contoh: 85-95" >&2; exit 1
fi

MAX_BYTES=$(awk -v m="$MAX_MB" 'BEGIN { printf "%d", m * 1024 * 1024 }')

# --- Cek dependency ---
MISSING_TOOLS=()
command -v pngquant  &> /dev/null || MISSING_TOOLS+=("pngquant (untuk PNG)")
command -v jpegoptim &> /dev/null || MISSING_TOOLS+=("jpegoptim (untuk JPG/JPEG)")
command -v cwebp     &> /dev/null || MISSING_TOOLS+=("cwebp (untuk WebP, dari paket libwebp)")

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  echo "⚠️  Tool berikut belum terinstall — file dengan format terkait akan DILEWATI:"
  printf '   - %s\n' "${MISSING_TOOLS[@]}"
  echo "   Install misalnya dengan: sudo pacman -S pngquant jpegoptim libwebp"
  echo ""
fi

IM=""
if command -v magick &> /dev/null; then
  IM="magick"
elif command -v convert &> /dev/null; then
  IM="convert"
fi
if [ "$MAX_BYTES" -gt 0 ] && [ -z "$IM" ]; then
  echo "⚠️  ImageMagick tidak ditemukan — langkah 'perkecil resolusi' tidak tersedia."
  echo "   File yang masih di atas batas setelah kualitas diturunkan akan dilaporkan gagal."
  echo "   Install: sudo pacman -S imagemagick"
  echo ""
fi

# --- Direktori kerja sementara ---
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT
STATS_FILE="$TMP_ROOT/stats"
FAIL_FILE="$TMP_ROOT/fail"
: > "$STATS_FILE"
: > "$FAIL_FILE"

# Urutan skala resolusi (persen dari ukuran asli) yang dicoba bila perlu
SCALES="85 70 60 50 40 30 20"

IMG_FIND=( \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) )

list_images() {
  find "$1" -maxdepth 1 -type f "${IMG_FIND[@]}" -print0
}

folder_has_image() {
  [ -n "$(find "$1" -maxdepth 1 -type f "${IMG_FIND[@]}" -print -quit 2>/dev/null)" ]
}

# ============================================================
#  Fungsi worker (dijalankan per file, di proses terpisah)
# ============================================================

hsize() { numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "${1}B"; }

# Bandingkan kandidat ($CAND) dengan yang terbaik sejauh ini ($BEST)
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

# Benar bila batas aktif dan hasil terbaik masih di atas batas
over_limit() {
  [ "$MAX_BYTES" -gt 0 ] && [ "$BEST_SIZE" -gt "$MAX_BYTES" ]
}

# resize_img SRC DST PERSEN
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
    echo "⚠️  $name — dilewati ($tool tidak terinstall)"
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
  local TARGET=$(( MAX_BYTES * 95 / 100 ))   # sasaran 95% dari batas, biar ada margin
  local JOPTS="--strip-com --strip-iptc --strip-xmp --all-progressive --quiet"

  case "$EXT" in
    # ---------------- PNG ----------------
    png)
      local ladder="$PNG_QUALITY 65-85 45-70 25-55"
      [ -z "$IM" ] && ladder="$ladder 0-40"
      local first=1
      for q in $ladder; do
        [ "$first" -eq 0 ] && STAGE_NOTE="kualitas diturunkan"
        first=0
        pngquant --quality="$q" --strip --force --output "$CAND" -- "$F" > /dev/null 2>&1
        consider
        over_limit || break
      done
      if over_limit && [ -n "$IM" ]; then
        for pct in $SCALES; do
          STAGE_NOTE="resolusi ${pct}%"
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
        STAGE_NOTE="kualitas diturunkan"
        cp -f -- "$F" "$CAND"
        jpegoptim --size="$(( TARGET / 1000 ))k" $JOPTS "$CAND" > /dev/null 2>&1
        consider
      fi
      if over_limit && [ -n "$IM" ]; then
        for pct in $SCALES; do
          STAGE_NOTE="resolusi ${pct}%"
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
        STAGE_NOTE="kualitas diturunkan"
        cwebp -quiet -m 6 -size "$TARGET" "$F" -o "$CAND" > /dev/null 2>&1
        consider
      fi
      if over_limit && [ -n "$IM" ]; then
        for pct in $SCALES; do
          STAGE_NOTE="resolusi ${pct}%"
          resize_img "$F" "$WORK/r.$EXT" "$pct" || break
          cwebp -quiet -m 6 -size "$TARGET" "$WORK/r.$EXT" -o "$CAND" > /dev/null 2>&1
          consider
          over_limit || break
        done
      fi
      ;;
  esac

  # --- Simpan hasil ke compressed/ ---
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
    echo "❌ $name  $info  — MASIH di atas $(hsize "$MAX_BYTES"), file asli TIDAK dihapus"
    printf '%s\n' "$F" >> "$FAIL_FILE"
  else
    [ "$HAVE_BEST" -eq 0 ] && info="$info · sudah optimal, disalin apa adanya"
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
#  Kumpulkan folder yang akan diproses
# ============================================================
ROOTS=("${@:-.}")
TARGET_DIRS=()

if [ "$RECURSIVE" -eq 1 ]; then
  for root in "${ROOTS[@]}"; do
    if [ ! -d "$root" ]; then
      echo "⚠️  Folder tidak ditemukan, dilewati: $root"
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
      echo "⚠️  Folder tidak ditemukan, dilewati: $root"
      continue
    fi
    if folder_has_image "$root"; then
      TARGET_DIRS+=("$root")
    else
      echo "⏭️  Tidak ada gambar langsung di: $root  (pakai -r untuk menyertakan subfolder)"
    fi
  done
fi

if [ ${#TARGET_DIRS[@]} -eq 0 ]; then
  echo "❌ Tidak ada folder dengan gambar (PNG/JPG/JPEG/WebP) yang ditemukan."
  echo "   Tip: coba tambahkan -r untuk mencari sampai ke subfolder."
  exit 1
fi

echo "🗂️  Total folder yang akan diproses: ${#TARGET_DIRS[@]}"
printf '   - %s\n' "${TARGET_DIRS[@]}"
echo "🎚️  Quality PNG  : $PNG_QUALITY"
echo "🎚️  Quality JPG  : $JPG_QUALITY"
echo "🎚️  Quality WebP : $WEBP_QUALITY"
if [ "$MAX_BYTES" -gt 0 ]; then
  echo "🎯 Batas ukuran per file: $(hsize "$MAX_BYTES")"
else
  echo "🎯 Batas ukuran per file: nonaktif"
fi
if [ "$DELETE_ORIGINAL" -eq 1 ]; then
  echo "🗑️  Mode hapus asli: AKTIF (hanya file yang sukses & mencapai batas)"
fi
echo ""

TOTAL_BEFORE=0
TOTAL_AFTER=0
JOBS=$(nproc 2>/dev/null || echo 2)

for dir in "${TARGET_DIRS[@]}"; do
  count=$(find "$dir" -maxdepth 1 -type f "${IMG_FIND[@]}" | wc -l)
  echo "──────────────────────────────────────────"
  echo "📂 Folder input  : $dir"
  echo "📦 Folder output : $dir/compressed"
  echo "🔢 Jumlah file   : $count"
  echo ""

  : > "$STATS_FILE"
  list_images "$dir" | xargs -0 -n1 -P"$JOBS" bash -c 'process_file "$1"' _ || true

  read -r b a < <(awk '{ b += $1; a += $2 } END { printf "%d %d\n", b, a }' "$STATS_FILE")
  echo ""
  echo "📊 Ukuran sebelum : $(hsize "$b")"
  echo "📊 Ukuran sesudah : $(hsize "$a")"
  echo ""
  TOTAL_BEFORE=$((TOTAL_BEFORE + b))
  TOTAL_AFTER=$((TOTAL_AFTER + a))
done

echo "════════════════════════════════════════"
echo "🎉 Selesai! Total ${#TARGET_DIRS[@]} folder diproses."
echo "📊 Total ukuran sebelum : $(hsize "$TOTAL_BEFORE")"
echo "📊 Total ukuran sesudah : $(hsize "$TOTAL_AFTER")"

if [ -s "$FAIL_FILE" ]; then
  n=$(wc -l < "$FAIL_FILE")
  echo ""
  echo "❌ $n file masih di atas batas $(hsize "$MAX_BYTES"):"
  sed 's/^/   - /' "$FAIL_FILE"
  if [ -z "$IM" ]; then
    echo "   Install ImageMagick (sudo pacman -S imagemagick) agar resolusi bisa diperkecil otomatis."
  fi
  exit 2
fi
