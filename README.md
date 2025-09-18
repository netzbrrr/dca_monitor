DCA PDF Monitor

A Bash script (and Docker container) that monitors the Department of Civil Aviation Myanmar (DCA) website for newly published PDF reports. If a change is detected, it logs the update and sends notifications.

The Department of Civil Aviation in Myanmar publishes aggregated monthly data on the number of passengers and cargo at domestic and international airports. Updates are irregular and the DCA does not offer notifications.
This tool automates checking the website and notifies you when new data is published.

📌 Features

Scrapes the DCA Myanmar publications page
.

Detects any report for the configured year (CHECK_YEAR).

Downloads & hashes the PDF, compares with last known hash.

Logs results in a structured, parse-friendly format.

Sends notifications via:

ntfy.sh
 → all updates

Google Chat webhook → only when new data is detected

Timezone awareness: timestamps use Myanmar Standard Time (UTC+6:30).

Can run bare-metal (cron/systemd) or in Docker (cron auto-configured).

✨ What’s New

Env-based year detection: configure via CHECK_YEAR instead of editing the script.

Focused parsing: only scans the <div class="text-download"> section.

Improved logs: YYYY-MM-DD HH:MM UTC|Message|HASH.

Multi-channel notifications: NTFY + optional Google Chat webhook.

Docker ready: auto-runs once on container start to bootstrap, then daily at 09:00 MMT.

.env handling:

Docker → pass env vars in Portainer or via stack.env.

Bare-metal → script auto-creates .env template if missing.

⚙️ Configuration
Required environment variables

CHECK_YEAR → year to watch (e.g. 2025)

NTFY_URL → ntfy topic URL (e.g. https://ntfy.sh/DCA_Data_Update)

CHAT_WEBHOOK → Google Chat webhook URL

Optional

TZ → defaults to Asia/Yangon

CRON_SCHEDULE → defaults to 0 9 * * * (daily 09:00 MMT)

CRON_BOOTSTRAP → run once on container start (true by default)

🚀 Usage
Bare-metal

Clone repo and install deps (bash, curl, gawk, sha256sum):

git clone https://github.com/netzbrrr/dca_monitor.git
cd dca_monitor
chmod +x check_dca.sh


First run creates .env template if missing. Fill it, then run:

./check_dca.sh


Automate with cron:

0 9 * * * cd /path/to/dca_monitor && ./check_dca.sh >> logs/cron.log 2>&1

Docker / Portainer

Deploy via docker-compose.yml:

version: "3.8"
services:
  dca-monitor:
    build:
      context: .
      dockerfile: Dockerfile
    restart: unless-stopped
    environment:
      CHECK_YEAR: ${CHECK_YEAR}
      CHAT_WEBHOOK: ${CHAT_WEBHOOK}
      NTFY_URL: ${NTFY_URL}
      TZ: ${TZ:-Asia/Yangon}
      CRON_SCHEDULE: ${CRON_SCHEDULE:-0 9 * * *}
      CRON_BOOTSTRAP: ${CRON_BOOTSTRAP:-true}
    env_file:
      - stack.env
    volumes:
      - dca-data:/data
volumes:
  dca-data:


For Portainer:

If deploying via Web editor: set env vars in the Environment variables panel.

If deploying via Git repository: commit a stack.env file in your repo with the required vars.

On start, the container:

Runs once immediately (to set baseline hash).

Schedules daily check at 09:00 MMT.

🔔 Notifications

NTFY: Subscribe to your topic via the web or the ntfy mobile app.

Google Chat: Configure a webhook in your space and set CHAT_WEBHOOK.

📂 Output

/logs/change_log.txt → append-only log of checks

/output/latest.pdf → most recent report

/output/pdf_hash.txt → last known hash + timestamp

/output/dca_tmp.html → raw scraped HTML

🛡️ Error Handling

Exit codes:

0 → First run initialized

1 → Success, no change

2 → Success, change detected

20 → No text/PDF found

21 → PDF download failed

22 → No PDF file found

23 → Env vars missing

All errors are logged and trigger an ntfy notification.

📦 Dependencies

bash

curl

gawk

sha256sum

ntfy.sh (no install needed — plain HTTP POST)

👤 Author

netzbrrr
https://github.com/netzbrrr
