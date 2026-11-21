#!/usr/bin/env bash
# dreams-update.sh: the live relay's auto-deploy (run by dreams-update.timer every 10 min).
# Reconstructed from the live setup (Nov 20, 2026): a sparse, shallow checkout of server/ from
# main; when server/ changed, npm ci and restart the dreams-relay service.
# The box runs the copy installed at setup; this file is the reference (and what a rebuilt
# box installs). Additions over the setup copy: it writes the deployed commit to
# server/.deployed_commit (served by GET /version as "commit") and logs one line per deploy.
# GET /version's "code" (sha1 of server.js + package-lock.json) needs neither, so CI can always
# tell which server/ is live, with or without this file.
#
# Env (all optional): DREAMS_DIR (checkout, default /opt/dreams), DREAMS_REPO, DREAMS_BRANCH,
# DREAMS_SERVICE (default dreams-relay).
set -euo pipefail
DIR="${DREAMS_DIR:-/opt/dreams}"
REPO="${DREAMS_REPO:-https://github.com/Excivious27/Dreams.git}"
BRANCH="${DREAMS_BRANCH:-main}"
SERVICE="${DREAMS_SERVICE:-dreams-relay}"
log() { echo "dreams-update: $*"; }

if [ ! -d "$DIR/.git" ]; then
  log "first checkout into $DIR"
  git clone -q --depth 1 --filter=blob:none --sparse --branch "$BRANCH" "$REPO" "$DIR"
  git -C "$DIR" sparse-checkout set server
  OLD=""
else
  OLD="$(git -C "$DIR" rev-parse HEAD:server 2>/dev/null || echo "")"
  git -C "$DIR" fetch -q --depth 1 origin "$BRANCH"
  git -C "$DIR" reset -q --hard FETCH_HEAD
fi
NEW="$(git -C "$DIR" rev-parse HEAD:server)"
COMMIT="$(git -C "$DIR" rev-parse HEAD)"
if [ "$OLD" = "$NEW" ] && [ -d "$DIR/server/node_modules" ]; then
  exit 0  # server/ unchanged: nothing to do (the running relay keeps its rooms)
fi
log "server/ changed ($OLD -> $NEW) at $COMMIT: npm ci + restart"
cd "$DIR/server"
npm ci --omit=dev --no-audit --no-fund --silent
echo "$COMMIT" > "$DIR/server/.deployed_commit"
systemctl restart "$SERVICE"
log "deployed $COMMIT"
