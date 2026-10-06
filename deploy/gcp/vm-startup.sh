#!/usr/bin/env bash
# GCP Compute Engine 開機時執行：安裝 Docker、NVIDIA Container Toolkit、啟動翻譯服務
set -euo pipefail

REPO_DIR="${MIT_REPO_DIR:-/opt/manga-image-translator}"
COMPOSE_FILE="${MIT_COMPOSE_FILE:-deploy/gcp/docker-compose-gcp-gpu.yml}"
LOG_FILE="/var/log/manga-translator-startup.log"

exec > >(tee -a "${LOG_FILE}") 2>&1
echo "=== manga-translator GCP startup: $(date -Is) ==="

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y git curl ca-certificates gnupg lsb-release

# Docker
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# NVIDIA Container Toolkit（GPU VM）
if command -v nvidia-smi >/dev/null 2>&1; then
  if ! dpkg -l | grep -q nvidia-container-toolkit; then
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
      | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
      | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
      > /etc/apt/sources.list.d/nvidia-container-toolkit.list
    apt-get update -y
    apt-get install -y nvidia-container-toolkit
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
  fi
fi

mkdir -p "${REPO_DIR}/result"

META_REPO_URL="$(curl -sf -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/mit-repo-url 2>/dev/null || true)"
MIT_REPO_URL="${META_REPO_URL:-${MIT_REPO_URL:-https://github.com/singitsck/manga-image-translator.git}}"

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  echo "Cloning repository into ${REPO_DIR}..."
  git clone --depth 1 "${MIT_REPO_URL}" "${REPO_DIR}"
fi

cd "${REPO_DIR}"

# 若 metadata 有提供 branch，切換過去
BRANCH="$(curl -sf -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/mit-branch 2>/dev/null || true)"
if [[ -n "${BRANCH}" ]]; then
  git fetch origin "${BRANCH}" && git checkout "${BRANCH}"
fi

# .env 由 deploy.sh 透過 scp 上傳，或手動放在 ${REPO_DIR}/.env
if [[ ! -f .env ]]; then
  echo "WARNING: ${REPO_DIR}/.env not found. Service will start but translation API keys may be missing."
fi

docker compose -f "${COMPOSE_FILE}" pull || true
docker compose -f "${COMPOSE_FILE}" up -d --remove-orphans

echo "=== Startup complete. API should listen on :5003 ==="
