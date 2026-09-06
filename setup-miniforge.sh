#!/usr/bin/env bash
# 用 Miniforge / conda-forge 建立專案內隔離環境（.conda-env）
# 與系統 Python、Homebrew、舊 venv 分離；PyTorch 走 conda-forge（macOS MPS）
set -euo pipefail
cd "$(dirname "$0")"

ENV_PREFIX="$(pwd)/.conda-env"
CONDA_EXE=""

find_conda() {
  if [[ -n "${CONDA_EXE:-}" && -x "${CONDA_EXE}" ]]; then
    return 0
  fi
  local candidates=(
    "${CONDA:-}"
    "$(command -v mamba 2>/dev/null || true)"
    "$(command -v conda 2>/dev/null || true)"
    "${HOME}/miniforge3/bin/mamba"
    "${HOME}/miniforge3/bin/conda"
    "${HOME}/miniforge3/condabin/conda"
    "/opt/homebrew/Caskroom/miniforge/base/bin/mamba"
    "/opt/homebrew/Caskroom/miniforge/base/bin/conda"
    "/usr/local/Caskroom/miniforge/base/bin/mamba"
    "/usr/local/Caskroom/miniforge/base/bin/conda"
  )
  for c in "${candidates[@]}"; do
    [[ -n "${c}" && -x "${c}" ]] || continue
    CONDA_EXE="${c}"
    return 0
  done
  return 1
}

if ! find_conda; then
  cat <<'EOF'
找不到 Miniforge / conda / mamba。

請先安裝 Miniforge（Apple Silicon 建議）：
  https://github.com/conda-forge/miniforge#download

安裝後重新開啟終端機，或執行：
  source ~/miniforge3/etc/profile.d/conda.sh

再執行：
  ./setup-miniforge.sh
EOF
  exit 1
fi

echo "Using: ${CONDA_EXE}"
echo "Env prefix: ${ENV_PREFIX}"

if [[ -x "${ENV_PREFIX}/bin/python" ]]; then
  echo "Updating existing conda env..."
  "${CONDA_EXE}" env update --prefix "${ENV_PREFIX}" -f environment.yml --prune -y
else
  echo "Creating conda env..."
  "${CONDA_EXE}" env create --prefix "${ENV_PREFIX}" -f environment.yml -y
fi

PIP="${ENV_PREFIX}/bin/pip"
REQ_FILE="requirements.txt"
if [[ "$(uname -s)" == "Darwin" ]]; then
  REQ_FILE="requirements-mac.txt"
fi

echo "Installing pip dependencies from ${REQ_FILE}..."
"${PIP}" install --upgrade pip wheel setuptools
"${PIP}" install -r "${REQ_FILE}"

echo ""
echo "Done. Activate with:"
echo "  source ./activate-miniforge.sh"
echo "Or start server directly:"
echo "  ./start.sh local"
