#!/usr/bin/env bash
# start-lmstudio-local.sh 的 Docker 對應版
set -euo pipefail
cd "$(dirname "$0")"

COMPOSE_FILE="demo/doc/docker-compose-web-with-lmstudio.yml"

if [[ ! -f .env ]]; then
  echo "缺少 .env，請先設定 MiniMax / fallback 參數"
  exit 1
fi

# 匯出給 compose 變數替換用（不印出 API key）
set -a
# shellcheck disable=SC1091
source .env
set +a

CONTEXT_SIZE="${CONTEXT_SIZE:-5}"
NUM_WORKERS="${NUM_WORKERS:-2}"
echo "Docker translator: base=${OPENAI_API_BASE:-unset} model=${OPENAI_MODEL:-unset}"
echo "Fallback LM Studio: host.docker.internal:${OPENAI_FALLBACK_PORT:-4321} model=${OPENAI_FALLBACK_MODEL:-unset} context_size=${CONTEXT_SIZE} workers=${NUM_WORKERS}"
echo "注意：Mac Docker 為 CPU（無 MPS），影像處理通常比 ./start-lmstudio-local.sh 慢"

# 避免本機 python 服務佔埠
if lsof -iTCP:5003 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "埠 5003 已被占用，請先停掉本機服務（Ctrl+C 或 pkill -f 'server/main.py'）"
  exit 1
fi

exec docker compose -f "${COMPOSE_FILE}" up
