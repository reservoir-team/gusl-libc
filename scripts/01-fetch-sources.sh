#!/usr/bin/env bash
set -euo pipefail
# 01-fetch-sources.sh — download glibc + musl source

GUSL_ROOT="${GITHUB_WORKSPACE:-$PWD}"
SOURCES_DIR="$GUSL_ROOT/sources"
mkdir -p "$SOURCES_DIR"
cd "$SOURCES_DIR"

GLIBC_VERSION="2.39"
MUSL_VERSION="1.2.5"

echo "[01] Downloading glibc $GLIBC_VERSION..."
if [ ! -f "glibc-${GLIBC_VERSION}.tar.xz" ]; then
    wget -q "https://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.xz" \
        -O "glibc-${GLIBC_VERSION}.tar.xz"
fi

echo "[01] Downloading musl $MUSL_VERSION..."
if [ ! -f "musl-${MUSL_VERSION}.tar.gz" ]; then
    wget -q "https://musl.libc.org/releases/musl-${MUSL_VERSION}.tar.gz" \
        -O "musl-${MUSL_VERSION}.tar.gz"
fi

echo "[01] Extracting glibc..."
rm -rf glibc-src
mkdir -p glibc-src
tar -xf "glibc-${GLIBC_VERSION}.tar.xz" -C glibc-src --strip-components=1

echo "[01] Extracting musl..."
rm -rf musl-src
mkdir -p musl-src
tar -xf "musl-${MUSL_VERSION}.tar.gz" -C musl-src --strip-components=1

echo "[01] Sources ready:"
echo "     glibc -> $SOURCES_DIR/glibc-src"
echo "     musl  -> $SOURCES_DIR/musl-src"
