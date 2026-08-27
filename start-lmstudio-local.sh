#!/usr/bin/env bash
# 本機啟動 manga-image-translator（Apple MPS + .env 內的翻譯 API）
set -euo pipefail
cd "$(dirname "$0")"
source venv/bin/activate

# 若 .env 存在會由程式自動載入；這裡再保險 export 一次
set -a
# shellcheck disable=SC1091
[ -f .env ] && source .env
set +a

# CONTEXT_SIZE：帶入前幾頁作為翻譯上下文（僅 chatgpt / chatgpt_2stage 有效）
CONTEXT_SIZE="${CONTEXT_SIZE:-5}"

echo "Translator API: ${OPENAI_API_BASE:-unset} model=${OPENAI_MODEL:-unset} context_size=${CONTEXT_SIZE}"

exec python -u server/main.py \
  --verbose \
  --start-instance \
  --host=0.0.0.0 \
  --port=5003 \
  --nonce None \
  --use-gpu \
  --context-size "${CONTEXT_SIZE}"
