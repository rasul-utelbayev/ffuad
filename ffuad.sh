#!/usr/bin/env bash
set -Euo pipefail
umask 077

APP_NAME="FFUAD Server"
SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"
CONFIG_DIR="${FFUAD_CONFIG_DIR:-$HOME/.config/ffuad}"
PROFILES_DIR="$CONFIG_DIR/bash-profiles"
RUNTIME_BASE="$CONFIG_DIR/bash-runtime"
SERVERS_ROOT="${FFUAD_SERVERS_ROOT:-$HOME/FFUAD-Servers}"
GLOBAL_FILE="$CONFIG_DIR/bash-global.conf"
MAX_UPLOAD_BYTES=$((333 * 1024 * 1024))
SESSION_SECONDS=$((12 * 60 * 60))

mkdir -p "$CONFIG_DIR" "$PROFILES_DIR" "$RUNTIME_BASE" "$SERVERS_ROOT"
chmod 700 "$CONFIG_DIR" "$PROFILES_DIR" "$RUNTIME_BASE" "$SERVERS_ROOT" 2>/dev/null || true

command_exists() { command -v "$1" >/dev/null 2>&1; }
now_epoch() { date +%s; }
now_iso() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
random_hex() {
  local bytes="${1:-16}"
  if command_exists openssl; then openssl rand -hex "$bytes" 2>/dev/null; else od -An -N "$bytes" -tx1 /dev/urandom | tr -d ' \n'; fi
}
random_token() {
  if command_exists openssl; then openssl rand -base64 32 2>/dev/null | tr -d '\n=/' | cut -c1-40; else random_hex 20; fi
}
sha256_text() { printf '%s' "$1" | sha256sum | awk '{print $1}'; }
hash_password() { sha256_text "$1:$2"; }
b64enc() { printf '%s' "$1" | base64 | tr -d '\n'; }
b64dec() { printf '%s' "$1" | base64 -d 2>/dev/null || true; }

cfg_get() {
  local file="$1" key="$2" line
  [[ -f "$file" ]] || return 1
  line="$(grep -m1 -F "${key}=" "$file" 2>/dev/null || true)"
  [[ -n "$line" ]] || return 1
  printf '%s' "${line#*=}"
}
write_global() {
  local lang="$1" admin_secret="$2"
  local tmp="$GLOBAL_FILE.tmp.$$"
  {
    printf 'language=%s\n' "$lang"
    printf 'admin_secret=%s\n' "$admin_secret"
  } > "$tmp"
  chmod 600 "$tmp"
  mv -f "$tmp" "$GLOBAL_FILE"
}
get_language() {
  local lang
  lang="$(cfg_get "$GLOBAL_FILE" language 2>/dev/null || true)"
  [[ "$lang" == "el" ]] || lang="en"
  printf '%s' "$lang"
}
trm() {
  local key="$1" lang="${2:-$(get_language)}"
  if [[ "$lang" == "el" ]]; then
    case "$key" in
      title) printf 'FFUAD Server — Διαχείριση' ;;
      menu_start) printf 'Έναρξη διακομιστή' ;;
      menu_create) printf 'Δημιουργία διακομιστή' ;;
      menu_edit) printf 'Επεξεργασία διακομιστή' ;;
      menu_delete) printf 'Διαγραφή διακομιστή' ;;
      menu_list) printf 'Λίστα διακομιστών' ;;
      menu_language) printf 'Αλλαγή γλώσσας' ;;
      menu_password) printf 'Εμφάνιση κωδικού διαχειριστή' ;;
      menu_install) printf 'Εγκατάσταση εξαρτήσεων' ;;
      menu_exit) printf 'Έξοδος' ;;
      choose) printf 'Επίλεξε επιλογή' ;;
      choose_server) printf 'Επίλεξε τον διακομιστή που θέλεις να ανοίξεις' ;;
      no_servers) printf 'Δεν υπάρχουν διακομιστές. Δημιούργησε πρώτα έναν.' ;;
      invalid) printf 'Μη έγκυρη επιλογή.' ;;
      admin_password) printf 'Κωδικός διαχειριστή' ;;
      wrong_password) printf 'Λανθασμένος κωδικός διαχειριστή.' ;;
      server_name) printf 'Όνομα διακομιστή' ;;
      server_password_optional) printf 'Κωδικός διαχειριστή ιστοσελίδας (προαιρετικός)' ;;
      server_root_optional) printf 'Φάκελος αποθήκευσης (κενό = αυτόματα από το όνομα)' ;;
      default_language) printf 'Προεπιλεγμένη γλώσσα ιστοσελίδας' ;;
      confirm_create) printf 'Να δημιουργηθεί αυτός ο διακομιστής;' ;;
      confirm_edit) printf 'Να αποθηκευτούν οι αλλαγές;' ;;
      confirm_delete) printf 'Να διαγραφεί αυτός ο διακομιστής;' ;;
      confirm_delete_files) printf 'Να διαγραφεί οριστικά και ο φάκελος αρχείων;' ;;
      yes_no) printf 'ν/Ο' ;;
      created) printf 'Ο διακομιστής δημιουργήθηκε.' ;;
      updated) printf 'Ο διακομιστής ενημερώθηκε.' ;;
      deleted) printf 'Ο διακομιστής διαγράφηκε.' ;;
      cancelled) printf 'Η ενέργεια ακυρώθηκε.' ;;
      installing) printf 'Εγκατάσταση εξαρτήσεων FFUAD…' ;;
      selected) printf 'Επιλεγμένος διακομιστής' ;;
      starting) printf 'Εκκίνηση τοπικού, Cloudflare και Tor συνδέσμου…' ;;
      local) printf 'ΤΟΠΙΚΟ' ;;
      localhost) printf 'ΤΟΠΙΚΗ ΣΥΣΚΕΥΗ' ;;
      cloudflare) printf 'CLOUDFLARE' ;;
      tor) printf 'TOR' ;;
      unavailable) printf 'ΜΗ ΔΙΑΘΕΣΙΜΟ' ;;
      stop_hint) printf 'Πάτησε Ctrl+C για διακοπή μόνο αυτής της συνεδρίας.' ;;
      passwordless_warning) printf 'ΠΡΟΣΟΧΗ: Αυτός ο διακομιστής δεν έχει κωδικό διαχειριστή. Όποιος έχει σύνδεσμο μπορεί να αποκτήσει πλήρη πρόσβαση.' ;;
      *) printf '%s' "$key" ;;
    esac
  else
    case "$key" in
      title) printf 'FFUAD Server — Management' ;;
      menu_start) printf 'Start server' ;;
      menu_create) printf 'Create server' ;;
      menu_edit) printf 'Edit server' ;;
      menu_delete) printf 'Delete server' ;;
      menu_list) printf 'List servers' ;;
      menu_language) printf 'Change language' ;;
      menu_password) printf 'Show administrator password' ;;
      menu_install) printf 'Install dependencies' ;;
      menu_exit) printf 'Exit' ;;
      choose) printf 'Choose an option' ;;
      choose_server) printf 'Choose the server you want to access' ;;
      no_servers) printf 'No servers exist. Create one first.' ;;
      invalid) printf 'Invalid option.' ;;
      admin_password) printf 'Administrator password' ;;
      wrong_password) printf 'Incorrect administrator password.' ;;
      server_name) printf 'Server name' ;;
      server_password_optional) printf 'Website administrator password (optional)' ;;
      server_root_optional) printf 'Storage folder (blank = generated from server name)' ;;
      default_language) printf 'Default website language' ;;
      confirm_create) printf 'Create this server?' ;;
      confirm_edit) printf 'Save these changes?' ;;
      confirm_delete) printf 'Delete this server?' ;;
      confirm_delete_files) printf 'Also permanently delete its files folder?' ;;
      yes_no) printf 'y/N' ;;
      created) printf 'Server created.' ;;
      updated) printf 'Server updated.' ;;
      deleted) printf 'Server deleted.' ;;
      cancelled) printf 'Action cancelled.' ;;
      installing) printf 'Installing FFUAD dependencies…' ;;
      selected) printf 'Selected server' ;;
      starting) printf 'Starting local, Cloudflare, and Tor links…' ;;
      local) printf 'LOCAL' ;;
      localhost) printf 'LOCALHOST' ;;
      cloudflare) printf 'CLOUDFLARE' ;;
      tor) printf 'TOR' ;;
      unavailable) printf 'UNAVAILABLE' ;;
      stop_hint) printf 'Press Ctrl+C to stop only this session.' ;;
      passwordless_warning) printf 'WARNING: This server has no administrator password. Anyone with a link can obtain full access.' ;;
      *) printf '%s' "$key" ;;
    esac
  fi
}

confirm_cli() {
  local prompt="$1" lang="${2:-$(get_language)}" ans
  read -r -p "$prompt ($(trm yes_no "$lang")): " ans || true
  [[ "${ans,,}" == "y" || "${ans,,}" == "yes" || "${ans,,}" == "ν" || "${ans,,}" == "ναι" ]]
}

slugify() {
  local s="$1"
  s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^[:alnum:]_-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  [[ -n "$s" ]] || s="server"
  printf '%s' "$s"
}
validate_name() {
  local s="$1"
  [[ -n "$s" && "$s" != "." && "$s" != ".." && "$s" != *$'\n'* && "$s" != *$'\r'* && "$s" != */* && "$s" != *\\* ]]
}
profile_file() { printf '%s/%s.profile' "$PROFILES_DIR" "$1"; }
profile_exists() { [[ -f "$(profile_file "$1")" ]]; }
profile_get_raw() { cfg_get "$(profile_file "$1")" "$2"; }
profile_get() {
  local id="$1" key="$2" value
  value="$(profile_get_raw "$id" "$key" 2>/dev/null || true)"
  case "$key" in name|root|description) b64dec "$value" ;; *) printf '%s' "$value" ;; esac
}
profile_ids() {
  local f
  shopt -s nullglob
  for f in "$PROFILES_DIR"/*.profile; do basename "$f" .profile; done
  shopt -u nullglob
}
profile_count() { profile_ids | awk 'NF{n++} END{print n+0}'; }
write_profile() {
  local id="$1" name="$2" root="$3" description="$4" pass_salt="$5" pass_hash="$6" lang="$7" created="$8"
  local file tmp secret
  file="$(profile_file "$id")"; tmp="$file.tmp.$$"
  secret="$(profile_get_raw "$id" secret 2>/dev/null || true)"
  [[ -n "$secret" ]] || secret="$(random_hex 32)"
  {
    printf 'id=%s\n' "$id"
    printf 'name=%s\n' "$(b64enc "$name")"
    printf 'root=%s\n' "$(b64enc "$root")"
    printf 'description=%s\n' "$(b64enc "$description")"
    printf 'password_salt=%s\n' "$pass_salt"
    printf 'password_hash=%s\n' "$pass_hash"
    printf 'language=%s\n' "$lang"
    printf 'secret=%s\n' "$secret"
    printf 'created_at=%s\n' "$created"
    printf 'updated_at=%s\n' "$(now_iso)"
  } > "$tmp"
  chmod 600 "$tmp"; mv -f "$tmp" "$file"
}

first_run_setup() {
  [[ -f "$GLOBAL_FILE" ]] && return 0
  local lang="en" admin_secret
  if [[ -t 0 ]]; then
    printf '1) English\n2) Ελληνικά\n'
    read -r -p '> ' choice || true
    [[ "${choice:-}" == "2" ]] && lang="el"
  fi
  admin_secret="$(random_token)"
  write_global "$lang" "$admin_secret"
  printf '\n%s: %s\n\n' "$(trm admin_password "$lang")" "$admin_secret"
}

require_admin() {
  local lang="${1:-$(get_language)}" expected entered
  expected="$(cfg_get "$GLOBAL_FILE" admin_secret 2>/dev/null || true)"
  [[ -n "$expected" ]] || return 0
  read -r -s -p "$(trm admin_password "$lang"): " entered || true
  printf '\n'
  if [[ "$entered" != "$expected" ]]; then
    printf '%s\n' "$(trm wrong_password "$lang")" >&2
    return 1
  fi
}


server_name_taken() {
  local wanted="${1,,}" exclude="${2:-}" id existing
  while IFS= read -r id; do
    [[ "$id" == "$exclude" ]] && continue
    existing="$(profile_get "$id" name)"
    [[ "${existing,,}" == "$wanted" ]] && return 0
  done < <(profile_ids)
  return 1
}

unique_profile_id() {
  local base id n=2
  base="$(slugify "$1")"; id="$base"
  while profile_exists "$id"; do id="${base}-${n}"; ((n++)); done
  printf '%s' "$id"
}
unique_storage_root() {
  local name="$1" base path n=2 id existing
  base="$(slugify "$name")"; path="$SERVERS_ROOT/$base"
  while :; do
    existing=0
    while IFS= read -r id; do
      [[ "$(profile_get "$id" root)" == "$path" ]] && { existing=1; break; }
    done < <(profile_ids)
    (( existing == 0 )) && break
    path="$SERVERS_ROOT/${base}-${n}"; ((n++))
  done
  printf '%s' "$path"
}

create_server() {
  local lang="${1:-$(get_language)}" name password root description id salt hash default_lang
  require_admin "$lang" || return 1
  read -r -p "$(trm server_name "$lang"): " name
  validate_name "$name" || { printf '%s\n' "$(trm invalid "$lang")"; return 1; }
  server_name_taken "$name" && { printf 'A server with that name already exists.\n'; return 1; }
  read -r -s -p "$(trm server_password_optional "$lang"): " password || true; printf '\n'
  read -r -p "$(trm server_root_optional "$lang"): " root || true
  read -r -p "Description / Περιγραφή (optional): " description || true
  printf '%s [en/el] (default %s): ' "$(trm default_language "$lang")" "$lang"
  read -r default_lang || true
  [[ "$default_lang" == "en" || "$default_lang" == "el" ]] || default_lang="$lang"
  [[ -n "$root" ]] || root="$(unique_storage_root "$name")"
  root="${root/#\~/$HOME}"
  mkdir -p "$root" || return 1
  root="$(realpath -m "$root")"
  id="$(unique_profile_id "$name")"
  salt=""; hash=""
  if [[ -n "$password" ]]; then salt="$(random_hex 16)"; hash="$(hash_password "$salt" "$password")"; fi
  confirm_cli "$(trm confirm_create "$lang")" "$lang" || { printf '%s\n' "$(trm cancelled "$lang")"; return 0; }
  write_profile "$id" "$name" "$root" "$description" "$salt" "$hash" "$default_lang" "$(now_iso)"
  printf '%s [%s]\n' "$(trm created "$lang")" "$name"
}

select_profile() {
  local lang="${1:-$(get_language)}" prompt="${2:-$(trm choose_server "$lang")}" id name count n choice
  mapfile -t PROFILE_LIST < <(profile_ids)
  count="${#PROFILE_LIST[@]}"
  if (( count == 0 )); then printf '%s\n' "$(trm no_servers "$lang")" >&2; return 1; fi
  printf '\n%s:\n' "$prompt"
  n=1
  for id in "${PROFILE_LIST[@]}"; do
    name="$(profile_get "$id" name)"
    if [[ -n "$(profile_get "$id" password_hash)" ]]; then
      printf '  %d) %s [🔒] (%s)\n' "$n" "$name" "$id"
    else
      printf '  %d) %s [open] (%s)\n' "$n" "$name" "$id"
    fi
    ((n++))
  done
  read -r -p '> ' choice || true
  [[ "$choice" =~ ^[0-9]+$ ]] || return 1
  (( choice >= 1 && choice <= count )) || return 1
  printf '%s' "${PROFILE_LIST[choice-1]}"
}

edit_server() {
  local lang="${1:-$(get_language)}" id name root description old_hash old_salt new_name new_root new_desc pw_mode pw1 salt hash default_lang
  require_admin "$lang" || return 1
  id="$(select_profile "$lang" "$(trm menu_edit "$lang")")" || return 1
  name="$(profile_get "$id" name)"; root="$(profile_get "$id" root)"; description="$(profile_get "$id" description)"
  old_hash="$(profile_get "$id" password_hash)"; old_salt="$(profile_get "$id" password_salt)"; default_lang="$(profile_get "$id" language)"
  read -r -p "$(trm server_name "$lang") [$name]: " new_name || true; [[ -n "$new_name" ]] || new_name="$name"
  validate_name "$new_name" || return 1
  server_name_taken "$new_name" "$id" && { printf 'A server with that name already exists.\n'; return 1; }
  read -r -p "$(trm server_root_optional "$lang") [$root]: " new_root || true; [[ -n "$new_root" ]] || new_root="$root"
  new_root="${new_root/#\~/$HOME}"; mkdir -p "$new_root"; new_root="$(realpath -m "$new_root")"
  read -r -p "Description / Περιγραφή [$description]: " new_desc || true; [[ -n "$new_desc" ]] || new_desc="$description"
  printf 'Password / Κωδικός: 1) keep  2) set/change  3) remove\n> '
  read -r pw_mode || true
  salt="$old_salt"; hash="$old_hash"
  case "$pw_mode" in
    2) read -r -s -p "$(trm server_password_optional "$lang"): " pw1 || true; printf '\n'; [[ -n "$pw1" ]] || { printf 'Password cannot be empty in set/change mode.\n'; return 1; }; salt="$(random_hex 16)"; hash="$(hash_password "$salt" "$pw1")" ;;
    3) salt=""; hash="" ;;
  esac
  printf '%s [en/el] [%s]: ' "$(trm default_language "$lang")" "$default_lang"; read -r new_lang || true
  [[ "$new_lang" == "en" || "$new_lang" == "el" ]] && default_lang="$new_lang"
  confirm_cli "$(trm confirm_edit "$lang")" "$lang" || { printf '%s\n' "$(trm cancelled "$lang")"; return 0; }
  write_profile "$id" "$new_name" "$new_root" "$new_desc" "$salt" "$hash" "$default_lang" "$(profile_get "$id" created_at)"
  printf '%s\n' "$(trm updated "$lang")"
}

delete_server() {
  local lang="${1:-$(get_language)}" id name root del_files="no"
  require_admin "$lang" || return 1
  id="$(select_profile "$lang" "$(trm menu_delete "$lang")")" || return 1
  name="$(profile_get "$id" name)"; root="$(profile_get "$id" root)"
  confirm_cli "$(trm confirm_delete "$lang") [$name]" "$lang" || { printf '%s\n' "$(trm cancelled "$lang")"; return 0; }
  if confirm_cli "$(trm confirm_delete_files "$lang") [$root]" "$lang"; then del_files="yes"; fi
  rm -f -- "$(profile_file "$id")"
  if [[ "$del_files" == "yes" && -n "$root" ]]; then
    case "$(realpath -m "$root")" in
      /|/storage|/storage/emulated|/storage/emulated/0|"$HOME"|"$HOME/storage"|"$HOME/storage/shared")
        printf 'Refusing to delete a device or home storage root: %s\n' "$root" >&2 ;;
      *) rm -rf -- "$root" ;;
    esac
  fi
  printf '%s\n' "$(trm deleted "$lang")"
}

list_servers() {
  local id name root lang protected
  printf '%-24s %-14s %-8s %s\n' "NAME" "ID" "LANG" "ROOT"
  while IFS= read -r id; do
    name="$(profile_get "$id" name)"; root="$(profile_get "$id" root)"; lang="$(profile_get "$id" language)"
    [[ -n "$(profile_get "$id" password_hash)" ]] && protected="locked" || protected="open"
    printf '%-24s %-14s %-8s %s [%s]\n' "$name" "$id" "$lang" "$root" "$protected"
  done < <(profile_ids)
}

url_decode() {
  local s="${1//+/ }" out="" c hex ch i=0 len
  len=${#s}
  while (( i < len )); do
    c="${s:i:1}"
    if [[ "$c" == '%' && $((i+2)) -lt $len ]]; then
      hex="${s:i+1:2}"
      if [[ "$hex" =~ ^[0-9A-Fa-f]{2}$ ]]; then
        printf -v ch '%b' "\\x$hex"
        out+="$ch"; ((i+=3)); continue
      fi
    fi
    out+="$c"; ((i++))
  done
  printf '%s' "$out"
}
url_encode() {
  local s="$1" out="" c hex i
  LC_ALL=C
  for ((i=0; i<${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in [a-zA-Z0-9.~_-]) out+="$c" ;; *) printf -v hex '%%%02X' "'$c"; out+="$hex" ;; esac
  done
  printf '%s' "$out"
}
html_escape() {
  local s="$1"
  s=${s//&/&amp;}; s=${s//</&lt;}; s=${s//>/&gt;}; s=${s//\"/&quot;}; s=${s//\'/&#39;}
  printf '%s' "$s"
}

js_string() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//</\\u003C}
  s=${s//>/\\u003E}
  s=${s//&/\\u0026}
  printf '"%s"' "$s"
}
query_value() {
  local key="$1" qs="${2:-${QUERY_STRING:-}}" pair k v
  IFS='&' read -ra pairs <<< "$qs"
  for pair in "${pairs[@]}"; do
    k="${pair%%=*}"; v="${pair#*=}"
    if [[ "$(url_decode "$k")" == "$key" ]]; then url_decode "$v"; return 0; fi
  done
  return 1
}
form_value() { query_value "$1" "$2"; }
form_values() {
  local key="$1" body="$2" pair k v
  IFS='&' read -ra pairs <<< "$body"
  for pair in "${pairs[@]}"; do
    k="${pair%%=*}"; v="${pair#*=}"
    [[ "$(url_decode "$k")" == "$key" ]] && printf '%s\n' "$(url_decode "$v")"
  done
}
cookie_value() {
  local key="$1" cookies="${HTTP_COOKIE:-}" part k v
  IFS=';' read -ra parts <<< "$cookies"
  for part in "${parts[@]}"; do
    part="${part#${part%%[![:space:]]*}}"; k="${part%%=*}"; v="${part#*=}"
    [[ "$k" == "$key" ]] && { printf '%s' "$v"; return 0; }
  done
  return 1
}
read_text_body() {
  local length="${CONTENT_LENGTH:-0}" body=""
  [[ "$length" =~ ^[0-9]+$ ]] || length=0
  if (( length > 0 )); then IFS= read -r -N "$length" body || true; fi
  printf '%s' "$body"
}

web_t() {
  local key="$1" lang="${2:-en}"
  if [[ "$lang" == "el" ]]; then
    case "$key" in
      title) printf 'FFUAD Server' ;; files) printf 'Αρχεία' ;; search) printf 'Αναζήτηση' ;;
      all) printf 'Όλα' ;; folders) printf 'Φάκελοι' ;; documents) printf 'Έγγραφα' ;; images) printf 'Εικόνες' ;;
      videos) printf 'Βίντεο' ;; audio) printf 'Ήχος' ;; archives) printf 'Συμπιεσμένα' ;; code) printf 'Κώδικας' ;;
      apps) printf 'Εφαρμογές' ;; other) printf 'Άλλα' ;; upload) printf 'Μεταφόρτωση' ;; new_folder) printf 'Νέος φάκελος' ;;
      folder_name) printf 'Όνομα φακέλου' ;; create) printf 'Δημιουργία' ;; name) printf 'Όνομα' ;; type) printf 'Τύπος' ;;
      size) printf 'Μέγεθος' ;; modified) printf 'Τροποποιήθηκε' ;; actions) printf 'Ενέργειες' ;; open) printf 'Άνοιγμα' ;;
      download) printf 'Λήψη' ;; details) printf 'Λεπτομέρειες' ;; move) printf 'Μετακίνηση/Μετονομασία' ;; delete) printf 'Διαγραφή' ;;
      selected_delete) printf 'Διαγραφή επιλεγμένων' ;; empty) printf 'Δεν βρέθηκαν στοιχεία.' ;; root) printf 'Ρίζα' ;;
      current_folder) printf 'Τρέχων φάκελος' ;; password) printf 'Κωδικός διακομιστή' ;; login) printf 'Σύνδεση διαχειριστή' ;;
      login_help) printf 'Πληκτρολόγησε τον κωδικό του διακομιστή για πλήρη διαχείριση.' ;; wrong_password) printf 'Λανθασμένος κωδικός.' ;;
      access_title) printf 'Επιλογή πρόσβασης' ;; access_help) printf 'Επίλεξε πώς θέλεις να ανοίξεις αυτόν τον διακομιστή.' ;;
      admin_login) printf 'Σύνδεση ως διαχειριστής' ;; admin_login_help) printf 'Ο διαχειριστής μπορεί να μεταφορτώνει, να δημιουργεί, να μετακινεί, να μετονομάζει και να διαγράφει.' ;;
      guest_continue) printf 'Συνέχεια ως επισκέπτης' ;; guest_help) printf 'Ο επισκέπτης μπορεί μόνο να περιηγείται, να αναζητά, να βλέπει λεπτομέρειες και να κατεβάζει.' ;;
      guest_mode) printf 'Επισκέπτης · Μόνο ανάγνωση' ;; admin_mode) printf 'Διαχειριστής' ;; permission_denied) printf 'Η λειτουργία είναι διαθέσιμη μόνο στον διαχειριστή.' ;;
      logout) printf 'Έξοδος' ;; light) printf 'Φωτεινό' ;; dark) printf 'Σκούρο' ;; language) printf 'Γλώσσα' ;;
      theme) printf 'Θέμα' ;; server) printf 'Διακομιστής' ;; protected) printf 'Προστατευμένος' ;; public) printf 'Χωρίς κωδικό' ;;
      confirm_upload) printf 'Να μεταφορτωθούν τα επιλεγμένα αρχεία;' ;; confirm_folder) printf 'Να δημιουργηθεί αυτός ο φάκελος;' ;;
      confirm_move) printf 'Να εφαρμοστεί η μετακίνηση ή μετονομασία;' ;; confirm_delete) printf 'Οριστική διαγραφή αυτού του στοιχείου; Η ενέργεια δεν αναιρείται.' ;;
      confirm_bulk) printf 'Οριστική διαγραφή όλων των επιλεγμένων στοιχείων; Η ενέργεια δεν αναιρείται.' ;;
      confirm_theme) printf 'Να αλλάξει το θέμα εμφάνισης;' ;; confirm_language) printf 'Να αλλάξει η γλώσσα εμφάνισης;' ;;
      confirm_logout) printf 'Να αποσυνδεθείς από αυτή τη συνεδρία;' ;; upload_done) printf 'Η μεταφόρτωση ολοκληρώθηκε.' ;;
      folder_done) printf 'Ο φάκελος δημιουργήθηκε.' ;; move_done) printf 'Το στοιχείο μετακινήθηκε ή μετονομάστηκε.' ;;
      delete_done) printf 'Το στοιχείο διαγράφηκε.' ;; bulk_done) printf 'Τα επιλεγμένα στοιχεία διαγράφηκαν.' ;;
      action_failed) printf 'Η ενέργεια απέτυχε.' ;; invalid_path) printf 'Μη έγκυρη ή μη ασφαλής διαδρομή.' ;;
      already_exists) printf 'Υπάρχει ήδη στοιχείο με αυτό το όνομα.' ;; too_large) printf 'Το αρχείο υπερβαίνει το όριο των 333 MB.' ;;
      destination) printf 'Φάκελος προορισμού (σχετική διαδρομή)' ;; new_name) printf 'Νέο όνομα' ;; save) printf 'Αποθήκευση' ;;
      back) printf 'Πίσω' ;; location) printf 'Τοποθεσία' ;; created) printf 'Δημιουργήθηκε' ;; mime) printf 'Τύπος MIME' ;;
      category) printf 'Κατηγορία' ;; checksum) printf 'SHA-256' ;; calculate) printf 'Υπολογισμός' ;; entry) printf 'Στοιχείο' ;;
      upload_hint) printf 'Επίλεξε πολλά αρχεία. Μεταφορτώνονται ένα-ένα με ένδειξη προόδου.' ;;
      no_password_warning) printf 'Αυτός ο διακομιστής δεν έχει κωδικό διαχειριστή. Όποιος έχει σύνδεσμο μπορεί να επιλέξει πλήρη πρόσβαση διαχειριστή.' ;;
      session_links) printf 'Οι σύνδεσμοι αυτής της συνεδρίας εμφανίζονται στο τερματικό.' ;;
      search_placeholder) printf 'Αναζήτηση ονόματος αρχείου ή φακέλου…' ;; choose_files) printf 'Επιλογή αρχείων' ;;
      upload_progress) printf 'Μεταφόρτωση' ;; file_label) printf 'Αρχείο' ;; folder_label) printf 'Φάκελος' ;;
      *) printf '%s' "$key" ;;
    esac
  else
    case "$key" in
      title) printf 'FFUAD Server' ;; files) printf 'Files' ;; search) printf 'Search' ;;
      all) printf 'All' ;; folders) printf 'Folders' ;; documents) printf 'Documents' ;; images) printf 'Images' ;;
      videos) printf 'Videos' ;; audio) printf 'Audio' ;; archives) printf 'Archives' ;; code) printf 'Code' ;;
      apps) printf 'Applications' ;; other) printf 'Other' ;; upload) printf 'Upload' ;; new_folder) printf 'New folder' ;;
      folder_name) printf 'Folder name' ;; create) printf 'Create' ;; name) printf 'Name' ;; type) printf 'Type' ;;
      size) printf 'Size' ;; modified) printf 'Modified' ;; actions) printf 'Actions' ;; open) printf 'Open' ;;
      download) printf 'Download' ;; details) printf 'Details' ;; move) printf 'Move/Rename' ;; delete) printf 'Delete' ;;
      selected_delete) printf 'Delete selected' ;; empty) printf 'No matching entries were found.' ;; root) printf 'Root' ;;
      current_folder) printf 'Current folder' ;; password) printf 'Server password' ;; login) printf 'Administrator login' ;;
      login_help) printf 'Enter the server password for full management access.' ;; wrong_password) printf 'Incorrect password.' ;;
      access_title) printf 'Choose access' ;; access_help) printf 'Choose how you want to open this server.' ;;
      admin_login) printf 'Log in as administrator' ;; admin_login_help) printf 'Administrators can upload, create, move, rename, and delete files and folders.' ;;
      guest_continue) printf 'Continue as guest' ;; guest_help) printf 'Guests can only browse, search, view details, and download.' ;;
      guest_mode) printf 'Guest · Read-only' ;; admin_mode) printf 'Administrator' ;; permission_denied) printf 'This operation is available only to the administrator.' ;;
      logout) printf 'Exit' ;; light) printf 'Light' ;; dark) printf 'Dark' ;; language) printf 'Language' ;;
      theme) printf 'Theme' ;; server) printf 'Server' ;; protected) printf 'Protected' ;; public) printf 'No password' ;;
      confirm_upload) printf 'Upload the selected files?' ;; confirm_folder) printf 'Create this folder?' ;;
      confirm_move) printf 'Apply this move or rename?' ;; confirm_delete) printf 'Permanently delete this entry? This cannot be undone.' ;;
      confirm_bulk) printf 'Permanently delete every selected entry? This cannot be undone.' ;;
      confirm_theme) printf 'Change the display theme?' ;; confirm_language) printf 'Change the display language?' ;;
      confirm_logout) printf 'Log out of this session?' ;; upload_done) printf 'Upload completed.' ;;
      folder_done) printf 'Folder created.' ;; move_done) printf 'Entry moved or renamed.' ;;
      delete_done) printf 'Entry deleted.' ;; bulk_done) printf 'Selected entries deleted.' ;;
      action_failed) printf 'The action failed.' ;; invalid_path) printf 'Invalid or unsafe path.' ;;
      already_exists) printf 'An entry with that name already exists.' ;; too_large) printf 'The file exceeds the 333 MB limit.' ;;
      destination) printf 'Destination folder (relative path)' ;; new_name) printf 'New name' ;; save) printf 'Save' ;;
      back) printf 'Back' ;; location) printf 'Location' ;; created) printf 'Created' ;; mime) printf 'MIME type' ;;
      category) printf 'Category' ;; checksum) printf 'SHA-256' ;; calculate) printf 'Calculate' ;; entry) printf 'Entry' ;;
      upload_hint) printf 'Select multiple files. They upload one at a time with progress.' ;;
      no_password_warning) printf 'This server has no administrator password. Anyone with a link can choose full administrator access.' ;;
      session_links) printf 'This session’s links are displayed in the terminal.' ;;
      search_placeholder) printf 'Search file or folder names…' ;; choose_files) printf 'Choose files' ;;
      upload_progress) printf 'Uploading' ;; file_label) printf 'File' ;; folder_label) printf 'Folder' ;;
      *) printf '%s' "$key" ;;
    esac
  fi
}

human_size() {
  local bytes="${1:-0}"
  awk -v b="$bytes" 'BEGIN { split("B KB MB GB TB",u," "); i=1; while(b>=1024 && i<5){b/=1024;i++} if(i==1) printf "%d %s",b,u[i]; else printf "%.1f %s",b,u[i] }'
}
format_epoch() {
  local e="${1:-0}"
  [[ "$e" =~ ^-?[0-9]+$ ]] || e=0
  if (( e > 0 )); then date -d "@$e" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || printf '-'; else printf '-'; fi
}
entry_category() {
  local path="$1" ext
  [[ -d "$path" ]] && { printf 'folders'; return; }
  ext=".${path##*.}"; ext="${ext,,}"
  [[ "$path" == "$ext" ]] && ext=""
  case "$ext" in
    .pdf|.txt|.md|.rtf|.doc|.docx|.odt|.xls|.xlsx|.ods|.ppt|.pptx|.odp|.csv|.epub) printf 'documents' ;;
    .jpg|.jpeg|.png|.gif|.webp|.bmp|.svg|.ico|.heic) printf 'images' ;;
    .mp4|.mkv|.webm|.avi|.mov|.m4v|.3gp|.mpeg|.mpg) printf 'videos' ;;
    .mp3|.wav|.flac|.ogg|.m4a|.aac|.opus|.wma) printf 'audio' ;;
    .zip|.7z|.rar|.tar|.gz|.bz2|.xz|.tgz|.zst) printf 'archives' ;;
    .sh|.js|.ts|.html|.css|.json|.xml|.yaml|.yml|.java|.c|.h|.cpp|.hpp|.go|.rs|.php|.rb|.sql|.kt) printf 'code' ;;
    .apk|.aab|.deb|.rpm|.appimage|.exe|.msi|.dmg) printf 'apps' ;;
    *) printf 'other' ;;
  esac
}
category_label() { web_t "$1" "$LANG"; }

safe_abs_maybe() {
  local rel="${1#/}" normalized
  normalized="$(realpath -m -- "$ROOT_REAL/$rel")" || return 1
  [[ "$normalized" == "$ROOT_REAL" || "$normalized" == "$ROOT_REAL/"* ]] || return 1
  printf '%s' "$normalized"
}
safe_abs_existing() {
  local candidate actual
  candidate="$(safe_abs_maybe "$1")" || return 1
  [[ -e "$candidate" || -L "$candidate" ]] || return 1
  actual="$(realpath -e -- "$candidate" 2>/dev/null)" || return 1
  [[ "$actual" == "$ROOT_REAL" || "$actual" == "$ROOT_REAL/"* ]] || return 1
  printf '%s' "$candidate"
}
rel_from_abs() {
  local abs="$1"
  [[ "$abs" == "$ROOT_REAL" ]] && { printf ''; return; }
  printf '%s' "${abs#"$ROOT_REAL"/}"
}
valid_entry_name() { validate_name "$1"; }

make_session_token() {
  local role="${1:-guest}" expiry nonce sig secret
  [[ "$role" == "admin" || "$role" == "guest" ]] || role="guest"
  expiry=$(( $(now_epoch) + SESSION_SECONDS )); nonce="$(random_hex 12)"; secret="$(profile_get "$SERVER_ID" secret)"
  sig="$(sha256_text "$secret:$SERVER_ID:$role:$expiry:$nonce")"
  printf '%s.%s.%s.%s' "$role" "$expiry" "$nonce" "$sig"
}
verify_session_token() {
  local token="$1" role expiry nonce sig expected secret
  IFS='.' read -r role expiry nonce sig <<< "$token"
  [[ "$role" == "admin" || "$role" == "guest" ]] || return 1
  [[ "$expiry" =~ ^[0-9]+$ && -n "$nonce" && -n "$sig" ]] || return 1
  (( expiry >= $(now_epoch) )) || return 1
  secret="$(profile_get "$SERVER_ID" secret)"; expected="$(sha256_text "$secret:$SERVER_ID:$role:$expiry:$nonce")"
  [[ "$sig" == "$expected" ]] || return 1
  SESSION_ROLE="$role"
}
csrf_for_token() { sha256_text "csrf:$(profile_get "$SERVER_ID" secret):$1"; }

EXTRA_HEADERS=()
add_cookie() { EXTRA_HEADERS+=("Set-Cookie: $1"); }
status_text() { case "$1" in 200) printf '200 OK';; 302) printf '302 Found';; 400) printf '400 Bad Request';; 401) printf '401 Unauthorized';; 403) printf '403 Forbidden';; 404) printf '404 Not Found';; 409) printf '409 Conflict';; 413) printf '413 Payload Too Large';; 500) printf '500 Internal Server Error';; *) printf '%s' "$1";; esac; }
emit_headers() {
  local code="$1" type="$2" h
  printf 'Status: %s\r\n' "$(status_text "$code")"
  printf 'Content-Type: %s\r\n' "$type"
  printf 'Cache-Control: no-store\r\n'
  printf 'X-Content-Type-Options: nosniff\r\n'
  printf 'X-Frame-Options: DENY\r\n'
  printf "Content-Security-Policy: default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; img-src 'self' data:; object-src 'none'; base-uri 'none'; frame-ancestors 'none'\r\n"
  for h in "${EXTRA_HEADERS[@]}"; do printf '%s\r\n' "$h"; done
  printf '\r\n'
}
redirect_to() {
  local url="$1" h
  printf 'Status: 302 Found\r\nLocation: %s\r\nCache-Control: no-store\r\n' "$url"
  for h in "${EXTRA_HEADERS[@]}"; do printf '%s\r\n' "$h"; done
  printf '\r\n'
}
error_page() {
  local code="$1" message="$2"
  emit_headers "$code" 'text/html; charset=utf-8'
  printf '<!doctype html><meta charset="utf-8"><title>FFUAD</title><style>body{font-family:system-ui;background:#111827;color:#f9fafb;padding:3rem}.box{max-width:680px;margin:auto;background:#1f2937;padding:2rem;border-radius:18px}a{color:#93c5fd}</style><div class="box"><h1>FFUAD</h1><p>%s</p><p><a href="%s">%s</a></p></div>' "$(html_escape "$message")" "$BASE_URL" "$(web_t back "$LANG")"
}

page_head() {
  local title="$1" body_class theme_label theme_target theme_confirm lang_target lang_confirm nav_action
  [[ "$THEME" == "light" ]] && { body_class="light"; theme_label="$(web_t dark "$LANG")"; theme_target="dark"; } || { body_class="dark"; theme_label="$(web_t light "$LANG")"; theme_target="light"; }
  [[ "$LANG" == "el" ]] && lang_target="en" || lang_target="el"
  theme_confirm="$(html_escape "$(web_t confirm_theme "$LANG")")"; lang_confirm="$(html_escape "$(web_t confirm_language "$LANG")")"
  [[ "$AUTHENTICATED" == "yes" ]] && nav_action="browse" || nav_action="access"
  cat <<HTML
<!doctype html><html lang="$LANG"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$(html_escape "$title")</title>
<style>
:root{--bg:#0b1020;--panel:#151c2f;--panel2:#1d2740;--text:#f5f7ff;--muted:#aeb9d4;--line:#33405d;--accent:#7c9cff;--danger:#ff6b75;--ok:#5fd69b;--shadow:0 16px 50px rgba(0,0,0,.28)}
body.light{--bg:#f4f7fb;--panel:#fff;--panel2:#edf2f8;--text:#172033;--muted:#61708a;--line:#d5deea;--accent:#315ed1;--danger:#c83242;--ok:#16885d;--shadow:0 16px 45px rgba(30,55,90,.12)}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font-family:system-ui,-apple-system,"Segoe UI",sans-serif;min-height:100vh}a{color:inherit;text-decoration:none}button,input,select{font:inherit}.top{position:sticky;top:0;z-index:5;background:color-mix(in srgb,var(--bg) 88%,transparent);backdrop-filter:blur(14px);border-bottom:1px solid var(--line)}.topin{max-width:1450px;margin:auto;padding:14px 20px;display:flex;gap:14px;align-items:center;justify-content:space-between}.brand{font-weight:850;letter-spacing:.4px;display:flex;align-items:center;gap:10px}.logo{width:38px;height:38px;border-radius:12px;display:grid;place-items:center;background:var(--accent);color:#fff}.toolbar{display:flex;gap:8px;align-items:center;flex-wrap:wrap}.btn{display:inline-flex;align-items:center;justify-content:center;gap:7px;border:1px solid var(--line);background:var(--panel);color:var(--text);padding:9px 13px;border-radius:11px;cursor:pointer}.btn:hover{border-color:var(--accent)}.btn.primary{background:var(--accent);border-color:var(--accent);color:#fff}.btn.danger{border-color:color-mix(in srgb,var(--danger) 60%,var(--line));color:var(--danger)}.layout{max-width:1450px;margin:auto;padding:20px;display:grid;grid-template-columns:230px minmax(0,1fr);gap:18px}.card{background:var(--panel);border:1px solid var(--line);border-radius:17px;box-shadow:var(--shadow)}.side{padding:14px;height:max-content;position:sticky;top:88px}.side a{display:flex;padding:10px 12px;border-radius:10px;color:var(--muted);margin:2px 0}.side a.active,.side a:hover{background:var(--panel2);color:var(--text)}.main{min-width:0}.hero{padding:18px;margin-bottom:16px}.hero h1{font-size:1.35rem;margin:0 0 5px}.muted{color:var(--muted)}.notice{padding:12px 15px;border:1px solid var(--line);border-left:4px solid var(--ok);border-radius:11px;background:var(--panel2);margin:0 0 14px}.warning{border-left-color:#f0b429}.error{border-left-color:var(--danger)}.actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:15px}.search{display:flex;gap:8px;flex:1;min-width:240px}.input{width:100%;background:var(--panel2);border:1px solid var(--line);color:var(--text);padding:10px 12px;border-radius:10px}.tablewrap{overflow:auto}.table{width:100%;border-collapse:collapse;min-width:830px}.table th,.table td{padding:12px 13px;border-bottom:1px solid var(--line);text-align:left;vertical-align:middle}.table th{color:var(--muted);font-size:.83rem;text-transform:uppercase;letter-spacing:.05em}.table tr:hover td{background:color-mix(in srgb,var(--panel2) 50%,transparent)}.entryname{font-weight:650;max-width:420px;word-break:break-word}.rowactions{display:flex;gap:6px;flex-wrap:wrap}.small{font-size:.86rem;padding:7px 9px}.empty{padding:40px;text-align:center;color:var(--muted)}.modalcard{max-width:760px;margin:40px auto;padding:22px}.formgrid{display:grid;gap:14px}.field label{display:block;color:var(--muted);margin-bottom:6px}.details{display:grid;grid-template-columns:180px 1fr;gap:1px;background:var(--line);border:1px solid var(--line);border-radius:12px;overflow:hidden}.details>*{background:var(--panel);padding:11px}.details .key{color:var(--muted)}.progress{height:12px;background:var(--panel2);border-radius:999px;overflow:hidden;margin-top:10px}.progress>div{height:100%;width:0;background:var(--accent);transition:width .15s}.breadcrumbs{display:flex;gap:5px;flex-wrap:wrap;color:var(--muted);margin-top:8px}.breadcrumbs a:hover{color:var(--text)}.checkbox{width:18px;height:18px}.login{max-width:480px;margin:9vh auto;padding:25px}.login h1{margin-top:0}@media(max-width:850px){.layout{grid-template-columns:1fr;padding:12px}.side{position:static;display:flex;overflow:auto;gap:5px}.side a{white-space:nowrap}.topin{padding:10px 12px}.toolbar .hide-mobile{display:none}.modalcard{margin:15px}.details{grid-template-columns:125px 1fr}}
</style></head><body class="$body_class"><header class="top"><div class="topin"><div class="brand"><span class="logo">▦</span><span>FFUAD</span></div><div class="toolbar">
<a class="btn confirm-link" data-confirm="$theme_confirm" href="$BASE_URL?action=$nav_action&amp;theme=$theme_target">◐ $theme_label</a>
<a class="btn confirm-link" data-confirm="$lang_confirm" href="$BASE_URL?action=$nav_action&amp;lang=$lang_target">🌐 ${lang_target^^}</a>
HTML
  if [[ "$AUTHENTICATED" == "yes" ]]; then
    if [[ "$SESSION_ROLE" == "admin" ]]; then
      printf '<span class="btn">%s</span>' "$(html_escape "$(web_t admin_mode "$LANG")")"
    else
      printf '<span class="btn">%s</span><a class="btn primary" href="%s?action=admin_login">%s</a>' "$(html_escape "$(web_t guest_mode "$LANG")")" "$BASE_URL" "$(web_t admin_login "$LANG")"
    fi
    printf '<a class="btn danger confirm-link" data-confirm="%s" href="%s?action=logout">%s</a>' "$(html_escape "$(web_t confirm_logout "$LANG")")" "$BASE_URL" "$(web_t logout "$LANG")"
  fi
  printf '</div></div></header>'
}
page_foot() {
  cat <<'HTML'
<script>
document.querySelectorAll('.confirm-link').forEach(a=>a.addEventListener('click',e=>{if(!confirm(a.dataset.confirm||'Confirm?'))e.preventDefault()}));
document.querySelectorAll('form[data-confirm]').forEach(f=>f.addEventListener('submit',e=>{if(!confirm(f.dataset.confirm||'Confirm?'))e.preventDefault()}));
</script></body></html>
HTML
}

current_url_for_browse() {
  local path="${1:-}" category="${2:-all}" q="${3:-}"
  printf '%s?action=browse&path=%s&category=%s&q=%s' "$BASE_URL" "$(url_encode "$path")" "$(url_encode "$category")" "$(url_encode "$q")"
}

sidebar_html() {
  local current_path="$1" current_cat="$2" key label cls
  printf '<aside class="card side">'
  for key in all folders documents images videos audio archives code apps other; do
    [[ "$key" == "$current_cat" ]] && cls="active" || cls=""
    label="$(web_t "$key" "$LANG")"
    printf '<a class="%s" href="%s">%s</a>' "$cls" "$(current_url_for_browse "$current_path" "$key" "")" "$(html_escape "$label")"
  done
  printf '</aside>'
}

breadcrumbs_html() {
  local rel="$1" accum="" part
  printf '<div class="breadcrumbs"><a href="%s">%s</a>' "$(current_url_for_browse '' "$CATEGORY" "$SEARCH_Q")" "$(web_t root "$LANG")"
  IFS='/' read -ra crumbs <<< "$rel"
  for part in "${crumbs[@]}"; do
    [[ -n "$part" ]] || continue
    [[ -n "$accum" ]] && accum+="/"
    accum+="$part"
    printf '<span>/</span><a href="%s">%s</a>' "$(current_url_for_browse "$accum" "$CATEGORY" "$SEARCH_Q")" "$(html_escape "$part")"
  done
  printf '</div>'
}

browse_page() {
  local requested_path abs message entry_path cat count=0 protected_label column_count
  requested_path="$(query_value path 2>/dev/null || true)"
  CATEGORY="$(query_value category 2>/dev/null || true)"; [[ -n "$CATEGORY" ]] || CATEGORY="all"
  case "$CATEGORY" in all|folders|documents|images|videos|audio|archives|code|apps|other) ;; *) CATEGORY="all" ;; esac
  SEARCH_Q="$(query_value q 2>/dev/null || true)"
  abs="$(safe_abs_existing "$requested_path" 2>/dev/null || true)"
  [[ -n "$abs" && -d "$abs" ]] || { error_page 400 "$(web_t invalid_path "$LANG")"; return; }
  requested_path="$(rel_from_abs "$abs")"
  message="$(query_value msg 2>/dev/null || true)"
  [[ -n "$PASSWORD_HASH" ]] && protected_label="$(web_t protected "$LANG")" || protected_label="$(web_t public "$LANG")"
  [[ "$SESSION_ROLE" == "admin" ]] && column_count=6 || column_count=5

  emit_headers 200 'text/html; charset=utf-8'
  page_head "$SERVER_NAME — $(web_t files "$LANG")"
  printf '<div class="layout">'; sidebar_html "$requested_path" "$CATEGORY"; printf '<main class="main">'
  printf '<section class="card hero"><h1>%s</h1><div class="muted">%s · %s</div>' "$(html_escape "$SERVER_NAME")" "$(html_escape "$protected_label")" "$(html_escape "$(web_t session_links "$LANG")")"
  breadcrumbs_html "$requested_path"
  printf '<div class="actions"><form class="search" method="get" action="%s"><input type="hidden" name="action" value="browse"><input type="hidden" name="path" value="%s"><input type="hidden" name="category" value="%s"><input class="input" type="search" name="q" value="%s" placeholder="%s"><button class="btn primary" type="submit">%s</button></form>' \
    "$BASE_URL" "$(html_escape "$requested_path")" "$(html_escape "$CATEGORY")" "$(html_escape "$SEARCH_Q")" "$(html_escape "$(web_t search_placeholder "$LANG")")" "$(web_t search "$LANG")"
  if [[ "$SESSION_ROLE" == "admin" ]]; then
    printf '<a class="btn" href="%s?action=new_folder&amp;path=%s">＋ %s</a>' "$BASE_URL" "$(url_encode "$requested_path")" "$(web_t new_folder "$LANG")"
    printf '<a class="btn" href="%s?action=upload_page&amp;path=%s">⬆ %s</a>' "$BASE_URL" "$(url_encode "$requested_path")" "$(web_t upload "$LANG")"
    printf '<button class="btn danger" id="bulkDelete" type="button">%s</button>' "$(web_t selected_delete "$LANG")"
  fi
  printf '</div></section>'
  if [[ -n "$message" ]]; then printf '<div class="notice">%s</div>' "$(html_escape "$(web_t "$message" "$LANG")")"; fi
  if [[ -z "$PASSWORD_HASH" ]]; then printf '<div class="notice warning">%s</div>' "$(html_escape "$(web_t no_password_warning "$LANG")")"; fi
  if [[ "$SESSION_ROLE" == "guest" ]]; then printf '<div class="notice warning">%s</div>' "$(html_escape "$(web_t guest_help "$LANG")")"; fi
  printf '<section class="card tablewrap"><table class="table"><thead><tr>'
  if [[ "$SESSION_ROLE" == "admin" ]]; then printf '<th><input id="selectAll" class="checkbox" type="checkbox"></th>'; fi
  printf '<th>%s</th><th>%s</th><th>%s</th><th>%s</th><th>%s</th></tr></thead><tbody>' \
    "$(web_t name "$LANG")" "$(web_t type "$LANG")" "$(web_t size "$LANG")" "$(web_t modified "$LANG")" "$(web_t actions "$LANG")"

  if [[ -n "$SEARCH_Q" ]]; then
    while IFS= read -r -d '' entry_path; do
      cat="$(entry_category "$entry_path")"
      [[ "$CATEGORY" == "all" || "$CATEGORY" == "$cat" ]] || continue
      render_entry_row "$entry_path" "$requested_path"; ((count++)) || true
      (( count >= 1000 )) && break
    done < <(find "$ROOT_REAL" -mindepth 1 -iname "*$SEARCH_Q*" -print0 2>/dev/null | sort -z)
  else
    while IFS= read -r -d '' entry_path; do
      cat="$(entry_category "$entry_path")"
      [[ "$CATEGORY" == "all" || "$CATEGORY" == "$cat" ]] || continue
      render_entry_row "$entry_path" "$requested_path"; ((count++)) || true
    done < <(find "$abs" -mindepth 1 -maxdepth 1 -print0 2>/dev/null | sort -z)
  fi
  if (( count == 0 )); then printf '<tr><td colspan="%s" class="empty">%s</td></tr>' "$column_count" "$(web_t empty "$LANG")"; fi
  printf '</tbody></table></section></main></div>'
  if [[ "$SESSION_ROLE" == "admin" ]]; then
    cat <<HTML
<script>
const csrf=$(js_string "$CSRF");
const base=$(js_string "$BASE_URL");
const bulkText=$(js_string "$BULK_CONFIRM");
document.getElementById('selectAll')?.addEventListener('change',e=>document.querySelectorAll('.entry-check').forEach(x=>x.checked=e.target.checked));
document.getElementById('bulkDelete')?.addEventListener('click',async()=>{
 const selected=[...document.querySelectorAll('.entry-check:checked')].map(x=>x.value);
 if(!selected.length){alert($(js_string "$SELECT_ONE"));return}
 if(!confirm(bulkText))return;
 const body=new URLSearchParams(); body.set('csrf',csrf); selected.forEach(v=>body.append('entry',v));
 const r=await fetch(base+'?action=bulk_delete',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body});
 if(r.ok) location.href=$(js_string "$RETURN_URL")+'&msg=bulk_done'; else alert(await r.text());
});
</script>
HTML
  fi
  page_foot
}

render_entry_row() {
  local entry_path="$1" current_path="$2" rel name cat bytes modified type_label icon enc_rel details_url download_url move_url
  rel="$(rel_from_abs "$entry_path")"; name="$(basename -- "$entry_path")"; cat="$(entry_category "$entry_path")"
  modified="$(stat -c %Y -- "$entry_path" 2>/dev/null || printf 0)"
  if [[ -d "$entry_path" ]]; then bytes="$(du -sb -- "$entry_path" 2>/dev/null | awk 'NR==1{print $1+0}')"; type_label="$(web_t folder_label "$LANG")"; icon="▣"; else bytes="$(stat -c %s -- "$entry_path" 2>/dev/null || printf 0)"; type_label="$(web_t file_label "$LANG")"; icon="▤"; fi
  enc_rel="$(url_encode "$rel")"
  details_url="$BASE_URL?action=details&entry=$enc_rel"; download_url="$BASE_URL?action=download&entry=$enc_rel"; move_url="$BASE_URL?action=move_form&entry=$enc_rel"
  printf '<tr>'
  if [[ "$SESSION_ROLE" == "admin" ]]; then printf '<td><input class="checkbox entry-check" type="checkbox" value="%s"></td>' "$(html_escape "$rel")"; fi
  printf '<td><div class="entryname">%s %s</div>' "$icon" "$(html_escape "$name")"
  if [[ -n "$SEARCH_Q" ]]; then printf '<div class="muted small">%s</div>' "$(html_escape "$rel")"; fi
  printf '</td><td>%s</td><td>%s</td><td>%s</td><td><div class="rowactions">' "$(html_escape "$(category_label "$cat")")" "$(human_size "$bytes")" "$(format_epoch "$modified")"
  if [[ -d "$entry_path" ]]; then printf '<a class="btn small primary" href="%s">%s</a>' "$(current_url_for_browse "$rel" all "")" "$(web_t open "$LANG")"; fi
  printf '<a class="btn small" href="%s">%s</a><a class="btn small" href="%s">%s</a>' "$download_url" "$(web_t download "$LANG")" "$details_url" "$(web_t details "$LANG")"
  if [[ "$SESSION_ROLE" == "admin" ]]; then
    printf '<a class="btn small" href="%s">%s</a>' "$move_url" "$(web_t move "$LANG")"
    printf '<form method="post" action="%s?action=delete" data-confirm="%s"><input type="hidden" name="csrf" value="%s"><input type="hidden" name="entry" value="%s"><input type="hidden" name="return_path" value="%s"><button class="btn small danger" type="submit">%s</button></form>' \
      "$BASE_URL" "$(html_escape "$(web_t confirm_delete "$LANG")")" "$(html_escape "$CSRF")" "$(html_escape "$rel")" "$(html_escape "$current_path")" "$(web_t delete "$LANG")"
  fi
  printf '</div></td></tr>'
}

access_page() {
  emit_headers 200 'text/html; charset=utf-8'
  page_head "$SERVER_NAME — $(web_t access_title "$LANG")"
  printf '<main class="card login"><div class="brand"><span class="logo">▦</span>FFUAD</div><h1>%s</h1><p class="muted">%s</p>' "$(html_escape "$SERVER_NAME")" "$(web_t access_help "$LANG")"
  if [[ -z "$PASSWORD_HASH" ]]; then printf '<div class="notice warning">%s</div>' "$(html_escape "$(web_t no_password_warning "$LANG")")"; fi
  printf '<div class="formgrid"><div class="card" style="padding:16px"><h2>%s</h2><p class="muted">%s</p><a class="btn primary" href="%s?action=admin_login">%s</a></div>' "$(web_t admin_login "$LANG")" "$(web_t admin_login_help "$LANG")" "$BASE_URL" "$(web_t admin_login "$LANG")"
  printf '<div class="card" style="padding:16px"><h2>%s</h2><p class="muted">%s</p><a class="btn" href="%s?action=guest">%s</a></div></div></main>' "$(web_t guest_continue "$LANG")" "$(web_t guest_help "$LANG")" "$BASE_URL" "$(web_t guest_continue "$LANG")"
  page_foot
}

admin_login_page() {
  local error="${1:-}"
  emit_headers 200 'text/html; charset=utf-8'
  page_head "$SERVER_NAME — $(web_t login "$LANG")"
  printf '<main class="card login"><div class="brand"><span class="logo">▦</span>FFUAD</div><h1>%s</h1><p class="muted">%s</p>' "$(web_t admin_login "$LANG")" "$(web_t login_help "$LANG")"
  [[ -n "$error" ]] && printf '<div class="notice error">%s</div>' "$(html_escape "$error")"
  printf '<form class="formgrid" method="post" action="%s?action=admin_login"><div class="field"><label>%s</label><input class="input" type="password" name="password" required autofocus></div><button class="btn primary" type="submit">%s</button><a class="btn" href="%s?action=access">%s</a></form></main>' "$BASE_URL" "$(web_t password "$LANG")" "$(web_t admin_login "$LANG")" "$BASE_URL" "$(web_t back "$LANG")"
  page_foot
}

new_folder_page() {
  local path abs
  path="$(query_value path 2>/dev/null || true)"; abs="$(safe_abs_existing "$path" 2>/dev/null || true)"
  [[ -n "$abs" && -d "$abs" ]] || { error_page 400 "$(web_t invalid_path "$LANG")"; return; }
  emit_headers 200 'text/html; charset=utf-8'
  page_head "$(web_t new_folder "$LANG")"
  printf '<main class="card modalcard"><h1>%s</h1><p class="muted">%s: %s</p><form class="formgrid" method="post" action="%s?action=create_folder" data-confirm="%s"><input type="hidden" name="csrf" value="%s"><input type="hidden" name="path" value="%s"><div class="field"><label>%s</label><input class="input" name="name" required autofocus></div><div class="actions"><button class="btn primary" type="submit">%s</button><a class="btn" href="%s">%s</a></div></form></main>' \
    "$(web_t new_folder "$LANG")" "$(web_t current_folder "$LANG")" "$(html_escape "${path:-/}")" "$BASE_URL" "$(html_escape "$(web_t confirm_folder "$LANG")")" "$(html_escape "$CSRF")" "$(html_escape "$path")" "$(web_t folder_name "$LANG")" "$(web_t create "$LANG")" "$(current_url_for_browse "$path" all "")" "$(web_t back "$LANG")"
  page_foot
}

upload_page() {
  local path abs
  path="$(query_value path 2>/dev/null || true)"; abs="$(safe_abs_existing "$path" 2>/dev/null || true)"
  [[ -n "$abs" && -d "$abs" ]] || { error_page 400 "$(web_t invalid_path "$LANG")"; return; }
  emit_headers 200 'text/html; charset=utf-8'
  page_head "$(web_t upload "$LANG")"
  printf '<main class="card modalcard"><h1>%s</h1><p class="muted">%s</p><div class="field"><label>%s</label><input class="input" id="files" type="file" multiple></div><div class="actions"><button class="btn primary" id="uploadBtn">%s</button><a class="btn" href="%s">%s</a></div><div id="status" class="muted" style="margin-top:14px"></div><div class="progress"><div id="bar"></div></div></main>' \
    "$(web_t upload "$LANG")" "$(web_t upload_hint "$LANG")" "$(web_t choose_files "$LANG")" "$(web_t upload "$LANG")" "$(current_url_for_browse "$path" all "")" "$(web_t back "$LANG")"
  cat <<HTML
<script>
const files=document.getElementById('files'),btn=document.getElementById('uploadBtn'),bar=document.getElementById('bar'),status=document.getElementById('status');
btn.addEventListener('click',async()=>{
 const list=[...files.files]; if(!list.length)return;
 if(!confirm($(js_string "$UPLOAD_CONFIRM")))return;
 btn.disabled=true;
 for(let i=0;i<list.length;i++){
  const f=list[i]; status.textContent=$(js_string "$UPLOADING")+' '+(i+1)+'/'+list.length+': '+f.name;
  const url=$(js_string "$BASE_URL")+'?action=upload&path='+encodeURIComponent($(js_string "$UPLOAD_PATH"))+'&name='+encodeURIComponent(f.name)+'&csrf='+encodeURIComponent($(js_string "$CSRF"));
  const r=await fetch(url,{method:'POST',headers:{'Content-Type':'application/octet-stream'},body:f});
  if(!r.ok){alert(await r.text());btn.disabled=false;return}
  bar.style.width=Math.round(((i+1)/list.length)*100)+'%';
 }
 location.href=$(js_string "$UPLOAD_RETURN")+'&msg=upload_done';
});
</script>
HTML
  page_foot
}

move_form_page() {
  local rel abs name parent
  rel="$(query_value entry 2>/dev/null || true)"; abs="$(safe_abs_existing "$rel" 2>/dev/null || true)"
  [[ -n "$abs" && "$abs" != "$ROOT_REAL" ]] || { error_page 400 "$(web_t invalid_path "$LANG")"; return; }
  name="$(basename -- "$abs")"; parent="$(rel_from_abs "$(dirname -- "$abs")")"
  emit_headers 200 'text/html; charset=utf-8'
  page_head "$(web_t move "$LANG")"
  printf '<main class="card modalcard"><h1>%s</h1><p class="muted">%s: %s</p><form class="formgrid" method="post" action="%s?action=move" data-confirm="%s"><input type="hidden" name="csrf" value="%s"><input type="hidden" name="entry" value="%s"><div class="field"><label>%s</label><input class="input" name="destination" value="%s"></div><div class="field"><label>%s</label><input class="input" name="new_name" value="%s" required></div><div class="actions"><button class="btn primary" type="submit">%s</button><a class="btn" href="%s">%s</a></div></form></main>' \
    "$(web_t move "$LANG")" "$(web_t entry "$LANG")" "$(html_escape "$rel")" "$BASE_URL" "$(html_escape "$(web_t confirm_move "$LANG")")" "$(html_escape "$CSRF")" "$(html_escape "$rel")" "$(web_t destination "$LANG")" "$(html_escape "$parent")" "$(web_t new_name "$LANG")" "$(html_escape "$name")" "$(web_t save "$LANG")" "$(current_url_for_browse "$parent" all "")" "$(web_t back "$LANG")"
  page_foot
}

entry_details_page() {
  local rel abs name parent size modified created mime cat checksum="" checksum_param
  rel="$(query_value entry 2>/dev/null || true)"; abs="$(safe_abs_existing "$rel" 2>/dev/null || true)"
  [[ -n "$abs" ]] || { error_page 404 "$(web_t invalid_path "$LANG")"; return; }
  name="$(basename -- "$abs")"; parent="$(rel_from_abs "$(dirname -- "$abs")")"
  if [[ -d "$abs" ]]; then size="$(du -sb -- "$abs" 2>/dev/null | awk 'NR==1{print $1+0}')"; mime='inode/directory'; else size="$(stat -c %s -- "$abs" 2>/dev/null || printf 0)"; mime="$(file -b --mime-type -- "$abs" 2>/dev/null || printf 'application/octet-stream')"; fi
  modified="$(stat -c %Y -- "$abs" 2>/dev/null || printf 0)"; created="$(stat -c %W -- "$abs" 2>/dev/null || printf 0)"; cat="$(entry_category "$abs")"
  checksum_param="$(query_value checksum 2>/dev/null || true)"
  if [[ "$checksum_param" == "1" && -f "$abs" ]]; then checksum="$(sha256sum -- "$abs" | awk '{print $1}')"; fi
  emit_headers 200 'text/html; charset=utf-8'
  page_head "$(web_t details "$LANG") — $name"
  printf '<main class="card modalcard"><h1>%s</h1><div class="details">' "$(html_escape "$name")"
  printf '<div class="key">%s</div><div>%s</div>' "$(web_t location "$LANG")" "$(html_escape "$rel")"
  printf '<div class="key">%s</div><div>%s</div>' "$(web_t type "$LANG")" "$(html_escape "$(if [[ -d "$abs" ]]; then web_t folder_label "$LANG"; else web_t file_label "$LANG"; fi)")"
  printf '<div class="key">%s</div><div>%s</div>' "$(web_t category "$LANG")" "$(html_escape "$(category_label "$cat")")"
  printf '<div class="key">%s</div><div>%s</div>' "$(web_t size "$LANG")" "$(human_size "$size")"
  printf '<div class="key">%s</div><div>%s</div>' "$(web_t mime "$LANG")" "$(html_escape "$mime")"
  printf '<div class="key">%s</div><div>%s</div>' "$(web_t modified "$LANG")" "$(format_epoch "$modified")"
  printf '<div class="key">%s</div><div>%s</div>' "$(web_t created "$LANG")" "$(format_epoch "$created")"
  printf '<div class="key">%s</div><div>' "$(web_t checksum "$LANG")"
  if [[ -f "$abs" ]]; then
    if [[ -n "$checksum" ]]; then printf '<code>%s</code>' "$checksum"; else printf '<a class="btn small" href="%s?action=details&amp;entry=%s&amp;checksum=1">%s</a>' "$BASE_URL" "$(url_encode "$rel")" "$(web_t calculate "$LANG")"; fi
  else printf '—'; fi
  printf '</div></div><div class="actions"><a class="btn primary" href="%s?action=download&amp;entry=%s">%s</a><a class="btn" href="%s">%s</a></div></main>' "$BASE_URL" "$(url_encode "$rel")" "$(web_t download "$LANG")" "$(current_url_for_browse "$parent" all "")" "$(web_t back "$LANG")"
  page_foot
}

verify_csrf_value() { [[ "$1" == "$CSRF" && -n "$1" ]]; }

create_folder_action() {
  local body csrf path name dir dest
  body="$(read_text_body)"; csrf="$(form_value csrf "$body" 2>/dev/null || true)"
  verify_csrf_value "$csrf" || { error_page 403 "Security check failed"; return; }
  path="$(form_value path "$body" 2>/dev/null || true)"; name="$(form_value name "$body" 2>/dev/null || true)"
  valid_entry_name "$name" || { error_page 400 "$(web_t invalid_path "$LANG")"; return; }
  dir="$(safe_abs_existing "$path" 2>/dev/null || true)"; [[ -n "$dir" && -d "$dir" ]] || { error_page 400 "$(web_t invalid_path "$LANG")"; return; }
  dest="$(safe_abs_maybe "${path:+$path/}$name" 2>/dev/null || true)"; [[ -n "$dest" ]] || { error_page 400 "$(web_t invalid_path "$LANG")"; return; }
  [[ ! -e "$dest" ]] || { error_page 409 "$(web_t already_exists "$LANG")"; return; }
  mkdir -- "$dest" || { error_page 500 "$(web_t action_failed "$LANG")"; return; }
  redirect_to "$(current_url_for_browse "$path" all "")&msg=folder_done"
}

delete_action() {
  local body csrf rel return_path abs
  body="$(read_text_body)"; csrf="$(form_value csrf "$body" 2>/dev/null || true)"
  verify_csrf_value "$csrf" || { error_page 403 "Security check failed"; return; }
  rel="$(form_value entry "$body" 2>/dev/null || true)"; return_path="$(form_value return_path "$body" 2>/dev/null || true)"
  abs="$(safe_abs_existing "$rel" 2>/dev/null || true)"
  [[ -n "$abs" && "$abs" != "$ROOT_REAL" ]] || { error_page 400 "$(web_t invalid_path "$LANG")"; return; }
  rm -rf -- "$abs" || { error_page 500 "$(web_t action_failed "$LANG")"; return; }
  redirect_to "$(current_url_for_browse "$return_path" all "")&msg=delete_done"
}

bulk_delete_action() {
  local body csrf rel abs deleted=0
  body="$(read_text_body)"; csrf="$(form_value csrf "$body" 2>/dev/null || true)"
  verify_csrf_value "$csrf" || { emit_headers 403 'text/plain; charset=utf-8'; printf 'Security check failed'; return; }
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    abs="$(safe_abs_existing "$rel" 2>/dev/null || true)"
    [[ -n "$abs" && "$abs" != "$ROOT_REAL" ]] || continue
    rm -rf -- "$abs" && ((deleted++)) || true
  done < <(form_values entry "$body")
  emit_headers 200 'text/plain; charset=utf-8'; printf '%s' "$deleted"
}

move_action() {
  local body csrf rel destination new_name src dest_dir dest parent_rel
  body="$(read_text_body)"; csrf="$(form_value csrf "$body" 2>/dev/null || true)"
  verify_csrf_value "$csrf" || { error_page 403 "Security check failed"; return; }
  rel="$(form_value entry "$body" 2>/dev/null || true)"; destination="$(form_value destination "$body" 2>/dev/null || true)"; new_name="$(form_value new_name "$body" 2>/dev/null || true)"
  valid_entry_name "$new_name" || { error_page 400 "$(web_t invalid_path "$LANG")"; return; }
  src="$(safe_abs_existing "$rel" 2>/dev/null || true)"; dest_dir="$(safe_abs_existing "$destination" 2>/dev/null || true)"
  [[ -n "$src" && "$src" != "$ROOT_REAL" && -n "$dest_dir" && -d "$dest_dir" ]] || { error_page 400 "$(web_t invalid_path "$LANG")"; return; }
  dest="$dest_dir/$new_name"; dest="$(realpath -m -- "$dest")"
  [[ "$dest" == "$ROOT_REAL/"* ]] || { error_page 400 "$(web_t invalid_path "$LANG")"; return; }
  [[ ! -e "$dest" && ! -L "$dest" ]] || { error_page 409 "$(web_t already_exists "$LANG")"; return; }
  if [[ -d "$src" && "$dest" == "$src/"* ]]; then error_page 400 "$(web_t invalid_path "$LANG")"; return; fi
  mv -- "$src" "$dest" || { error_page 500 "$(web_t action_failed "$LANG")"; return; }
  parent_rel="$(rel_from_abs "$dest_dir")"
  redirect_to "$(current_url_for_browse "$parent_rel" all "")&msg=move_done"
}

unique_upload_path() {
  local dir="$1" name="$2" stem ext candidate n=2
  candidate="$dir/$name"
  [[ ! -e "$candidate" ]] && { printf '%s' "$candidate"; return; }
  if [[ "$name" == *.* && "$name" != .* ]]; then stem="${name%.*}"; ext=".${name##*.}"; else stem="$name"; ext=""; fi
  while [[ -e "$dir/${stem} (${n})${ext}" ]]; do ((n++)); done
  printf '%s' "$dir/${stem} (${n})${ext}"
}

upload_action() {
  local csrf path name dir dest tmp length actual
  csrf="$(query_value csrf 2>/dev/null || true)"; verify_csrf_value "$csrf" || { emit_headers 403 'text/plain; charset=utf-8'; printf 'Security check failed'; return; }
  path="$(query_value path 2>/dev/null || true)"; name="$(query_value name 2>/dev/null || true)"
  valid_entry_name "$name" || { emit_headers 400 'text/plain; charset=utf-8'; printf '%s' "$(web_t invalid_path "$LANG")"; return; }
  length="${CONTENT_LENGTH:-0}"; [[ "$length" =~ ^[0-9]+$ ]] || length=0
  (( length <= MAX_UPLOAD_BYTES )) || { emit_headers 413 'text/plain; charset=utf-8'; printf '%s' "$(web_t too_large "$LANG")"; return; }
  dir="$(safe_abs_existing "$path" 2>/dev/null || true)"; [[ -n "$dir" && -d "$dir" ]] || { emit_headers 400 'text/plain; charset=utf-8'; printf '%s' "$(web_t invalid_path "$LANG")"; return; }
  dest="$(unique_upload_path "$dir" "$name")"; tmp="$RUNTIME_DIR/upload-$(random_hex 8).part"
  cat > "$tmp"
  actual="$(stat -c %s -- "$tmp" 2>/dev/null || printf 0)"
  if (( actual > MAX_UPLOAD_BYTES )); then rm -f -- "$tmp"; emit_headers 413 'text/plain; charset=utf-8'; printf '%s' "$(web_t too_large "$LANG")"; return; fi
  mv -- "$tmp" "$dest" || { rm -f -- "$tmp"; emit_headers 500 'text/plain; charset=utf-8'; printf '%s' "$(web_t action_failed "$LANG")"; return; }
  emit_headers 200 'application/json; charset=utf-8'; printf '{"ok":true}'
}

safe_download_header_name() {
  local s="$1"; s=${s//$'\r'/}; s=${s//$'\n'/}; s=${s//\"/_}; printf '%s' "$s"
}

download_action() {
  local rel abs name send_path mime length tmp parent base encoded
  rel="$(query_value entry 2>/dev/null || true)"; abs="$(safe_abs_existing "$rel" 2>/dev/null || true)"
  [[ -n "$abs" && "$abs" != "$ROOT_REAL" ]] || { error_page 404 "$(web_t invalid_path "$LANG")"; return; }
  name="$(basename -- "$abs")"; send_path="$abs"; tmp=""
  if [[ -d "$abs" ]]; then
    command_exists zip || { error_page 500 'zip is required'; return; }
    tmp="$RUNTIME_DIR/download-$(random_hex 8).zip"; parent="$(dirname -- "$abs")"; base="$(basename -- "$abs")"
    (cd "$parent" && zip -qr "$tmp" "./$base") || { rm -f -- "$tmp"; error_page 500 "$(web_t action_failed "$LANG")"; return; }
    send_path="$tmp"; name="$name.zip"; mime='application/zip'
  else
    mime="$(file -b --mime-type -- "$send_path" 2>/dev/null || printf 'application/octet-stream')"
  fi
  length="$(stat -c %s -- "$send_path" 2>/dev/null || printf 0)"; encoded="$(url_encode "$name")"; name="$(safe_download_header_name "$name")"
  printf 'Status: 200 OK\r\nContent-Type: %s\r\nContent-Length: %s\r\nContent-Disposition: attachment; filename="%s"; filename*=UTF-8\x27\x27%s\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\r\n' "$mime" "$length" "$name" "$encoded"
  cat -- "$send_path"
  [[ -n "$tmp" ]] && rm -f -- "$tmp"
}

cgi_main() {
  SERVER_ID="${FFUAD_ACTIVE_PROFILE:-}"
  RUNTIME_DIR="${FFUAD_RUNTIME_DIR:-$RUNTIME_BASE/cgi-fallback}"
  BASE_URL="${SCRIPT_NAME:-/cgi-bin/ffuad}"
  EXTRA_HEADERS=()
  [[ -n "$SERVER_ID" && -f "$(profile_file "$SERVER_ID")" ]] || { LANG=en; AUTHENTICATED=no; SESSION_ROLE=""; error_page 404 'Server profile not found'; return; }
  mkdir -p "$RUNTIME_DIR"
  SERVER_NAME="$(profile_get "$SERVER_ID" name)"; ROOT_REAL="$(profile_get "$SERVER_ID" root)"; ROOT_REAL="$(realpath -m "$ROOT_REAL")"; mkdir -p "$ROOT_REAL"; ROOT_REAL="$(realpath -e "$ROOT_REAL")"
  PASSWORD_HASH="$(profile_get "$SERVER_ID" password_hash)"; PASSWORD_SALT="$(profile_get "$SERVER_ID" password_salt)"
  local profile_lang lang_q theme_q token action method body entered actual_hash
  profile_lang="$(profile_get "$SERVER_ID" language)"; [[ "$profile_lang" == "el" ]] || profile_lang="en"
  lang_q="$(query_value lang 2>/dev/null || true)"; theme_q="$(query_value theme 2>/dev/null || true)"
  LANG="$lang_q"; [[ "$LANG" == "en" || "$LANG" == "el" ]] || LANG="$(cookie_value FFUAD_LANG 2>/dev/null || true)"; [[ "$LANG" == "en" || "$LANG" == "el" ]] || LANG="$profile_lang"
  THEME="$theme_q"; [[ "$THEME" == "dark" || "$THEME" == "light" ]] || THEME="$(cookie_value FFUAD_THEME 2>/dev/null || true)"; [[ "$THEME" == "light" ]] || THEME="dark"
  [[ "$lang_q" == "en" || "$lang_q" == "el" ]] && add_cookie "FFUAD_LANG=$LANG; Path=/; Max-Age=31536000; SameSite=Strict"
  [[ "$theme_q" == "dark" || "$theme_q" == "light" ]] && add_cookie "FFUAD_THEME=$THEME; Path=/; Max-Age=31536000; SameSite=Strict"
  AUTH_COOKIE="FFUAD_AUTH_${SERVER_ID}"; token="$(cookie_value "$AUTH_COOKIE" 2>/dev/null || true)"
  AUTHENTICATED=no; SESSION_ROLE=""
  if [[ -n "$token" ]] && verify_session_token "$token"; then AUTHENTICATED=yes; fi
  action="$(query_value action 2>/dev/null || true)"; method="${REQUEST_METHOD:-GET}"
  if [[ -z "$action" ]]; then [[ "$AUTHENTICATED" == "yes" ]] && action="browse" || action="access"; fi

  if [[ "$action" == "logout" ]]; then
    add_cookie "$AUTH_COOKIE=deleted; Path=/; Max-Age=0; HttpOnly; SameSite=Strict"
    redirect_to "$BASE_URL?action=access"; return
  fi

  if [[ "$action" == "guest" ]]; then
    token="$(make_session_token guest)"; add_cookie "$AUTH_COOKIE=$token; Path=/; Max-Age=$SESSION_SECONDS; HttpOnly; SameSite=Strict"
    redirect_to "$BASE_URL?action=browse"; return
  fi

  if [[ "$action" == "admin_login" || "$action" == "login" ]]; then
    if [[ -z "$PASSWORD_HASH" ]]; then
      token="$(make_session_token admin)"; add_cookie "$AUTH_COOKIE=$token; Path=/; Max-Age=$SESSION_SECONDS; HttpOnly; SameSite=Strict"
      redirect_to "$BASE_URL?action=browse"; return
    fi
    if [[ "$method" == "POST" ]]; then
      body="$(read_text_body)"; entered="$(form_value password "$body" 2>/dev/null || true)"; actual_hash="$(hash_password "$PASSWORD_SALT" "$entered")"
      if [[ "$actual_hash" == "$PASSWORD_HASH" ]]; then
        token="$(make_session_token admin)"; add_cookie "$AUTH_COOKIE=$token; Path=/; Max-Age=$SESSION_SECONDS; HttpOnly; SameSite=Strict"
        redirect_to "$BASE_URL?action=browse"; return
      fi
      admin_login_page "$(web_t wrong_password "$LANG")"; return
    fi
    admin_login_page; return
  fi

  if [[ "$AUTHENTICATED" != "yes" ]]; then
    access_page; return
  fi

  CSRF="$(csrf_for_token "$token")"
  BULK_CONFIRM="$(web_t confirm_bulk "$LANG")"; SELECT_ONE="$(if [[ "$LANG" == el ]]; then printf 'Επίλεξε τουλάχιστον ένα στοιχείο.'; else printf 'Select at least one entry.'; fi)"
  UPLOAD_CONFIRM="$(web_t confirm_upload "$LANG")"; UPLOADING="$(web_t upload_progress "$LANG")"

  case "$action" in
    new_folder|upload_page|move_form|create_folder|delete|bulk_delete|move|upload)
      [[ "$SESSION_ROLE" == "admin" ]] || { error_page 403 "$(web_t permission_denied "$LANG")"; return; }
      ;;
  esac

  case "$action" in
    access) access_page ;;
    browse) RETURN_URL="$(current_url_for_browse "$(query_value path 2>/dev/null || true)" "$(query_value category 2>/dev/null || printf all)" "$(query_value q 2>/dev/null || true)")"; browse_page ;;
    new_folder) new_folder_page ;;
    upload_page) UPLOAD_PATH="$(query_value path 2>/dev/null || true)"; UPLOAD_RETURN="$(current_url_for_browse "$UPLOAD_PATH" all "")"; upload_page ;;
    move_form) move_form_page ;;
    details) entry_details_page ;;
    create_folder) [[ "$method" == POST ]] || { error_page 400 'POST required'; return; }; create_folder_action ;;
    delete) [[ "$method" == POST ]] || { error_page 400 'POST required'; return; }; delete_action ;;
    bulk_delete) [[ "$method" == POST ]] || { error_page 400 'POST required'; return; }; bulk_delete_action ;;
    move) [[ "$method" == POST ]] || { error_page 400 'POST required'; return; }; move_action ;;
    upload) [[ "$method" == POST ]] || { error_page 400 'POST required'; return; }; upload_action ;;
    download) download_action ;;
    *) error_page 404 'Unknown action' ;;
  esac
}

install_cloudflared_linux() {
  local arch url tmp target installer=()
  arch="$(uname -m)"
  case "$arch" in x86_64|amd64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; armv7l|armhf) arch=arm ;; *) return 1 ;; esac
  url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$arch"
  tmp="$(mktemp)"; curl -fL "$url" -o "$tmp" || { rm -f "$tmp"; return 1; }; chmod +x "$tmp"
  target="/usr/local/bin/cloudflared"
  if [[ -w "$(dirname "$target")" ]]; then mv "$tmp" "$target"; else command_exists sudo || { rm -f "$tmp"; return 1; }; sudo mv "$tmp" "$target"; fi
}

install_dependencies() {
  local lang="${1:-$(get_language)}"
  printf '%s\n' "$(trm installing "$lang")"
  if command_exists pkg; then
    pkg update -y
    pkg install -y bash busybox curl cloudflared tor coreutils findutils file zip openssl iproute2
  elif command_exists apt-get; then
    local sudo_cmd=()
    [[ "$(id -u)" -eq 0 ]] || sudo_cmd=(sudo)
    "${sudo_cmd[@]}" apt-get update
    "${sudo_cmd[@]}" apt-get install -y bash busybox curl tor coreutils findutils file zip openssl iproute2
    command_exists cloudflared || install_cloudflared_linux || true
  elif command_exists dnf; then
    local sudo_cmd=(); [[ "$(id -u)" -eq 0 ]] || sudo_cmd=(sudo)
    "${sudo_cmd[@]}" dnf install -y bash busybox curl tor coreutils findutils file zip openssl iproute
    command_exists cloudflared || install_cloudflared_linux || true
  else
    printf 'Unsupported package manager. Required: bash busybox curl cloudflared tor coreutils findutils file zip openssl.\n' >&2
    return 1
  fi
}

ensure_link_dependencies() {
  local missing=()
  command_exists cloudflared || missing+=(cloudflared)
  command_exists tor || missing+=(tor)
  ((${#missing[@]} == 0)) && return 0
  if command_exists pkg; then
    pkg update -y
    pkg install -y "${missing[@]}" || true
  elif command_exists apt-get; then
    local sudo_cmd=(); [[ "$(id -u)" -eq 0 ]] || sudo_cmd=(sudo)
    if ! command_exists tor; then "${sudo_cmd[@]}" apt-get update && "${sudo_cmd[@]}" apt-get install -y tor || true; fi
    command_exists cloudflared || install_cloudflared_linux || true
  fi
}

ensure_runtime_dependencies() {
  local missing=() cmd
  for cmd in busybox curl realpath find sort stat sha256sum file zip; do command_exists "$cmd" || missing+=("$cmd"); done
  if ((${#missing[@]})); then
    printf 'Missing dependencies: %s\n' "${missing[*]}" >&2
    if command_exists pkg; then install_dependencies "$(get_language)"; else return 1; fi
  fi
}

port_in_use() {
  local port="$1"
  if command_exists ss; then ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)$port$"; return; fi
  (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null
}
find_free_port() {
  local port="${1:-8080}"
  while (( port <= 9999 )); do port_in_use "$port" || { printf '%s' "$port"; return; }; ((port++)); done
  return 1
}
local_ip() {
  local ip
  ip="$(ip route get 1.1.1.1 2>/dev/null | awk '/src/{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
  [[ -n "$ip" ]] || ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  [[ -n "$ip" ]] || ip='127.0.0.1'
  printf '%s' "$ip"
}

cleanup_session() {
  trap - INT TERM EXIT
  local pid
  for pid in "${CLOUDFLARED_PID:-}" "${TOR_PID:-}" "${HTTPD_PID:-}"; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    kill "$pid" 2>/dev/null || true
  done
  sleep 0.2
  for pid in "${CLOUDFLARED_PID:-}" "${TOR_PID:-}" "${HTTPD_PID:-}"; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    kill -9 "$pid" 2>/dev/null || true
  done
  [[ -n "${SESSION_RUNTIME:-}" ]] && rm -rf -- "$SESSION_RUNTIME"
}

start_cloudflared_link() {
  local port="$1" log="$SESSION_RUNTIME/cloudflared.log"
  CLOUDFLARED_PID=""
  command_exists cloudflared || return 1
  : > "$log"
  cloudflared tunnel --url "http://127.0.0.1:$port" --no-autoupdate > "$log" 2>&1 &
  CLOUDFLARED_PID=$!
}

start_tor_link() {
  local port="$1" tor_base="$SESSION_RUNTIME/tor" data_dir hs_dir torrc log
  TOR_PID=""; TOR_HOSTNAME_FILE=""
  command_exists tor || return 1
  data_dir="$tor_base/data"; hs_dir="$tor_base/hidden-service"; torrc="$tor_base/torrc"; log="$tor_base/tor.log"
  mkdir -p "$data_dir" "$hs_dir"; chmod 700 "$tor_base" "$data_dir" "$hs_dir"
  cat > "$torrc" <<TORRC
DataDirectory $data_dir
SocksPort 0
ControlPort 0
Log notice stdout
HiddenServiceDir $hs_dir
HiddenServicePort 80 127.0.0.1:$port
TORRC
  TOR_HOSTNAME_FILE="$hs_dir/hostname"
  tor -f "$torrc" > "$log" 2>&1 &
  TOR_PID=$!
}

prepare_webroot() {
  local profile_id="$1" webroot="$SESSION_RUNTIME/www" wrapper="$SESSION_RUNTIME/www/cgi-bin/ffuad"
  mkdir -p "$webroot/cgi-bin"
  cat > "$webroot/index.html" <<'HTML'
<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>FFUAD</title><script>location.replace('/cgi-bin/ffuad')</script><a href="/cgi-bin/ffuad">Open FFUAD</a>
HTML
  {
    printf '#!/usr/bin/env bash\n'
    printf 'export FFUAD_CONFIG_DIR=%q\n' "$CONFIG_DIR"
    printf 'export FFUAD_ACTIVE_PROFILE=%q\n' "$profile_id"
    printf 'export FFUAD_RUNTIME_DIR=%q\n' "$SESSION_RUNTIME"
    printf 'exec %q --cgi\n' "$SCRIPT_PATH"
  } > "$wrapper"
  chmod +x "$wrapper"
  printf '%s' "$webroot"
}

wait_for_httpd() {
  local port="$1" deadline=$(( $(now_epoch) + 15 ))
  while (( $(now_epoch) < deadline )); do
    kill -0 "$HTTPD_PID" 2>/dev/null || return 1
    curl -sS -o /dev/null "http://127.0.0.1:$port/cgi-bin/ffuad" 2>/dev/null && return 0
    sleep 0.2
  done
  return 1
}

start_server_session() {
  local id="$1" lang name root port session_id webroot lan local_url localhost_url cf_url='' onion='' deadline cf_log protected
  profile_exists "$id" || { printf 'Unknown server profile: %s\n' "$id" >&2; return 1; }
  ensure_runtime_dependencies || return 1
  ensure_link_dependencies
  lang="$(get_language)"; name="$(profile_get "$id" name)"; root="$(profile_get "$id" root)"
  port=8080
  session_id="${id}-$(now_epoch)-$$-$(random_hex 4)"; SESSION_RUNTIME="$RUNTIME_BASE/$session_id"; mkdir -p "$SESSION_RUNTIME"; chmod 700 "$SESSION_RUNTIME"
  webroot="$(prepare_webroot "$id")"
  HTTPD_PID=''; CLOUDFLARED_PID=''; TOR_PID=''; TOR_HOSTNAME_FILE=''
  trap cleanup_session INT TERM EXIT

  printf '\n%s: %s\n' "$(trm selected "$lang")" "$name"
  printf '%s\n' "$(trm starting "$lang")"
  if [[ -z "$(profile_get "$id" password_hash)" ]]; then printf '%s\n' "$(trm passwordless_warning "$lang")"; fi

  local http_started=no
  while (( port <= 9999 )); do
    if port_in_use "$port"; then ((port++)); continue; fi
    : > "$SESSION_RUNTIME/httpd.log"
    busybox httpd -f -p "0.0.0.0:$port" -h "$webroot" > "$SESSION_RUNTIME/httpd.log" 2>&1 &
    HTTPD_PID=$!
    if wait_for_httpd "$port"; then http_started=yes; break; fi
    kill "$HTTPD_PID" 2>/dev/null || true
    wait "$HTTPD_PID" 2>/dev/null || true
    HTTPD_PID=''
    ((port++))
  done
  if [[ "$http_started" != yes ]]; then
    printf 'FFUAD HTTP server failed. Log: %s\n' "$SESSION_RUNTIME/httpd.log" >&2
    return 1
  fi

  local cf_active=no tor_active=no cf_done=no tor_done=no
  start_cloudflared_link "$port" && cf_active=yes || true
  start_tor_link "$port" && tor_active=yes || true
  [[ "$cf_active" == no ]] && cf_done=yes
  [[ "$tor_active" == no ]] && tor_done=yes
  cf_log="$SESSION_RUNTIME/cloudflared.log"; deadline=$(( $(now_epoch) + 180 ))
  while (( $(now_epoch) < deadline )); do
    if [[ "$cf_done" == no && -f "$cf_log" ]]; then
      cf_url="$(grep -Eo 'https://[A-Za-z0-9-]+\.trycloudflare\.com' "$cf_log" 2>/dev/null | head -n1 || true)"
      [[ -n "$cf_url" ]] && cf_done=yes
      if [[ -n "$CLOUDFLARED_PID" ]] && ! kill -0 "$CLOUDFLARED_PID" 2>/dev/null; then cf_done=yes; fi
    fi
    if [[ "$tor_done" == no && -n "$TOR_HOSTNAME_FILE" && -f "$TOR_HOSTNAME_FILE" ]]; then
      onion="$(tr -d '\r\n' < "$TOR_HOSTNAME_FILE")"; [[ "$onion" == *.onion ]] && tor_done=yes || onion=''
    fi
    if [[ "$tor_done" == no && -n "$TOR_PID" ]] && ! kill -0 "$TOR_PID" 2>/dev/null; then tor_done=yes; fi
    [[ "$cf_done" == yes && "$tor_done" == yes ]] && break
    sleep 0.25
  done

  lan="$(local_ip)"; local_url="http://$lan:$port"; localhost_url="http://127.0.0.1:$port"
  printf '\n%s [%s]\n' "$APP_NAME" "$name"
  printf '%-14s %s\n' "$(trm local "$lang"):" "$local_url"
  printf '%-14s %s\n' "$(trm localhost "$lang"):" "$localhost_url"
  printf '%-14s %s\n' "$(trm cloudflare "$lang"):" "${cf_url:-$(trm unavailable "$lang")}"
  local tor_url
  if [[ -n "$onion" ]]; then tor_url="http://$onion"; else tor_url="$(trm unavailable "$lang")"; fi
  printf '%-14s %s\n' "$(trm tor "$lang"):" "$tor_url"
  printf '\n%s\n' "$(trm stop_hint "$lang")"
  printf 'Session: %s\nLogs: %s\n' "$session_id" "$SESSION_RUNTIME"

  if command_exists termux-open-url; then termux-open-url "$localhost_url" >/dev/null 2>&1 || true; elif command_exists xdg-open; then xdg-open "$localhost_url" >/dev/null 2>&1 || true; fi
  while kill -0 "$HTTPD_PID" 2>/dev/null; do sleep 1; done
}

change_language() {
  local current choice secret
  current="$(get_language)"; secret="$(cfg_get "$GLOBAL_FILE" admin_secret)"
  printf '1) English\n2) Ελληνικά\n'; read -r -p '> ' choice || true
  case "$choice" in 1) write_global en "$secret" ;; 2) write_global el "$secret" ;; *) return 1 ;; esac
}

manager_menu() {
  local lang choice id
  while :; do
    lang="$(get_language)"
    printf '\n=== %s ===\n' "$(trm title "$lang")"
    printf '1) %s\n2) %s\n3) %s\n4) %s\n5) %s\n6) %s\n7) %s\n8) %s\n0) %s\n' \
      "$(trm menu_start "$lang")" "$(trm menu_create "$lang")" "$(trm menu_edit "$lang")" "$(trm menu_delete "$lang")" \
      "$(trm menu_list "$lang")" "$(trm menu_language "$lang")" "$(trm menu_password "$lang")" "$(trm menu_install "$lang")" "$(trm menu_exit "$lang")"
    read -r -p "$(trm choose "$lang"): " choice || return 0
    case "$choice" in
      1) id="$(select_profile "$lang")" && start_server_session "$id" ;;
      2) create_server "$lang" ;;
      3) edit_server "$lang" ;;
      4) delete_server "$lang" ;;
      5) list_servers ;;
      6) change_language ;;
      7) printf '%s: %s\n' "$(trm admin_password "$lang")" "$(cfg_get "$GLOBAL_FILE" admin_secret)" ;;
      8) install_dependencies "$lang" ;;
      0) return 0 ;;
      *) printf '%s\n' "$(trm invalid "$lang")" ;;
    esac
  done
}

show_help() {
  cat <<'EOF'
FFUAD Server

  ./ffuad.sh                  Open the interactive server manager
  ./ffuad.sh --start          Choose a profile, then generate Local + Cloudflare + Tor links
  ./ffuad.sh --start ID       Start one specific profile in this terminal session
  ./ffuad.sh --create         Create a server profile
  ./ffuad.sh --edit           Edit a server profile
  ./ffuad.sh --delete         Delete a server profile
  ./ffuad.sh --list-servers   List profiles
  ./ffuad.sh --show-password  Show the local administrator password
  ./ffuad.sh --install        Install Termux/Linux dependencies

Run the script in separate Termux sessions to expose different server profiles simultaneously.
EOF
}

main_dispatch() {
  if [[ "${1:-}" == "--cgi" ]]; then cgi_main; return; fi
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then show_help; return; fi
  first_run_setup
  local lang id
  lang="$(get_language)"
  case "${1:-}" in
    --install) install_dependencies "$lang" ;;
    --create) create_server "$lang" ;;
    --edit) edit_server "$lang" ;;
    --delete) delete_server "$lang" ;;
    --list-servers) list_servers ;;
    --show-password) printf '%s\n' "$(cfg_get "$GLOBAL_FILE" admin_secret)" ;;
    --start)
      if [[ -n "${2:-}" ]]; then id="$2"; else id="$(select_profile "$lang")" || exit 1; fi
      start_server_session "$id"
      ;;
    '') manager_menu ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; show_help; return 2 ;;
  esac
}

main_dispatch "$@"
