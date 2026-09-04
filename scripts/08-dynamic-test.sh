#!/usr/bin/env bash
set -euo pipefail
# 08-dynamic-test.sh — test dynamically-linked musl binaries running
# against glibc's loader, inside an isolated staged root (not the CI
# host's real /) so the symlink from 06 doesn't clobber the build host.

GUSL_ROOT="${GITHUB_WORKSPACE:-$PWD}"
SOURCES_DIR="$GUSL_ROOT/sources"
WORK_DIR="$GUSL_ROOT/work"
MUSL_SRC="$SOURCES_DIR/musl-src"
ANALYSIS_DIR="$WORK_DIR/analysis"
STAGED_ROOT="$WORK_DIR/staged-root"
TEST_DIR="$WORK_DIR/dynamic-test"

mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

REAL_LDSO="$(cat "$ANALYSIS_DIR/real-ldso-path.txt" 2>/dev/null || true)"
MUSL_INTERP="$(head -n1 "$ANALYSIS_DIR/musl-interp-name.txt" 2>/dev/null || true)"

if [ -z "$REAL_LDSO" ] || [ -z "$MUSL_INTERP" ]; then
    echo "[08] ERROR: missing loader info — run 05 and 06 first" >&2
    exit 1
fi

echo "[08] Real glibc loader: $REAL_LDSO"
echo "[08] Target musl interpreter path: $MUSL_INTERP"

MUSL_INSTALL="$WORK_DIR/musl-ref-install"
MUSL_GCC="$MUSL_INSTALL/bin/musl-gcc"
if [ ! -x "$MUSL_GCC" ]; then
    echo "[08] ERROR: musl-gcc not found — run 07 first (it builds it)" >&2
    exit 1
fi

echo "[08] Writing minimal test program..."
cat > hello.c << 'EOF'
#include <stdio.h>

int main(void) {
    printf("gusl-libc dynamic test: hello from musl (dynamic)\n");
    return 0;
}
EOF

echo "[08] Compiling as dynamically-linked musl binary..."
"$MUSL_GCC" -o hello-dynamic hello.c

echo "[08] Checking the binary's requested interpreter..."
REQUESTED_INTERP="$(readelf -l hello-dynamic 2>/dev/null | grep -A1 'INTERP' | grep -oE '/[a-zA-Z0-9_./-]+' | head -n1 || true)"
echo "[08] Binary requests interpreter: ${REQUESTED_INTERP:-<none found>}"

echo "[08] Setting up isolated staged root for testing..."
mkdir -p "$STAGED_ROOT$(dirname "$MUSL_INTERP")"
ln -sf "$REAL_LDSO" "$STAGED_ROOT$MUSL_INTERP"
echo "[08] Staged symlink: $STAGED_ROOT$MUSL_INTERP -> $REAL_LDSO"

echo "[08] Attempting to run via chroot into staged root..."
if command -v chroot >/dev/null 2>&1 && [ "$(id -u)" = "0" ]; then
    cp hello-dynamic "$STAGED_ROOT/hello-dynamic"
    if chroot "$STAGED_ROOT" /hello-dynamic; then
        echo "[08] PASS: dynamic musl binary ran via patched loader in chroot."
        echo "PASS" > "$ANALYSIS_DIR/dynamic-test-result.txt"
    else
        echo "[08] FAIL: dynamic musl binary failed under chroot (expected —"
        echo "     symbol resolution work from 04 is not yet applied to a live build)." >&2
        echo "FAIL" > "$ANALYSIS_DIR/dynamic-test-result.txt"
    fi
else
    echo "[08] SKIPPED: chroot requires root — recording staged setup only, no execution."
    echo "SKIPPED" > "$ANALYSIS_DIR/dynamic-test-result.txt"
fi

echo "[08] Done. See $ANALYSIS_DIR/dynamic-test-result.txt"
