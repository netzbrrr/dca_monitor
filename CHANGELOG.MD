📑 Changelog

All notable changes to this project will be documented in this file.

[Unreleased]
[1.1.0] – 2025-09-17
✨ Added

Environment variables

CHECK_YEAR → configurable via .env or Docker env.

CHAT_WEBHOOK, NTFY_URL → required for notifications.

CRON_SCHEDULE, CRON_BOOTSTRAP → control containerized scheduling behavior.

Docker support

New Dockerfile and docker-compose.yml.

Container now runs once on startup (bootstrap) and then daily via cron.

Portainer/Git deploys supported with stack.env.

.env auto-generation

On bare-metal, the script creates a .env template with placeholders if missing.

Exit codes

Unified, expanded, and documented (0 = init, 1 = no change, 2 = change, 20+ = errors).

Docs

README updated with clear Docker + bare-metal instructions.

🔄 Changed

HTML parsing

Now restricted to <div class="text-download"> section → faster & fewer false positives.

Logging

Standardized format:

YYYY-MM-DD HH:MM UTC | Message | HASH


Notifications

NTFY → receives all runs.

Google Chat → receives only change detections.

Timezone handling

TZ defaults to Asia/Yangon, but configurable via env.

🐛 Fixed

Dependencies

Docker image now includes all required tools: bash, curl, gawk, sha256sum, tzdata.

Validation

Missing CHECK_YEAR or misconfigured env vars now produce a clear error (exit 23).

Security

.dockerignore updated → prevents accidental commit of secrets (stack.env, .env).

[1.0.0] – 2025-05-01
🚀 Initial Release

Bash script monitoring DCA Myanmar PDF publications.

Detects changes via hash comparison.

Logs results locally.

Sends notifications via ntfy.sh and Google Chat webhook.

🔖 Versioning
We follow Semantic Versioning
:

MAJOR → breaking changes.

MINOR → new features, backward-compatible.

PATCH → bug fixes only.
