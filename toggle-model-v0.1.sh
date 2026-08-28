#!/usr/bin/env bash
# toggle-model-v0.1.sh — switch Agent Zero between two xAI Grok models.
#
#   ./toggle-model-v0.1.sh code        # Grok Code Fast 1  (cheap, coding)
#   ./toggle-model-v0.1.sh reasoning   # Grok 4.1 Fast     (heavier logic)
#   ./toggle-model-v0.1.sh status      # show what's live now, change nothing
#
# Designed to be run over SSH from a phone. Everything is auto-discovered:
# the container, the settings file, and the JSON edit all happen without
# needing jq or python on the host.
#
# Overrides, if auto-detection guesses wrong:
#   A0_CONTAINER=<name>   pin the container
#   A0_SETTINGS=<path>    pin the settings file path (inside the container)
#   A0_NO_RESTART=1       edit the config but don't restart

set -euo pipefail

VERSION="0.1"

# Both models are xAI, so the provider / api_base / API key never change.
# The toggle rewrites the model name and context length only. Keeping the
# provider untouched means a working endpoint config can't be broken here.
CODE_NAME="grok-code-fast-1"
CODE_CTX="256000"
CODE_LABEL="Grok Code Fast 1 (cheap, coding-tuned)"

REASON_NAME="grok-4-1-fast-reasoning"
REASON_CTX="2000000"
REASON_LABEL="Grok 4.1 Fast — reasoning (heavier logic)"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<USAGE
toggle-model v${VERSION}

  $(basename "$0") code        -> ${CODE_LABEL}
  $(basename "$0") reasoning   -> ${REASON_LABEL}
  $(basename "$0") status      -> show current model, change nothing
USAGE
}

# --- resolve the target ------------------------------------------------------
case "${1:-}" in
  code)       WANT_NAME="$CODE_NAME";   WANT_CTX="$CODE_CTX";   WANT_LABEL="$CODE_LABEL" ;;
  reasoning)  WANT_NAME="$REASON_NAME"; WANT_CTX="$REASON_CTX"; WANT_LABEL="$REASON_LABEL" ;;
  status)     WANT_NAME=""; WANT_CTX=""; WANT_LABEL="" ;;
  -h|--help|"") usage; exit 0 ;;
  *) usage; die "unknown argument '${1}'" ;;
esac

command -v docker >/dev/null 2>&1 || die "docker not found on PATH"
docker info >/dev/null 2>&1 || die "can't reach the Docker daemon — is Docker Desktop running?"

# --- find the container ------------------------------------------------------
CTR="${A0_CONTAINER:-}"
if [ -z "$CTR" ]; then
  # Match on image or name; Agent Zero images are published as *agent-zero*.
  CTR=$(docker ps --format '{{.Names}}\t{{.Image}}' \
        | grep -iE 'agent[-_]?zero' \
        | head -n1 | cut -f1 || true)
fi
[ -n "$CTR" ] || die "couldn't find a running Agent Zero container.
Run 'docker ps' and re-run with:  A0_CONTAINER=<name> $0 ${1}"

# --- find the settings file --------------------------------------------------
# Newer builds use /a0/usr/settings.json; older ones /a0/tmp/settings.json.
# Editing inside the container works either way — if the path is a host
# bind-mount the write passes straight through to the Mac's filesystem.
SETTINGS="${A0_SETTINGS:-}"
if [ -z "$SETTINGS" ]; then
  for candidate in /a0/usr/settings.json /a0/tmp/settings.json; do
    if docker exec "$CTR" test -f "$candidate" 2>/dev/null; then
      SETTINGS="$candidate"; break
    fi
  done
fi
[ -n "$SETTINGS" ] || die "no settings.json found in container '$CTR'.
Looked in /a0/usr/ and /a0/tmp/. Pin it with:  A0_SETTINGS=<path> $0 ${1}"

show() {
  docker exec -i "$CTR" python3 - "$SETTINGS" <<'PYEOF'
import json, sys
try:
    with open(sys.argv[1]) as fh:
        s = json.load(fh)
except Exception as exc:
    print("  (could not read settings: %s)" % exc); raise SystemExit(1)
for key in ("chat_model_provider", "chat_model_name", "chat_model_ctx_length"):
    if key in s:
        print("  %-22s %s" % (key + ":", s[key]))
kw = s.get("chat_model_kwargs")
if kw:
    print("  %-22s %s" % ("chat_model_kwargs:", json.dumps(kw)))
PYEOF
}

echo "container: $CTR"
echo "settings:  $SETTINGS"
echo
echo "current:"
show

if [ -z "$WANT_NAME" ]; then exit 0; fi

# --- apply -------------------------------------------------------------------
echo
echo "switching to: $WANT_LABEL"

docker exec -i "$CTR" python3 - "$SETTINGS" "$WANT_NAME" "$WANT_CTX" <<'PYEOF'
import json, os, shutil, sys, time

path, name, ctx = sys.argv[1], sys.argv[2], sys.argv[3]

with open(path) as fh:
    settings = json.load(fh)

# Timestamped backup so a bad toggle is always one 'cp' away from undone.
backup = "%s.bak-%s" % (path, time.strftime("%Y%m%d-%H%M%S"))
shutil.copy2(path, backup)

settings["chat_model_name"] = name
settings["chat_model_ctx_length"] = int(ctx)

# The Grok 4 family rejects these outright; grok-code-fast-1 ignores
# reasoning_effort. Leaving them in a saved config causes 400s on the first
# request, so strip them from the chat model kwargs on every toggle.
UNSUPPORTED = {
    "presence_penalty", "presencePenalty",
    "frequency_penalty", "frequencyPenalty",
    "stop", "reasoning_effort", "reasoningEffort",
}
kwargs = settings.get("chat_model_kwargs")
if isinstance(kwargs, dict):
    removed = [k for k in list(kwargs) if k in UNSUPPORTED]
    for k in removed:
        del kwargs[k]
    if removed:
        print("  stripped unsupported params: %s" % ", ".join(removed))

# Write to a temp file and rename, so an interrupted write can't leave a
# half-written settings.json behind (the failure mode that forces a wipe).
tmp = path + ".tmp"
with open(tmp, "w") as fh:
    json.dump(settings, fh, indent=4)
os.replace(tmp, path)
print("  backup saved: %s" % backup)
PYEOF

if [ "${A0_NO_RESTART:-}" = "1" ]; then
  echo
  echo "config updated; skipping restart (A0_NO_RESTART=1)."
  exit 0
fi

echo
echo "restarting $CTR ..."
docker restart "$CTR" >/dev/null

# Wait for the container to come back before reporting, otherwise the
# confirmation below can read from a container that's still booting.
for _ in $(seq 1 30); do
  state=$(docker inspect -f '{{.State.Running}}' "$CTR" 2>/dev/null || echo false)
  [ "$state" = "true" ] && break
  sleep 1
done
sleep 2

echo
echo "now active:"
show
echo
echo "done — $WANT_LABEL"
