# Dockerfile
FROM alpine:3.20

# Deps for your script
RUN apk add --no-cache bash curl jq tzdata ca-certificates gawk \
 && update-ca-certificates

# Timezone
ENV TZ=Asia/Yangon

# App files
WORKDIR /app
COPY . /app
RUN chmod +x /app/check_dca.sh

# Ensure dirs
RUN mkdir -p /usr/local/bin /var/log

# Entrypoint: creates cron job, optional bootstrap run, then starts crond
RUN cat >/usr/local/bin/docker-entrypoint.sh <<'EOF' && chmod +x /usr/local/bin/docker-entrypoint.sh
#!/usr/bin/env bash
set -euo pipefail

: "${CRON_SCHEDULE:=0 9 * * *}"   # default 09:00 MMT daily
: "${CRON_BOOTSTRAP:=true}"       # run once on container start by default

# Wrapper so cron inherits env; mirror output to file + stdout
cat >/usr/local/bin/run-check.sh <<'EOW'
#!/usr/bin/env bash
set -euo pipefail
export TZ="${TZ:-Asia/Yangon}"
export CHAT_WEBHOOK="${CHAT_WEBHOOK:-}"
export NTFY_URL="${NTFY_URL:-}"
export CHECK_YEAR="${CHECK_YEAR:-}"
cd /app
/app/check_dca.sh 2>&1 | tee -a /var/log/dca_monitor.log
EOW
chmod +x /usr/local/bin/run-check.sh

# Install the cron job
echo "${CRON_SCHEDULE} /usr/local/bin/run-check.sh" > /etc/crontabs/root
echo "[dca_monitor] Cron installed: ${CRON_SCHEDULE} (TZ=${TZ:-Asia/Yangon})"

# One-shot bootstrap to initialize baseline hash/logs
if [ "${CRON_BOOTSTRAP}" = "true" ]; then
  echo "[dca_monitor] Bootstrap run on container start..."
  /usr/local/bin/run-check.sh || true
fi

# Start cron in foreground
exec crond -f -l 8
EOF

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
