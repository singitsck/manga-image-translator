#!/usr/bin/env bash
# 刪除 GCP 上的 manga-translator VM（可選刪除防火牆規則）
#
# 用法：
#   export GCP_PROJECT_ID=my-project
#   ./deploy/gcp/teardown.sh

set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-}"
ZONE="${GCP_ZONE:-asia-east1-b}"
INSTANCE_NAME="${GCP_INSTANCE_NAME:-manga-translator-gpu}"
FIREWALL_RULE="${GCP_FIREWALL_RULE:-allow-manga-translator-5003}"
DELETE_FIREWALL="${DELETE_FIREWALL:-0}"

if [[ -z "${PROJECT_ID}" ]]; then
  echo "請設定 GCP_PROJECT_ID" >&2
  exit 1
fi

gcloud config set project "${PROJECT_ID}"

if gcloud compute instances describe "${INSTANCE_NAME}" --zone="${ZONE}" >/dev/null 2>&1; then
  echo "刪除 VM ${INSTANCE_NAME}..."
  gcloud compute instances delete "${INSTANCE_NAME}" --zone="${ZONE}" --quiet
else
  echo "VM ${INSTANCE_NAME} 不存在"
fi

if [[ "${DELETE_FIREWALL}" == "1" ]]; then
  if gcloud compute firewall-rules describe "${FIREWALL_RULE}" >/dev/null 2>&1; then
    gcloud compute firewall-rules delete "${FIREWALL_RULE}" --quiet
  fi
fi

echo "完成"
