#!/usr/bin/env bash
set -euo pipefail
# 02-analyze-musl-abi.sh — extract musl symbol/syscall list

GUSL_ROOT="${GITHUB_WORKSPACE:-$PWD}"
SOURCES_DIR="$GUSL_ROOT/sources"
WORK_DIR="$GUSL_ROOT/work"
MUSL_SRC="$SOURCES_DIR/musl-src"

mkdir -p "$WORK_DIR/analysis"

echo "[02] Building musl (reference build, to get a real .so with symbols)..."
cd "$MUSL_SRC"
if [ ! -f "lib/libc.so" ]; then
    ./configure --prefix="$WORK_DIR/musl-ref-install" > "$WORK_DIR/analysis/musl-configure.log" 2>&1
    make -j"$(nproc)" > "$WORK_DIR/analysis/musl-build.log" 2>&1
fi

echo "[02] Extracting dynamic symbol list from musl libc.so..."
nm -D --defined-only lib/libc.so | awk '{print $3}' | sort -u \
    > "$WORK_DIR/analysis/musl-symbols.txt"

echo "[02] Extracting syscall numbers referenced in musl source..."
grep -rhoE '__NR_[a-zA-Z0-9_]+' arch/ include/ src/ 2>/dev/null \
    | sort -u > "$WORK_DIR/analysis/musl-syscalls.txt" || true

echo "[02] Recording musl's dynamic linker interpreter name..."
grep -rho '/lib/ld-musl-[a-zA-Z0-9_.\-]*\.so\.1' "$MUSL_SRC" 2>/dev/null \
    | sort -u > "$WORK_DIR/analysis/musl-interp-name.txt" || true

echo "[02] Summary:"
echo "     Symbols found:  $(wc -l < "$WORK_DIR/analysis/musl-symbols.txt")"
echo "     Syscalls found: $(wc -l < "$WORK_DIR/analysis/musl-syscalls.txt")"
echo "     -> $WORK_DIR/analysis/"
