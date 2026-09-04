#!/usr/bin/env bash
set -euo pipefail
# 00-host-prep.sh — check host deps, prepare work/output dirs

echo "[00] Updating package lists..."
apt-get update && apt-get upgrade -y

echo "[00] Installing build dependencies..."
apt-get install -y \
    build-essential \
    gcc g++ make \
    gawk bison texinfo \
    wget curl \
    git \
    python3 \
    gperf \
    bc \
    rsync \
    file \
    patch \
    xz-utils \
    pkg-config

echo "[00] Preparing work directories..."
export GUSL_ROOT="${GITHUB_WORKSPACE:-$PWD}"
mkdir -p "$GUSL_ROOT/work"
mkdir -p "$GUSL_ROOT/sources"
mkdir -p "$GUSL_ROOT/output"

echo "[00] Verifying toolchain..."
gcc --version
make --version

echo "[00] Host prep complete."
