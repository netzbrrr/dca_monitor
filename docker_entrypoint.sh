#!/usr/bin/env bash
set -euo pipefail

# Run every day at 09:00 (MMT) by default
: "${CRON_SCHEDULE:=0 9 * * *}"

# Make env vars available to the cron job
cat >/usr/local/bin/run-check.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export TZ="${TZ:-Asia/Yangon}"
export CHAT_WEBHOOK="${CHAT_WEBHOOK:-}"
export NTFY_URL="${NTFY_URL:-}"
cd /app
./check_dca.sh >> /var/log/dca_monitor.log 2>&1
EOF
chmod +x /usr/local/bin/run-check.sh

echo "${CRON_SCHEDULE} /usr/local/bin/run-check.sh" > /etc/crontabs/root
echo "[dca_monitor] Cron installed: ${CRON_SCHEDULE} (TZ=${TZ:-Asia/Yangon})"
exec "$@"
