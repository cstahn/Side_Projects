#!/usr/bin/env bash
# install.sh — idempotent dependency setup for the Agent Zero model-toggle repo.
#
# Installs the tools the toggle script and its development loop need:
#   - shellcheck : lint the bash script
#   - docker-ce  : the toggle script drives Agent Zero through Docker; a working
#                  daemon lets us exercise the script against a mock container
#   - fuse-overlayfs : storage driver required to run Docker inside the
#                      Cloud Agent's nested container (standard overlay2 is
#                      unavailable there)
#
# Runs after the repository is checked out. The Docker *daemon* is not started
# here (that is per-boot work handled by start.sh); this only installs packages.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# The base image ships a script-modified /etc/fuse.conf, so installing fuse3
# triggers an interactive dpkg conffile prompt that hangs a non-interactive
# build. Force dpkg to keep the existing config without prompting.
APT_INSTALL=(sudo apt-get install -y -qq --no-install-recommends
  -o Dpkg::Options::=--force-confdef
  -o Dpkg::Options::=--force-confold)

echo "==> apt update"
sudo apt-get update -qq

echo "==> install base tooling (shellcheck, fuse-overlayfs, iptables)"
"${APT_INSTALL[@]}" \
  ca-certificates curl gnupg \
  shellcheck fuse3 fuse-overlayfs uidmap iptables

# Belt-and-suspenders: settle any package left half-configured by a prior run.
sudo dpkg --configure -a --force-confdef --force-confold >/dev/null 2>&1 || true

echo "==> install Docker CE from the official Docker apt repository"
if ! command -v dockerd >/dev/null 2>&1; then
  sudo install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
  fi
  # shellcheck source=/dev/null
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -qq
  "${APT_INSTALL[@]}" \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin
fi

echo "==> configure Docker to use the fuse-overlayfs storage driver"
sudo mkdir -p /etc/docker
printf '{\n    "storage-driver": "fuse-overlayfs"\n}\n' \
  | sudo tee /etc/docker/daemon.json >/dev/null

echo "==> allow the 'ubuntu' user to talk to the Docker socket without sudo"
sudo groupadd -f docker
sudo usermod -aG docker ubuntu || true

echo "==> versions"
shellcheck --version | sed -n '2p'
docker --version

echo "install.sh: done"
