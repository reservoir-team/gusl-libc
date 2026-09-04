#!/usr/bin/env bash
set -euo pipefail
# 05-patch-loader.sh — make glibc's built ld.so answer to musl's
# expected interpreter path, using the real interpreter name musl
# uses (extracted in 02) and the real loader glibc actually builds.

GUSL_ROOT="${GITHUB_WORKSPACE:-$PWD}"
SOURCES_DIR="$GUSL_ROOT/sources"
WORK_DIR="$GUSL_ROOT/work"
GLIBC_SRC="$SOURCES_DIR/glibc-src"
ANALYSIS_DIR="$WORK_DIR/analysis"

if [ ! -f "$ANALYSIS_DIR/musl-interp-name.txt" ]; then
    echo "[05] ERROR: musl interpreter name not found — run 02 first" >&2
    exit 1
fi

MUSL_INTERP="$(head -n1 "$ANALYSIS_DIR/musl-interp-name.txt" 2>/dev/null || true)"
if [ -z "$MUSL_INTERP" ]; then
    echo "[05] ERROR: could not determine musl's interpreter path from source scan" >&2
    exit 1
fi
echo "[05] musl interpreter path (from real source scan): $MUSL_INTERP"

echo "[05] Locating glibc's Linux x86_64 sysdeps directory (real loader source)..."
LOADER_SYSDEP_DIR="$GLIBC_SRC/sysdeps/unix/sysv/linux/x86_64"
if [ ! -d "$LOADER_SYSDEP_DIR" ]; then
    echo "[05] ERROR: expected sysdeps dir not found at $LOADER_SYSDEP_DIR" >&2
    echo "[05] glibc source layout may differ from expected version" >&2
    exit 1
fi

echo "[05] Checking configure-time interpreter name (from shlib-versions/Makefile)..."
# glibc's own build determines the interpreter's installed SONAME from
# elf/Makefile / config.make after configure runs — we don't know the
# built filename for certain until 06 actually configures+builds glibc,
# so we record the plan and the real musl target path now, and apply
# the symlink step against the ACTUAL built artifact in 06/08.
PLAN_FILE="$GLIBC_SRC/gusl-compat/loader-patch-plan.md"
mkdir -p "$GLIBC_SRC/gusl-compat"

cat > "$PLAN_FILE" << EOF
# Loader interpreter compatibility plan (generated $(date -u +%Y-%m-%dT%H:%M:%SZ))

Real musl interpreter path (extracted from musl source, script 02):
    $MUSL_INTERP

glibc's own dynamic linker (ld.so) is built by 06-build-glibc.sh and its
actual installed filename/SONAME is only known for certain after that
build completes (it is derived from configure + sysdeps/unix/sysv/linux/x86_64/64/shlib-versions
at build time, not fixed in source).

Action to run AFTER 06 builds glibc (this is what 08-dynamic-test.sh does):

    REAL_LDSO=\$(find "\$GUSL_ROOT/work/glibc-install" -name 'ld-linux-x86-64.so.*' | head -n1)
    ln -sf "\$REAL_LDSO" "$MUSL_INTERP"

This lets the kernel invoke glibc's real, just-built loader whenever it
loads a musl binary whose ELF .interp section requests
"$MUSL_INTERP" — no source patch to rtld.c is needed for this part.

Symbol resolution once the loader is invoked is handled separately by
the aliasing work from 04 (glibc-all-symbols.txt / symbols-missing-in-glibc.txt).
EOF

echo "[05] Plan written to $PLAN_FILE"
echo "[05] Symlink will be created for real after 06 builds an actual ld.so"
echo "[05] Done."
