#!/usr/bin/env bash
# 啟用專案內 Miniforge 環境（.conda-env）
# 用法: source ./activate-miniforge.sh
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "請用 source 執行: source ./activate-miniforge.sh" >&2
  exit 1
fi

_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ENV_PREFIX="${_PROJECT_ROOT}/.conda-env"

if [[ ! -x "${_ENV_PREFIX}/bin/python" ]]; then
  echo "找不到 ${_ENV_PREFIX}，請先執行: ./setup-miniforge.sh" >&2
  return 1 2>/dev/null || exit 1
fi

# 若已在 PATH 有 conda，用 hook 啟用（較完整）
if command -v conda >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  eval "$(conda shell.bash hook 2>/dev/null)" || true
  conda activate "${_ENV_PREFIX}" 2>/dev/null && return 0
fi

# 無 conda hook 時，直接改 PATH
export PATH="${_ENV_PREFIX}/bin:${PATH}"
export CONDA_PREFIX="${_ENV_PREFIX}"
unset PYTHONHOME
hash -r 2>/dev/null || true
