#!/usr/bin/env bash
set -euo pipefail
# 07-static-test.sh — test statically-linked musl binaries.
# These should work with zero translation work, since a static binary
# has no dynamic loader dependency and only needs the kernel syscall
# ABI to match (which it does on Linux x86_64 regardless of libc).

GUSL_ROOT="${GITHUB_WORKSPACE:-$PWD}"
SOURCES_DIR="$GUSL_ROOT/sources"
WORK_DIR="$GUSL_ROOT/work"
MUSL_SRC="$SOURCES_DIR/musl-src"
TEST_DIR="$WORK_DIR/static-test"

mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "[07] Locating musl-gcc wrapper (built by musl's own build)..."
MUSL_INSTALL="$WORK_DIR/musl-ref-install"
MUSL_GCC="$MUSL_INSTALL/bin/musl-gcc"

if [ ! -x "$MUSL_GCC" ]; then
    echo "[07] musl-gcc not found — building musl properly with install target..."
    cd "$MUSL_SRC"
    ./configure --prefix="$MUSL_INSTALL" > "$WORK_DIR/musl-install-configure.log" 2>&1
    make -j"$(nproc)" > "$WORK_DIR/musl-install-build.log" 2>&1
    make install > "$WORK_DIR/musl-install-install.log" 2>&1
    cd "$TEST_DIR"
fi

if [ ! -x "$MUSL_GCC" ]; then
    echo "[07] ERROR: musl-gcc still not available after install — aborting" >&2
    exit 1
fi

echo "[07] Writing minimal test program..."
cat > hello.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    printf("gusl-libc static test: hello from musl\n");
    char buf[64];
    strcpy(buf, "syscall path check");
    printf("strcpy result: %s\n", buf);
    void *p = malloc(128);
    if (!p) {
        fprintf(stderr, "malloc failed\n");
        return 1;
    }
    free(p);
    printf("malloc/free OK\n");
    return 0;
}
EOF

echo "[07] Compiling statically with musl-gcc..."
"$MUSL_GCC" -static -o hello-static hello.c

echo "[07] Verifying binary has no dynamic interpreter (true static)..."
if file hello-static | grep -qi "statically linked"; then
    echo "[07] Confirmed: statically linked binary."
else
    echo "[07] WARNING: binary may not be fully static — check with 'file hello-static'"
fi

echo "[07] Running static musl binary directly on this glibc host..."
if ./hello-static; then
    echo "[07] PASS: static musl binary ran successfully."
    echo "PASS" > "$WORK_DIR/analysis/static-test-result.txt"
else
    echo "[07] FAIL: static musl binary did not run correctly." >&2
    echo "FAIL" > "$WORK_DIR/analysis/static-test-result.txt"
    exit 1
fi
