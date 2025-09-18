Changelog

All notable changes to this project will be documented in this file.

[Unreleased]
[1.1.0] – 2025-09-17
Added

Environment variables:

CHECK_YEAR configurable via .env or Docker env.

CHAT_WEBHOOK, NTFY_URL required for notifications.

CRON_SCHEDULE and CRON_BOOTSTRAP for containerized deployments.

Docker support:

Added Dockerfile and docker-compose.yml.

Container runs once on startup (bootstrap) then on schedule via cron.

Portainer/Git deploys supported with stack.env.

.env template auto-generation: On bare-metal, the script now creates a .env file with placeholders if missing.

System exit codes: unified and expanded (0 = init, 1 = no change, 2 = change, 20+ = errors).

Improved README: clarified Docker usage and bare-metal instructions.

Changed

HTML parsing limited to <div class="text-download"> section (faster, fewer false positives).

Logging format standardized to YYYY-MM-DD HH:MM UTC|Message|HASH.

Notifications improved:

NTFY receives all runs.

Google Chat receives only change detections.

Timezone handling improved (TZ defaults to Asia/Yangon but configurable).

Fixed

Docker builds now include all required dependencies (bash, curl, gawk, sha256sum, tzdata).

Missing CHECK_YEAR or misconfigured env vars now produce a clear exit code (23) and error message.

Prevented accidental commit of secrets by updating .dockerignore.

[1.0.0] – 2025-05-01

Initial release: Bash script monitoring DCA Myanmar PDF publications.

Detects changes via hash comparison, logs results, sends ntfy + Google Chat notifications.
