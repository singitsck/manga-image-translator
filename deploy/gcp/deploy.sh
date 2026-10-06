#!/usr/bin/env bash
# 一鍵在 GCP 建立 GPU VM 並部署 manga-image-translator（本 fork）
#
# 前置需求：
#   1. 已安裝 gcloud CLI 並登入：gcloud auth login
#   2. 已設定專案：export GCP_PROJECT_ID=your-project
#   3. 專案已啟用計費
#   4. 專案根目錄有 .env（可參考 deploy/gcp/env.gcp.example）
#
# 用法：
#   export GCP_PROJECT_ID=my-project
#   export GCP_ZONE=asia-east1-b          # 可選，預設 asia-east1-b
#   ./deploy/gcp/deploy.sh
#
# 選用環境變數：
#   GCP_INSTANCE_NAME   預設 manga-translator-gpu
#   GCP_MACHINE_TYPE    預設 n1-standard-4
#   GCP_GPU_TYPE        預設 nvidia-tesla-t4
#   GCP_GPU_COUNT       預設 1
#   GCP_BOOT_DISK_GB    預設 150
#   MIT_REPO_URL        預設本 fork GitHub URL
#   MIT_BRANCH          預設 main
#   SKIP_FIREWALL=1     不建立防火牆規則

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT_DIR}"

PROJECT_ID="${GCP_PROJECT_ID:-}"
ZONE="${GCP_ZONE:-asia-east1-b}"
INSTANCE_NAME="${GCP_INSTANCE_NAME:-manga-translator-gpu}"
MACHINE_TYPE="${GCP_MACHINE_TYPE:-n1-standard-4}"
GPU_TYPE="${GCP_GPU_TYPE:-nvidia-tesla-t4}"
GPU_COUNT="${GCP_GPU_COUNT:-1}"
BOOT_DISK_GB="${GCP_BOOT_DISK_GB:-150}"
REPO_URL="${MIT_REPO_URL:-https://github.com/singitsck/manga-image-translator.git}"
BRANCH="${MIT_BRANCH:-main}"
STARTUP_SCRIPT="${ROOT_DIR}/deploy/gcp/vm-startup.sh"
FIREWALL_RULE="${GCP_FIREWALL_RULE:-allow-manga-translator-5003}"

if [[ -z "${PROJECT_ID}" ]]; then
  echo "請設定 GCP_PROJECT_ID，例如：export GCP_PROJECT_ID=my-project-id" >&2
  exit 1
fi

if [[ ! -f .env ]]; then
  echo "找不到 ${ROOT_DIR}/.env" >&2
  echo "請先複製 deploy/gcp/env.gcp.example 並填入 MiniMax API Key" >&2
  exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "未安裝 gcloud CLI。請安裝：https://cloud.google.com/sdk/docs/install" >&2
  exit 1
fi

gcloud config set project "${PROJECT_ID}"

echo "啟用必要 API..."
gcloud services enable compute.googleapis.com --quiet

if [[ "${SKIP_FIREWALL:-0}" != "1" ]]; then
  if ! gcloud compute firewall-rules describe "${FIREWALL_RULE}" >/dev/null 2>&1; then
    echo "建立防火牆規則 ${FIREWALL_RULE}（TCP 5003）..."
    gcloud compute firewall-rules create "${FIREWALL_RULE}" \
      --direction=INGRESS \
      --priority=1000 \
      --network=default \
      --action=ALLOW \
      --rules=tcp:5003 \
      --source-ranges=0.0.0.0/0 \
      --target-tags=manga-translator \
      --description="Manga Image Translator API port"
  else
    echo "防火牆規則 ${FIREWALL_RULE} 已存在，略過"
  fi
fi

if gcloud compute instances describe "${INSTANCE_NAME}" --zone="${ZONE}" >/dev/null 2>&1; then
  echo "VM ${INSTANCE_NAME} 已存在於 ${ZONE}"
else
  echo "建立 GPU VM ${INSTANCE_NAME}（${MACHINE_TYPE} + ${GPU_COUNT}x ${GPU_TYPE}）..."
  gcloud compute instances create "${INSTANCE_NAME}" \
    --zone="${ZONE}" \
    --machine-type="${MACHINE_TYPE}" \
    --accelerator="type=${GPU_TYPE},count=${GPU_COUNT}" \
    --maintenance-policy=TERMINATE \
    --provisioning-model=STANDARD \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --tags=manga-translator \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size="${BOOT_DISK_GB}GB" \
    --boot-disk-type=pd-balanced \
    --metadata="mit-repo-url=${REPO_URL},mit-branch=${BRANCH}" \
    --metadata-from-file=startup-script="${STARTUP_SCRIPT}"
fi

echo "等待 VM 開機與 startup script（約 3~8 分鐘，含 Docker 映像拉取）..."
sleep 30

for i in $(seq 1 36); do
  if gcloud compute ssh "${INSTANCE_NAME}" --zone="${ZONE}" --command="test -f /var/log/manga-translator-startup.log" 2>/dev/null; then
    break
  fi
  echo "  等待 SSH / startup... (${i}/36)"
  sleep 10
done

echo "上傳 .env 到 VM..."
gcloud compute scp .env "${INSTANCE_NAME}:~/manga-image-translator.env" --zone="${ZONE}"
gcloud compute ssh "${INSTANCE_NAME}" --zone="${ZONE}" --command="
  sudo mkdir -p /opt/manga-image-translator
  sudo mv ~/manga-image-translator.env /opt/manga-image-translator/.env
  sudo chown root:root /opt/manga-image-translator/.env
  sudo chmod 600 /opt/manga-image-translator/.env
  if [ -d /opt/manga-image-translator/deploy ]; then
    cd /opt/manga-image-translator
    sudo docker compose -f deploy/gcp/docker-compose-gcp-gpu.yml up -d --remove-orphans
  fi
"

EXTERNAL_IP="$(gcloud compute instances describe "${INSTANCE_NAME}" \
  --zone="${ZONE}" \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')"

echo ""
echo "=========================================="
echo "部署完成（或進行中，請查看 VM 日誌）"
echo "  專案：${PROJECT_ID}"
echo "  VM：  ${INSTANCE_NAME} (${ZONE})"
echo "  API： http://${EXTERNAL_IP}:5003"
echo "  文件：http://${EXTERNAL_IP}:5003/docs"
echo ""
echo "查看啟動日誌："
echo "  gcloud compute ssh ${INSTANCE_NAME} --zone=${ZONE} --command='sudo tail -100 /var/log/manga-translator-startup.log'"
echo ""
echo "查看容器狀態："
echo "  gcloud compute ssh ${INSTANCE_NAME} --zone=${ZONE} --command='cd /opt/manga-image-translator && sudo docker compose -f deploy/gcp/docker-compose-gcp-gpu.yml ps'"
echo "=========================================="
