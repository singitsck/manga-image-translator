#!/usr/bin/env bash
# 兩全其美啟動器：
#   - macOS / Apple Silicon → 本機 Python + MPS（快）
#   - 其他（Linux / 有 NVIDIA 的機器）→ Docker（好搬、好管）
#
# 共同設定都在專案根目錄 .env，兩邊共用。
set -euo pipefail
cd "$(dirname "$0")"

MODE="${1:-auto}"  # auto | local | docker

usage() {
  cat <<'EOF'
用法: ./start.sh [auto|local|docker]

  auto   （預設）Mac 用本機，其餘用 Docker
  local  強制本機 ./start-lmstudio-local.sh（MPS）
  docker 強制 Docker ./start-docker.sh

共用設定: .env
  OPENAI_* / OPENAI_FALLBACK_* / SKIP_LANG / CONTEXT_SIZE
EOF
}

if [[ "${MODE}" == "-h" || "${MODE}" == "--help" ]]; then
  usage
  exit 0
fi

pick_auto() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"
  if [[ "${os}" == "Darwin" ]]; then
    echo "local"
  else
    echo "docker"
  fi
}

if [[ "${MODE}" == "auto" ]]; then
  MODE="$(pick_auto)"
  echo "auto → ${MODE}  ($(uname -s)/$(uname -m))"
fi

case "${MODE}" in
  local)
    exec ./start-lmstudio-local.sh
    ;;
  docker)
    exec ./start-docker.sh
    ;;
  *)
    echo "未知模式: ${MODE}"
    usage
    exit 1
    ;;
esac
