#!/bin/bash

URL="https://dcamyanmar.com/dcadca/index.php?option=com_content&view=article&id=29"
DATA_DIR="/var/local/dca_monitor"
TMP_HTML="/tmp/dca_tmp.html"
PDF_FILE="$DATA_DIR/latest.pdf"
OLD_HASH_FILE="$DATA_DIR/pdf_hash.txt"
LAST_CHECK_FILE="$DATA_DIR/last_check.txt"
LOG_FILE="$DATA_DIR/change_log.txt"
NTFY_TOPIC="DCA_Data_Update"
NTFY_URL="https://ntfy.sh/$NTFY_TOPIC"

mkdir -p "$DATA_DIR"

/usr/bin/curl -s "$URL" -o "$TMP_HTML"

PDF_URL=$(gawk 'BEGIN{IGNORECASE=1}
    match($0, /<a[^>]+href="([^"]+\.pdf)"[^>]*>(20[0-9]{2}-(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec))<\/a>/, m) {
        print m[1];
        exit
    }' "$TMP_HTML")


if [ -z "$PDF_URL" ]; then
    echo "$(date): No matching PDF link with YYYY-MMM found." >> "$LOG_FILE"
    /usr/bin/curl -s -X POST "$NTFY_URL" -d "No matching PDF link (YYYY-MMM) found at $URL"
    exit 1
fi

# Handle relative URLs
if [[ "$PDF_URL" != http* ]]; then
    BASE_URL=$(echo "$URL" | grep -oE '^https?://[^/]+')
    PDF_URL="${BASE_URL}${PDF_URL}"
fi

# Download the PDF
/usr/bin/curl -s -L "$PDF_URL" -o "$PDF_FILE"

if [ ! -s "$PDF_FILE" ]; then
    echo "$(date)|Failed to download PDF from $PDF_URL" >> "$LOG_FILE"
    /usr/bin/curl -s -X POST "$NTFY_URL" -d "Failed to download PDF from $PDF_URL"
    exit 1
fi

# Generate a timestamp for when the file is hashed
CURRENT_HASH_DATETIME=$(date -u "+%Y-%m-%d %H:%M UTC")

# Hash the downloaded PDF
CURRENT_HASH=$(/usr/bin/sha256sum "$PDF_FILE" | /usr/bin/awk '{print $1}')

# If this is the first time the script runs, store both date and hash
if [ ! -f "$OLD_HASH_FILE" ]; then
    echo "$CURRENT_HASH_DATETIME|No Previous Has detected|$CURRENT_HASH" > "$OLD_HASH_FILE"
    echo "$CURRENT_HASH_DATETIME|Initialized PDF monitoring: $PDF_URL" >> "$LOG_FILE"
    /usr/bin/curl -s -X POST "$NTFY_URL" -d "Started monitoring: $PDF_URL (first check at $CURRENT_HASH_DATETIME)"
    exit 0
fi

# Load current check time,previous hash and last hash time, logs and messages
    LAST_HASH=$(awk -F'|' '{print $3}' "$OLD_HASH_FILE")
    LAST_HASH_DATETIME=$(awk -F'|' '{print $1}' "$OLD_HASH_FILE")
    LAST_CHECK=$(awk -F'|' 'END {print $1 "|" $2}' "$LOG_FILE")
    NEW_HASH_LOG="$CURRENT_HASH_DATETIME|Successful check, change detected|$CURRENT_HASH"
    CHANGE_MESSAGE="🆕 Change detected in DCA pdf report 🆕 Please open: $PDF_URL."
    NO_CHANGE_MESSAGE="😞 No Change detected in DCA pdf report 😞" 


# Compare current hash with previous
if [ "$CURRENT_HASH" != "$LAST_HASH" ]; then
    echo "$NEW_HASH_LOG" > "$OLD_HASH_FILE"
    /usr/bin/curl -s -X POST "$NTFY_URL" -d "$(date): $CHANGE_MESSAGE" 
    echo "$CURRENT_HASH_DATETIME|Successful check, change detected|$CURRENT_HASH" >> "$LOG_FILE"
else
    /usr/bin/curl -s -X POST "$NTFY_URL" -d "$(date): $NO_CHANGE_MESSAGE"
    echo "$CURRENT_HASH_DATETIME|Successful check, no change detected|$CURRENT_HASH" >> "$LOG_FILE"
fi

