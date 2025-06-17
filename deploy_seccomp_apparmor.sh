#!/usr/bin/env bash
# deploy.sh – loads the custom AppArmor profile, then runs docker-compose.
#
# Copies security_config/docker-bwrap into /etc/apparmor.d/docker-bwrap
#   (only if changed) and reloads it via apparmor_parser.
# Forwards all arguments to `docker compose` (e.g. `./deploy.sh up -d`).
#
# Project Local Context:
#   security_config/docker-bwrap
#   security_config/seccomp_allow_bwrap.json
#   docker-compose.yml
#   deploy.sh
#

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
PROFILE_SRC="$PROJECT_ROOT/security_config/docker-bwrap"
PROFILE_DST="/etc/apparmor.d/docker-bwrap" # Path to the AppArmor profile

echo "Loading AppArmor profile…"
if [[ ! -f "$PROFILE_SRC" ]]; then
  echo "$PROFILE_SRC not found" >&2
  exit 1
fi

if ! sudo cmp -s "$PROFILE_SRC" "$PROFILE_DST" 2>/dev/null; then
  echo "Installing/Updating $PROFILE_DST"
  sudo install -m 644 -D "$PROFILE_SRC" "$PROFILE_DST"
  sudo apparmor_parser -Kr "$PROFILE_DST"
else
  echo "Profile already up-to-date; skipping reload"
fi

echo "Starting Docker Compose stack…"
sudo docker compose "$@"

echo "Done."
