#!/usr/bin/env bash
set -euo pipefail
# 00-host-prep.sh — check host deps, prepare work/output dirs

echo "[00] Updating package lists..."
sudo apt-get update && sudo apt-get upgrade -y

echo "[00] Installing build dependencies..."
sudo apt-get install -y \
    build-essential \
    gcc-12 g++-12 \
    make \
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

echo "[00] Pinning gcc-12/g++-12 as default gcc/g++ (glibc build compatibility)..."
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 100
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 100
sudo update-alternatives --set gcc /usr/bin/gcc-12
sudo update-alternatives --set g++ /usr/bin/g++-12

echo "[00] Preparing work directories..."
export GUSL_ROOT="${GITHUB_WORKSPACE:-$PWD}"
mkdir -p "$GUSL_ROOT/work"
mkdir -p "$GUSL_ROOT/sources"
mkdir -p "$GUSL_ROOT/output"

echo "[00] Verifying toolchain..."
gcc --version
make --version

echo "[00] Host prep complete."
