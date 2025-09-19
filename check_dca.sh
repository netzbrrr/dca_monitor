#!/usr/bin/env bash

#----------------------------------------------------------------------
# Script: DCA Monitor
# Purpose: Automated periodical check to see if Myanmar DCA has published new
#          data for total number of passengers travelling inside and to/from
#          Myanmar by airplane, and send a notification to subscribers of the
#          NTFY topic "DCA_Data_Update".
# Timezone: Myanmar Standard Time (MMT, UTC+6:30)
#----------------------------------------------------------------------

set -euo pipefail

# === Exit Codes & Exception Handling ===
# 0–19: Success, 20+: Errors
EXIT_SUCCESS_INITIALIZED=0   # ran successfully, no prior hash
EXIT_SUCCESS_NOCHANGE=1      # ran successfully, no change detected
EXIT_SUCCESS_CHANGE=2        # ran successfully, change detected
EXIT_NO_TEXTMATCH_FOUND=20   # no matching $CHECK_YEAR in HTML
EXIT_PDF_DOWNLOAD_FAILED=21  # PDF could not be downloaded
EXIT_NO_PDF_FOUND=22         # no PDF file found
EXIT_ENV_MISSING=23          # no .env and required vars not present; template created

exit_with_message() {
  local code="$1"; shift
  printf 'Exit %s: %s\n' "$code" "$*" >&2
  exit "$code"
}

# --- Environment & Timezone ---
export TZ="${TZ:-Asia/Yangon}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_PATH="$SCRIPT_DIR/.env"

# Detect Docker so we don't force .env inside containers
is_docker() {
  [[ -f "/.dockerenv" ]] && return 0
  grep -qE '(docker|containerd|kubepods)' /proc/1/cgroup 2>/dev/null && return 0
  return 1
}

# Try to load .env on bare metal; in Docker, rely on env vars
if ! is_docker; then
  if [[ -f "$ENV_PATH" ]]; then
    set -a; source "$ENV_PATH"; set +a
  else
    # Create template .env for convenience
    cat > "$ENV_PATH" <<'EOF'
# .env for DCA Monitor (do NOT commit this file)
# Fill in the values and save.

# Required:
CHAT_WEBHOOK=
NTFY_URL=
CHECK_YEAR=

# Optional:
# TZ=Asia/Yangon
EOF
    # Only exit if required vars are still missing from the process env
    if [[ -z "${CHAT_WEBHOOK:-}" || -z "${NTFY_URL:-}" || -z "${CHECK_YEAR:-}" ]]; then
      exit_with_message "$EXIT_ENV_MISSING" "No .env file found. Template created at $ENV_PATH"
    fi
  fi
else
  echo "[env] Docker detected; using container environment variables."
fi

# Validate required env vars
: "${CHAT_WEBHOOK:?❌ CHAT_WEBHOOK environment variable is not set. Exiting.}"
: "${NTFY_URL:?❌ NTFY_URL environment variable is not set. Exiting.}"
: "${CHECK_YEAR:?❌ CHECK_YEAR environment variable is not set. Exiting.}"

# === Configuration ===
URL="https://dcamyanmar.com/dcadca/index.php?option=com_content&view=article&id=29"
OUTPUT_DIR="$SCRIPT_DIR/output"
LOG_DIR="$SCRIPT_DIR/logs"
TMP_HTML="$OUTPUT_DIR/dca_tmp.html"
TMP_HTML_SECTION="$OUTPUT_DIR/dca_section_tmp.html"
PDF_FILE="$OUTPUT_DIR/latest.pdf"
OLD_HASH_FILE="$OUTPUT_DIR/pdf_hash.txt"
LOG_FILE="$LOG_DIR/change_log.txt"
NTFY_TOPIC="DCA_Data_Update"

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

#echo "📂 Script directory: $SCRIPT_DIR"
#echo "📁 Output directory: $OUTPUT_DIR"
#echo "📝 Log directory: $LOG_DIR"

# === Script Start ===

# 1) Fetch page
curl -fsSL -A "Mozilla/5.0" "$URL" -o "$TMP_HTML"

echo "URL="$URL
echo "HTML Temp="$TMP_HTML

# 2) Extract relevant section
SECTION_HTML=$(awk '/<div class="text-download">/,/<\/div>/' "$TMP_HTML")
printf "%s\n" "$SECTION_HTML" > "$TMP_HTML_SECTION"

# 3) Find the text that matches the check year (e.g., 2025 or 2025-MAY)
TEXT_MATCH=$(echo "$SECTION_HTML" | gawk -v year="$CHECK_YEAR" '
  BEGIN { IGNORECASE=1 }
  match($0, ">" year "(-[A-Za-z]{3})?</a>", m) {
    # m[0] = ">2025-MAY</a>" or ">2025</a>"
    gsub(/<\/?[^>]+>/, "", m[0]);  # strip tags
    gsub(/^>/, "", m[0]);          # remove leading >
    print m[0];
    exit
  }')

if [ -n "$TEXT_MATCH" ]; then
  TEXT_URL_LINE=$(grep -F "$TEXT_MATCH" "$TMP_HTML_SECTION" || true)
  echo "Matching text detected: $TEXT_MATCH"
  [ -n "$TEXT_URL_LINE" ] && echo "Found in code line: $TEXT_URL_LINE"
else
  echo "$(date)|FAILED: No text found matching $CHECK_YEAR. EXITCODE:$EXIT_NO_TEXTMATCH_FOUND" >> "$LOG_FILE"
  curl -fsS -X POST "$NTFY_URL" -d "No text found matching $CHECK_YEAR at $URL" || true
  exit_with_message "$EXIT_NO_TEXTMATCH_FOUND" "No text found matching $CHECK_YEAR"
fi

# 4) Extract the PDF URL linked to the matched text
PDF_URL=$(echo "$SECTION_HTML" | gawk -v year="$CHECK_YEAR" '
  BEGIN { IGNORECASE=1 }
  match($0, "<a[^>]+href=\"([^\"]+\\.pdf)\"[^>]*>" year "(-[A-Za-z]{3})?</a>", m) {
    print m[1];
    exit
  }')

if [ -z "$PDF_URL" ]; then
  echo "$(date)|FAILED: No matching PDF link for $CHECK_YEAR. EXITCODE:$EXIT_NO_PDF_FOUND" >> "$LOG_FILE"
  curl -fsS -X POST "$NTFY_URL" -d "No matching PDF link (YYYY or YYYY-MMM) found at $URL" || true
  exit_with_message "$EXIT_NO_PDF_FOUND" "No matching PDF link found"
fi

# 5) Handle relative URLs
if [[ "$PDF_URL" != http* ]]; then
  BASE_URL=$(printf "%s\n" "$URL" | grep -oE '^https?://[^/]+')
  PDF_URL="${BASE_URL}${PDF_URL}"
fi

# 6) Download the PDF
if ! curl -fsSL -A "Mozilla/5.0" "$PDF_URL" -o "$PDF_FILE"; then
  echo "$(date)|FAILED: Failed to download PDF from $PDF_URL. EXITCODE:$EXIT_PDF_DOWNLOAD_FAILED" >> "$LOG_FILE"
  curl -fsS -X POST "$NTFY_URL" -d "Failed to download PDF from $PDF_URL" || true
  exit_with_message "$EXIT_PDF_DOWNLOAD_FAILED" "Failed to download PDF"
fi

if [ ! -s "$PDF_FILE" ]; then
  echo "$(date)|FAILED: Empty PDF after download from $PDF_URL. EXITCODE:$EXIT_PDF_DOWNLOAD_FAILED" >> "$LOG_FILE"
  curl -fsS -X POST "$NTFY_URL" -d "Downloaded PDF was empty: $PDF_URL" || true
  exit_with_message "$EXIT_PDF_DOWNLOAD_FAILED" "Downloaded PDF is empty"
fi

# 7) Hash comparison
CURRENT_HASH_DATETIME=$(date -u "+%Y-%m-%d %H:%M UTC")
CURRENT_HASH=$(sha256sum "$PDF_FILE" | awk '{print $1}')

if [ ! -f "$OLD_HASH_FILE" ]; then
  echo "$CURRENT_HASH_DATETIME|No previous hash detected|$CURRENT_HASH" > "$OLD_HASH_FILE"
  echo "$CURRENT_HASH_DATETIME|Initialized PDF monitoring: $PDF_URL|EXITCODE:$EXIT_SUCCESS_INITIALIZED" >> "$LOG_FILE"
  curl -fsS -X POST "$NTFY_URL" -d "Started monitoring: $PDF_URL (first check at $CURRENT_HASH_DATETIME)" || true
  exit_with_message "$EXIT_SUCCESS_INITIALIZED" "Initialized monitoring"
fi

LAST_HASH=$(awk -F'|' '{print $3}' "$OLD_HASH_FILE")
LAST_HASH_DATETIME=$(awk -F'|' '{print $1}' "$OLD_HASH_FILE")
NEW_HASH_LOG="$CURRENT_HASH_DATETIME|SUCCESS: Successful check, change detected|$CURRENT_HASH"
CHANGE_MESSAGE="🆕 Change detected in DCA PDF report 🆕 Please open: $PDF_URL."
NO_CHANGE_MESSAGE="😞 No change detected in DCA PDF report 😞"

echo "last hash at $LAST_HASH_DATETIME was $LAST_HASH"
echo "current hash at $CURRENT_HASH_DATETIME is $CURRENT_HASH"

if [ "$CURRENT_HASH" != "$LAST_HASH" ]; then
  echo "$NEW_HASH_LOG" > "$OLD_HASH_FILE"
  # Notify ntfy
  curl -fsS -X POST "$NTFY_URL" -d "$(date): $CHANGE_MESSAGE" || true
  # Notify Google Chat webhook
  curl -fsS -X POST -H 'Content-Type: application/json' \
    -d "{\"text\": \"$(date): $CHANGE_MESSAGE\"}" \
    "$CHAT_WEBHOOK" >/dev/null || true
  echo "$CURRENT_HASH_DATETIME|SUCCESS: Successful check, change detected. EXITCODE:$EXIT_SUCCESS_CHANGE|$CURRENT_HASH" >> "$LOG_FILE"
  exit_with_message "$EXIT_SUCCESS_CHANGE" "Change detected"
else
  curl -fsS -X POST "$NTFY_URL" -d "$(date): $NO_CHANGE_MESSAGE" || true
  echo "$CURRENT_HASH_DATETIME|Successful check, no change detected. EXITCODE:$EXIT_SUCCESS_NOCHANGE|$CURRENT_HASH" >> "$LOG_FILE"
  exit_with_message "$EXIT_SUCCESS_NOCHANGE" "No change"
fi
