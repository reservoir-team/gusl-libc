#!/usr/bin/env bash
set -euo pipefail
# 06-build-glibc.sh — compile patched glibc, install to local prefix,
# then apply the loader symlink plan from 05 against the real built ld.so

GUSL_ROOT="${GITHUB_WORKSPACE:-$PWD}"
SOURCES_DIR="$GUSL_ROOT/sources"
WORK_DIR="$GUSL_ROOT/work"
GLIBC_SRC="$SOURCES_DIR/glibc-src"
BUILD_DIR="$WORK_DIR/glibc-build"
INSTALL_DIR="$WORK_DIR/glibc-install"
ANALYSIS_DIR="$WORK_DIR/analysis"

if [ ! -d "$GLIBC_SRC" ]; then
    echo "[06] ERROR: glibc source not found — run 01-fetch-sources.sh first" >&2
    exit 1
fi

mkdir -p "$BUILD_DIR" "$INSTALL_DIR"

echo "[06] Applying known-bug patch: syslog.c always_inline failure..."
echo "     (glibc 2.39 bug: ldbl_strong_alias on syslog fails to inline"
echo "     under -O2 with fortify flags — same bug reported against"
echo "     glibc 2.33-2.37 on Arch/Gentoo, still present in 2.39)"
SYSLOG_FILE="$GLIBC_SRC/misc/syslog.c"
if [ -f "$SYSLOG_FILE" ]; then
    if grep -q "^ldbl_strong_alias (__syslog, syslog)$" "$SYSLOG_FILE"; then
        sed -i '/^ldbl_strong_alias (__syslog, syslog)$/d' "$SYSLOG_FILE"
        echo "[06] Patched: removed problematic ldbl_strong_alias line from syslog.c"
    else
        echo "[06] Pattern not found verbatim — checking for patched state..."
        if grep -q "ldbl_strong_alias (__syslog, syslog)" "$SYSLOG_FILE"; then
            echo "[06] WARNING: line exists but didn't match exactly — inspect manually:" >&2
            grep -n "ldbl_strong_alias (__syslog, syslog)" "$SYSLOG_FILE" >&2
        else
            echo "[06] Line already absent — syslog.c already patched, skipping."
        fi
    fi
else
    echo "[06] ERROR: $SYSLOG_FILE not found — glibc source tree layout unexpected" >&2
    exit 1
fi

cd "$BUILD_DIR"

echo "[06] Configuring glibc (out-of-tree build)..."
"$GLIBC_SRC/configure" \
    --prefix="$INSTALL_DIR" \
    --disable-werror \
    --enable-kernel=4.14 \
    2>&1 | tee "$WORK_DIR/glibc-configure.log"

echo "[06] Building glibc (this takes a while)..."
make -j"$(nproc)" 2>&1 | tee "$WORK_DIR/glibc-build.log"

echo "[06] Installing glibc to $INSTALL_DIR..."
make install 2>&1 | tee "$WORK_DIR/glibc-install.log"

echo "[06] Locating the real built dynamic loader (ld.so)..."
REAL_LDSO="$(find "$INSTALL_DIR" -name 'ld-linux-x86-64.so.*' | head -n1)"
if [ -z "$REAL_LDSO" ]; then
    echo "[06] ERROR: built ld.so not found under $INSTALL_DIR" >&2
    exit 1
fi
echo "[06] Real built loader: $REAL_LDSO"
echo "$REAL_LDSO" > "$ANALYSIS_DIR/real-ldso-path.txt"

echo "[06] Applying loader symlink plan from 05..."
MUSL_INTERP="$(head -n1 "$ANALYSIS_DIR/musl-interp-name.txt" 2>/dev/null || true)"
if [ -n "$MUSL_INTERP" ]; then
    MUSL_INTERP_DIR="$(dirname "$MUSL_INTERP")"
    STAGED_INTERP_DIR="$WORK_DIR/staged-root${MUSL_INTERP_DIR}"
    mkdir -p "$STAGED_INTERP_DIR"
    ln -sf "$REAL_LDSO" "$WORK_DIR/staged-root${MUSL_INTERP}"
    echo "[06] Symlink staged at: $WORK_DIR/staged-root${MUSL_INTERP} -> $REAL_LDSO"
    echo "[06] (Staged under work/staged-root/ — 07/08 tests apply this at real / when run in a container/chroot, not on the CI host's actual /)"
else
    echo "[06] WARNING: musl interpreter name unknown — skipping symlink staging"
fi

echo "[06] glibc build complete."
echo "     Install dir: $INSTALL_DIR"
echo "     Loader:      $REAL_LDSO"
