#!/usr/bin/env bash
# deploy_seccomp_apparmor.sh – loads the custom AppArmor profile, then runs docker-compose.yaml.
#
# Copies security_config/docker-bwrap into /etc/apparmor.d/docker-bwrap
#   (only if changed) and reloads it via apparmor_parser.
# Forwards all arguments to `docker compose` (e.g. `./deploy.sh up -d`).
#
# Project Local Context:
#   security_config/docker-bwrap
#   security_config/seccomp_allow_bwrap.json
#   docker-compose.yaml
#   deploy.sh
#

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
APPARMOR_PROFILE_SRC="$PROJECT_ROOT/security_config/apparmor_allow_bwrap"
APPARMOR_PROFILE_DST="/etc/apparmor.d/docker-bwrap"


echo "Loading AppArmor profile…"
if [[ ! -f "$APPARMOR_PROFILE_SRC" ]]; then
  echo "$APPARMOR_PROFILE_SRC not found" >&2
  exit 1
fi

if ! sudo cmp -s "$APPARMOR_PROFILE_SRC" "$APPARMOR_PROFILE_DST" 2>/dev/null; then
  echo "Installing/Updating $APPARMOR_PROFILE_DST"
  sudo install -m 644 -D "$APPARMOR_PROFILE_SRC" "$APPARMOR_PROFILE_DST"
  sudo apparmor_parser -Kr "$APPARMOR_PROFILE_DST"
else
  echo "Profile already up-to-date; skipping reload"
fi

echo "Starting Docker Compose stack…"
sudo docker compose "$@"

echo "Done."
