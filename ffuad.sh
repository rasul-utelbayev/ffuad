#!/data/data/com.termux/files/usr/bin/bash

set -e
RED=$'\e[0;31m'; GREEN=$'\e[0;32m'; YELLOW=$'\e[1;33m'; BLUE=$'\e[0;34m'; NC=$'\e[0m'
VERSION="FFUAD v3.0 by Rasul"
HISTFILE="$HOME/.ffuad_history"
CACHE="$HOME/.ffuad_cache"
mkdir -p "$CACHE"

# ── Help ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
${YELLOW}FFUAD - Fast File Upload and Download${NC}
${BLUE}${VERSION}${NC}

  ffuad -f <file>              Upload a file
  ffuad -f <file> -p <pass>   Encrypt and upload a file
  ffuad -fl <folder>           Zip and upload a folder
  ffuad -fl <folder> -p <pass> Encrypt and upload a folder
  ffuad -d <code>              Download a file
  ffuad -d <code> -p <pass>   Download and decrypt a file
  ffuad --list                 Show history
  ffuad --version              Show version
EOF
  exit 0
}

# ── History ───────────────────────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M')] $1" >> "$HISTFILE"; }

# ── Progress bar ──────────────────────────────────────────────────────────────
progress() {
  local msg="$1" i
  echo -ne "${YELLOW}${msg}${NC} "
  for i in {1..20}; do
    echo -ne "${BLUE}█${NC}"
    sleep 0.05
  done
  echo ""
}

# ── AES Encryption ────────────────────────────────────────────────────────────
encrypt_file() {
  local input="$1" output="$2" pass="$3"
  openssl enc -aes-256-cbc -pbkdf2 -in "$input" -out "$output" -k "$pass" 2>/dev/null \
    || { echo -e "${RED}Encryption failed!${NC}"; exit 1; }
}

decrypt_file() {
  local input="$1" output="$2" pass="$3"
  openssl enc -aes-256-cbc -pbkdf2 -d -in "$input" -out "$output" -k "$pass" 2>/dev/null \
    || { echo -e "${RED}Wrong password or corrupted file!${NC}"; exit 1; }
}

# ── Upload ────────────────────────────────────────────────────────────────────
upload() {
  local file="$1" pass="$2" upload_file="$1"

  [ -f "$file" ] || { echo -e "${RED}File not found: $file${NC}"; exit 1; }

  if [ -n "$pass" ]; then
    upload_file="$CACHE/$(basename "$file").enc"
    progress "Encrypting... "
    encrypt_file "$file" "$upload_file" "$pass"
  fi

  progress "Uploading...  "
  local url
  url=$(curl -fsSL -F "file=@$upload_file" https://0x0.st) \
    || { echo -e "${RED}Upload failed!${NC}"; exit 1; }

  [ -n "$pass" ] && rm -f "$upload_file"

  local code="${url##*/}"
  log "UPLOAD: $(basename "$file") -> $url $([ -n "$pass" ] && echo '[encrypted]')"

  echo -e "\n${GREEN}✓ Uploaded!${NC}"
  echo -e "  Code: ${YELLOW}${code}${NC}"
  echo -e "  URL:  ${BLUE}${url}${NC}"
  [ -n "$pass" ] && echo -e "  ${RED}⚠ Password required to open!${NC}"
}

# ── Upload Folder ─────────────────────────────────────────────────────────────
upload_folder() {
  local folder="$1" pass="$2"
  [ -d "$folder" ] || { echo -e "${RED}Folder not found: $folder${NC}"; exit 1; }

  local zipfile="$CACHE/$(basename "$folder").zip"
  progress "Zipping...    "
  (cd "$(dirname "$folder")" && zip -r "$zipfile" "$(basename "$folder")" > /dev/null)

  upload "$zipfile" "$pass"
  rm -f "$zipfile"
}

# ── Download ──────────────────────────────────────────────────────────────────
download() {
  local code="$1" pass="$2"
  local url="https://0x0.st/$code"
  local outfile="$code"

  progress "Downloading..."
  curl -fsSL -o "$outfile" "$url" \
    || { echo -e "${RED}Download failed: $code${NC}"; exit 1; }

  if [ -n "$pass" ]; then
    local decfile="${code%.enc}"
    decrypt_file "$outfile" "$decfile" "$pass"
    rm -f "$outfile"
    outfile="$decfile"
  fi

  log "DOWNLOAD: $code $([ -n "$pass" ] && echo '[decrypted]')"
  echo -e "\n${GREEN}✓ Saved: ${YELLOW}${outfile}${NC}"
}

# ── Main ──────────────────────────────────────────────────────────────────────
case "$1" in
  -f)
    [[ "$3" == "-p" ]] && upload "$2" "$4" || upload "$2"
    ;;
  -fl)
    [[ "$3" == "-p" ]] && upload_folder "$2" "$4" || upload_folder "$2"
    ;;
  -d)
    [ -z "$2" ] && { echo -e "${RED}Provide a code!${NC}"; exit 1; }
    [[ "$3" == "-p" ]] && download "$2" "$4" || download "$2"
    ;;
  --list)
    [ -f "$HISTFILE" ] && echo -e "${YELLOW}History:${NC}\n$(cat "$HISTFILE")" || echo "History is empty."
    ;;
  --version)
    echo -e "${BLUE}${VERSION}${NC}"
    ;;
  --help|-help|"")
    usage
    ;;
  *)
    echo -e "${RED}Unknown command. Use --help${NC}"; exit 1
    ;;
esac
