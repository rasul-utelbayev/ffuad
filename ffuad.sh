#!/data/data/com.termux/files/usr/bin/bash

export TERM=xterm-256color

set -e
RED=$'\e[0;31m'; GREEN=$'\e[0;32m'; YELLOW=$'\e[1;33m'; BLUE=$'\e[0;34m'; NC=$'\e[0m'
VERSION="FFUAD v3.0 by Rasul"
HISTFILE="$HOME/.ffuad_history"
CACHE="$HOME/.ffuad_cache"
mkdir -p "$CACHE"

# ── Yordam ──────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
${YELLOW}FFUAD - Fast File Upload and Download${NC}
${BLUE}${VERSION}${NC}

  ffuad -f <fayl>              Faylni yuklash
  ffuad -f <fayl> -p <parol>  Faylni shifrlash va yuklash
  ffuad -fl <papka>            Papkani zip qilib yuklash
  ffuad -fl <papka> -p <parol> Papkani shifrlash va yuklash
  ffuad -d <kod>               Faylni yuklab olish
  ffuad -d <kod> -p <parol>   Shifrlangan faylni yuklab olish
  ffuad --list                 Tarix ko'rish
  ffuad --version              Versiya
EOF
  exit 0
}

# ── Tarix ────────────────────────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M')] $1" >> "$HISTFILE"; }

# ── Progress bar ─────────────────────────────────────────────────────────────
progress() {
  local msg="$1" i
  echo -ne "${YELLOW}${msg}${NC} "
  for i in {1..20}; do
    echo -ne "${BLUE}█${NC}"
    sleep 0.05
  done
  echo ""
}

# ── AES shifrlash ────────────────────────────────────────────────────────────
encrypt_file() {
  local input="$1" output="$2" pass="$3"
  openssl enc -aes-256-cbc -pbkdf2 -in "$input" -out "$output" -k "$pass" 2>/dev/null \
    || { echo -e "${RED}Shifrlash xatosi!${NC}"; exit 1; }
}

decrypt_file() {
  local input="$1" output="$2" pass="$3"
  openssl enc -aes-256-cbc -pbkdf2 -d -in "$input" -out "$output" -k "$pass" 2>/dev/null \
    || { echo -e "${RED}Parol noto'g'ri yoki fayl buzilgan!${NC}"; exit 1; }
}

# ── Yuklash ──────────────────────────────────────────────────────────────────
upload() {
  local file="$1" pass="$2" upload_file="$1"

  [ -f "$file" ] || { echo -e "${RED}Fayl topilmadi: $file${NC}"; exit 1; }

  if [ -n "$pass" ]; then
    upload_file="$CACHE/$(basename "$file").enc"
    progress "Shifrlanyapti..."
    encrypt_file "$file" "$upload_file" "$pass"
  fi

  progress "Yuklanmoqda... "
  local url
  url=$(curl -fsSL -F "file=@$upload_file" https://0x0.st) \
    || { echo -e "${RED}Yuklash xatosi!${NC}"; exit 1; }

  [ -n "$pass" ] && rm -f "$upload_file"

  local code="${url##*/}"
  log "UPLOAD: $(basename "$file") -> $url $([ -n "$pass" ] && echo '[shifrlangan]')"

  echo -e "\n${GREEN}✓ Yuklandi!${NC}"
  echo -e "  Kod:  ${YELLOW}${code}${NC}"
  echo -e "  URL:  ${BLUE}${url}${NC}"
  [ -n "$pass" ] && echo -e "  ${RED}⚠ Parolsiz ochilmaydi!${NC}"
}

# ── Papka yuklash ─────────────────────────────────────────────────────────────
upload_folder() {
  local folder="$1" pass="$2"
  [ -d "$folder" ] || { echo -e "${RED}Papka topilmadi: $folder${NC}"; exit 1; }

  local zipfile="$CACHE/$(basename "$folder").zip"
  progress "Zip qilinmoqda..."
  (cd "$(dirname "$folder")" && zip -r "$zipfile" "$(basename "$folder")" > /dev/null)

  upload "$zipfile" "$pass"
  rm -f "$zipfile"
}

# ── Yuklab olish ──────────────────────────────────────────────────────────────
download() {
  local code="$1" pass="$2"
  local url="https://0x0.st/$code"
  local outfile="$code"

  progress "Yuklab olinmoqda..."
  curl -fsSL -o "$outfile" "$url" \
    || { echo -e "${RED}Yuklab olish xatosi: $code${NC}"; exit 1; }

  if [ -n "$pass" ]; then
    local decfile="${code%.enc}"
    decrypt_file "$outfile" "$decfile" "$pass"
    rm -f "$outfile"
    outfile="$decfile"
  fi

  log "DOWNLOAD: $code $([ -n "$pass" ] && echo '[shifr ochildi]')"
  echo -e "\n${GREEN}✓ Saqlandi: ${YELLOW}${outfile}${NC}"
}

# ── Asosiy ───────────────────────────────────────────────────────────────────
case "$1" in
  -f)
    [[ "$3" == "-p" ]] && upload "$2" "$4" || upload "$2"
    ;;
  -fl)
    [[ "$3" == "-p" ]] && upload_folder "$2" "$4" || upload_folder "$2"
    ;;
  -d)
    [ -z "$2" ] && { echo -e "${RED}Kod kiriting!${NC}"; exit 1; }
    [[ "$3" == "-p" ]] && download "$2" "$4" || download "$2"
    ;;
  --list)
    [ -f "$HISTFILE" ] && echo -e "${YELLOW}Tarix:${NC}\n$(cat "$HISTFILE")" || echo "Tarix bo'sh."
    ;;
  --version)
    echo -e "${BLUE}${VERSION}${NC}"
    ;;
  --help|-help|"")
    usage
    ;;
  *)
    echo -e "${RED}Noto'g'ri buyruq. --help ga qarang.${NC}"; exit 1
    ;;
esac
