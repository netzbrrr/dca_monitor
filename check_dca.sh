#!/bin/bash

# === Configuration ===
URL="https://dcamyanmar.com/dcadca/index.php?option=com_content&view=article&id=29"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"
LOG_DIR="$SCRIPT_DIR/logs"
TMP_HTML="$OUTPUT_DIR/dca_tmp.html"
PDF_FILE="$OUTPUT_DIR/latest.pdf"
OLD_HASH_FILE="$OUTPUT_DIR/pdf_hash.txt"
LOG_FILE="$LOG_DIR/change_log.txt"
NTFY_TOPIC="DCA_Data_Update"
NTFY_URL="https://ntfy.sh/$NTFY_TOPIC"
CHECK_YEAR="2025"

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

#echo "📂 Script directory: $SCRIPT_DIR"
#echo "📁 Output directory: $OUTPUT_DIR"
#echo "📝 Log directory: $LOG_DIR"

# === Exit Codes ===
# 0–19: Success, 20+: Errors
EXIT_SUCCESS_INITIALIZED=0  # Script ran successfully for first time. No prior hash detected.
EXIT_SUCCESS_NOCHANGE=1     # Script ran successfully, no change in pdf detected
EXIT_SUCCESS_CHANGE=2       # Script ran successfully, change in pdf detected
EXIT_NO_TEXTMATCH_FOUND=20  # Script exited because no text matching $CHECK_YEAR was found in the html section

EXIT_NO_PDF_FOUND=20        # Script exited because no PDF file was found
EXIT_PDF_DOWNLOAD_FAILED=21 # Script exited becuase PDF could not be downloaded


# === Exception Handling ===
exit_with_message() {
    local code="$1"
    local message="$2"
    echo "Exit $code: $message"
    exit "$code"
}


# === Script ===

# === Dump the HTML content of the URL to a temporary file ===

/usr/bin/curl -s "$URL" -o "$TMP_HTML"

# === Extract relevant section from HTML ===
SECTION_HTML=$(awk '/<div class="text-download">/,/<\/div>/' "$TMP_HTML")

# === Find the text that matches the check year in the section HTML ===
TEXT_MATCH=$(echo "$SECTION_HTML" | gawk -v year="$CHECK_YEAR" '
    BEGIN { IGNORECASE=1 }
    match($0, ">" year "(-[A-Za-z]{3})?</a>", m) {
        gsub(/<\/?[^>]+>/, "", m[0])  # Strip tags, just keep visible text
        gsub(/^>/, "", m[0])          # Remove leading >
        print m[0]
        exit
    }')


TEXT_URL_LINE=$(grep --color=always -F "$TEXT_MATCH" "$TMP_HTML")
echo "Matching text detected: " $TEXT_MATCH
echo "Found in code line:" $TEXT_URL_LINE

# === If no matching text is found, exit with an error ===

if [ -z "$TEXT_MATCH" ]; then
    echo "$(date)|FAILED:No text found matching "$CHECK_YEAR". EXITCODE:$EXIT_NO_TEXTMATCH_FOUND" >> "$LOG_FILE"
    /usr/bin/curl -s -X POST "$NTFY_URL" -d "No text found matching "$CHECK_YEAR" at $URL"
    exit_with_message $EXIT_NO_TEXTMATCH_FOUND 
fi

# === Extract the url linked to the matched text ===

PDF_URL=$(echo "$SECTION_HTML" | gawk -v year="$CHECK_YEAR" '
    BEGIN { IGNORECASE=1 }
    match($0, "<a[^>]+href=\"([^\"]+\\.pdf)\"[^>]*>" year "(-[A-Za-z]{3})?</a>", m) {
        print m[1]
        exit
    }')


# === If no url can be extracted from the matched text, exit with an error ===

if [ -z "$PDF_URL" ]; then
    echo "$(date)|FAILED:No url found at matched text "$CHECK_YEAR". EXITCODE:$EXIT_NO_PDF_FOUND" >> "$LOG_FILE"
    /usr/bin/curl -s -X POST "$NTFY_URL" -d "No matching PDF link (YYYY-MMM) found at $URL"
    exit_with_message $EXIT_NO_PDF_FOUND 
fi

# === Handle relative URLs ===
if [[ "$PDF_URL" != http* ]]; then
    BASE_URL=$(echo "$URL" | grep -oE '^https?://[^/]+')
    PDF_URL="${BASE_URL}${PDF_URL}"
fi

# === Download the PDF from the URL ===
/usr/bin/curl -s -f -L "$PDF_URL" -o "$PDF_FILE"

if [ ! -s "$PDF_FILE" ]; then
    echo "$(date)|FAILED:Failed to download PDF from $PDF_URL. EXITCODE:$EXIT_PDF_DOWNLOAD_FAILED" >> "$LOG_FILE"
    /usr/bin/curl -s -X POST "$NTFY_URL" -d "Failed to download PDF from $PDF_URL"
    exit_with_message $EXIT_PDF_DOWNLOAD_FAILED
fi

# === Generate a timestamp for when the file is hashed ===
CURRENT_HASH_DATETIME=$(date -u "+%Y-%m-%d %H:%M UTC")

# Hash the downloaded PDF ===
CURRENT_HASH=$(/usr/bin/sha256sum "$PDF_FILE" | /usr/bin/awk '{print $1}')

# If this is the first time the script runs, store both date and hash
if [ ! -f "$OLD_HASH_FILE" ]; then
    echo "$CURRENT_HASH_DATETIME|No Previous Has detected|$CURRENT_HASH" > "$OLD_HASH_FILE"
    echo "$CURRENT_HASH_DATETIME|Initialized PDF monitoring: $PDF_URL|EXITCODE:$EXIT_SUCCESS_INITIALIZED" >> "$LOG_FILE"
    /usr/bin/curl -s -X POST "$NTFY_URL" -d "Started monitoring: $PDF_URL (first check at $CURRENT_HASH_DATETIME)"
    exit_with_message $EXIT_SUCCESS_INITIALIZED
fi

# Load current check time,previous hash and last hash time, logs and messages
    LAST_HASH=$(awk -F'|' '{print $3}' "$OLD_HASH_FILE")
    LAST_HASH_DATETIME=$(awk -F'|' '{print $1}' "$OLD_HASH_FILE")
    LAST_CHECK=$(awk -F'|' 'END {print $1 "|" $2}' "$LOG_FILE")
    NEW_HASH_LOG="$CURRENT_HASH_DATETIME|Successful check, change detected|$CURRENT_HASH"
    CHANGE_MESSAGE="🆕 Change detected in DCA pdf report 🆕 Please open: $PDF_URL."
    NO_CHANGE_MESSAGE="😞 No Change detected in DCA pdf report 😞" 

echo $LAST_HASH_DATETIME
echo $LAST_HASH
echo $CURRENT_HASH_DATETIME
echo $CURRENT_HASH

# Compare current hash with previous
if [ "$CURRENT_HASH" != "$LAST_HASH" ]; then
    echo "$NEW_HASH_LOG" > "$OLD_HASH_FILE"
    /usr/bin/curl -s -X POST "$NTFY_URL" -d "$(date): $CHANGE_MESSAGE" 
    echo "$CURRENT_HASH_DATETIME|SUCCES:Successful check, change detected.EXITCODE:$EXIT_SUCCESS_CHANGE|$CURRENT_HASH" >> "$LOG_FILE"
    exit_with_message $EXIT_SUCCESS_CHANGE
else
    /usr/bin/curl -s -X POST "$NTFY_URL" -d "$(date): $NO_CHANGE_MESSAGE"
    echo "$CURRENT_HASH_DATETIME|Successful check, no change detected.EXITCODE:$EXIT_SUCCESS_NOCHANGE|$CURRENT_HASH" >> "$LOG_FILE"
    exit_with_message $EXIT_SUCCESS_NOCHANGE
fi

