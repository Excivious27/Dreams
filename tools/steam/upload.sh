#!/usr/bin/env bash
# Staged Steam upload (s1_11; run by .github/workflows/steam-upload.yml, never locally). Needs env STEAM_USERNAME + STEAM_CONFIG_VDF (base64 config.vdf),
# from the GitHub Environment "steam". Never takes a password; never echoes secrets.
set -euo pipefail
SCRIPT="$(realpath "$1")"
: "${STEAM_USERNAME:?}" "${STEAM_CONFIG_VDF:?}"
echo "::add-mask::$STEAM_USERNAME"
SC="$HOME/steamcmd"
if [ ! -x "$SC/steamcmd.sh" ]; then
  mkdir -p "$SC"
  curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar xz -C "$SC"
fi
"$SC/steamcmd.sh" +quit > /dev/null 2>&1 || true          # finish self-update first
# steamcmd reads config.vdf from its install dir or ~/Steam depending on the install; write both (verify on the first real run).
umask 077
for d in "$SC/config" "$HOME/Steam/config"; do mkdir -p "$d"; printf '%s' "$STEAM_CONFIG_VDF" | base64 -d > "$d/config.vdf"; done
trap 'for d in "$SC/config" "$HOME/Steam/config"; do shred -u "$d/config.vdf" 2>/dev/null || rm -f "$d/config.vdf"; done' EXIT
set +e
out="$("$SC/steamcmd.sh" +@NoPromptForPassword 1 +login "$STEAM_USERNAME" +run_app_build "$SCRIPT" +quit 2>&1)"
set -e
printf '%s\n' "$out" | grep -v -i -F "$STEAM_USERNAME" | tail -n 40
if printf '%s' "$out" | grep -q -i -E "steam guard|two-factor|Invalid Password|password:"; then
  echo "STEAM: login needs a new Steam Guard code - run the steam-login workflow" | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"
  exit 1
fi
if grep -q '"Preview" "1"' "$SCRIPT" && printf '%s' "$out" | grep -q -E "Successfully finished AppID|Preview build"; then
  echo "STEAM: preview ok (nothing uploaded)" | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"; exit 0
fi
bid="$(printf '%s' "$out" | grep -o -E 'Successfully finished AppID [0-9]+ build \(BuildID [0-9]+\)' | grep -o -E 'BuildID [0-9]+' || true)"
if [ -z "$bid" ]; then echo "STEAM: upload failed" | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"; exit 1; fi
echo "STEAM: ok, $bid" | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"
# Build size per depot from the SteamPipe logs (summary only; logs never become artifacts).
for lg in "$(dirname "$SCRIPT")"/../output/*.log; do
  [ -f "$lg" ] && grep -h -o -E "depot [0-9]+.*bytes.*" "$lg" | head -n 4 | sed 's/^/STEAM size: /' | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}" || true
done
exit 0
