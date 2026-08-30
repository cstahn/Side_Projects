#!/usr/bin/env bash
# start.sh — per-boot startup. Brings the Docker daemon up so the toggle script
# has a reachable daemon. Idempotent: safe to run repeatedly, and a no-op if the
# daemon is already responding.
#
# The Cloud Agent VM has no systemd, so dockerd is launched directly and
# supervised via a background process instead of `systemctl start docker`.

set -euo pipefail

LOG=/var/log/dockerd.log

# Use sudo for the readiness probe so the check does not depend on the current
# shell having picked up the 'docker' group membership yet.
if sudo docker info >/dev/null 2>&1; then
  echo "start.sh: Docker daemon already running"
  exit 0
fi

echo "start.sh: launching dockerd (log: ${LOG})"
sudo mkdir -p /var/log
sudo bash -c "nohup dockerd >> '${LOG}' 2>&1 &"

echo "start.sh: waiting for the Docker daemon to become ready"
for _ in $(seq 1 60); do
  if sudo docker info >/dev/null 2>&1; then
    echo "start.sh: Docker daemon is up"
    sudo docker info 2>/dev/null | grep -E 'Server Version|Storage Driver' | sed 's/^/  /'
    exit 0
  fi
  sleep 1
done

echo "start.sh: ERROR — Docker daemon did not become ready in time" >&2
sudo tail -n 30 "${LOG}" >&2 || true
exit 1
