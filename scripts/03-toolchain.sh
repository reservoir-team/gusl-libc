#!/usr/bin/env bash
set -euo pipefail
# 03-toolchain.sh — prepare build toolchain

GUSL_ROOT="${GITHUB_WORKSPACE:-$PWD}"
WORK_DIR="$GUSL_ROOT/work"

echo "[03] Verifying host toolchain..."
for tool in gcc g++ make bison gawk makeinfo; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[03] ERROR: missing required tool: $tool" >&2
        exit 1
    fi
done

echo "[03] Toolchain versions:"
gcc --version | head -n1
g++ --version | head -n1
make --version | head -n1
bison --version | head -n1

echo "[03] Preparing glibc build directory (out-of-tree build)..."
mkdir -p "$WORK_DIR/glibc-build"

echo "[03] Toolchain check complete."
