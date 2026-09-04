#!/usr/bin/env bash
set -euo pipefail
# 09-package.sh — bundle final build output + analysis reports

GUSL_ROOT="${GITHUB_WORKSPACE:-$PWD}"
WORK_DIR="$GUSL_ROOT/work"
OUTPUT_DIR="$GUSL_ROOT/output"
INSTALL_DIR="$WORK_DIR/glibc-install"
ANALYSIS_DIR="$WORK_DIR/analysis"

mkdir -p "$OUTPUT_DIR"

echo "[09] Checking build artifacts exist..."
if [ ! -d "$INSTALL_DIR" ]; then
    echo "[09] ERROR: no glibc install found — run 06 first" >&2
    exit 1
fi

echo "[09] Packaging glibc install tree..."
tar -C "$WORK_DIR" -czf "$OUTPUT_DIR/gusl-libc-glibc-install.tar.gz" "$(basename "$INSTALL_DIR")"

echo "[09] Packaging analysis reports (symbol data, test results)..."
if [ -d "$ANALYSIS_DIR" ]; then
    tar -C "$WORK_DIR" -czf "$OUTPUT_DIR/gusl-libc-analysis.tar.gz" "$(basename "$ANALYSIS_DIR")"
fi

echo "[09] Writing build summary..."
SUMMARY="$OUTPUT_DIR/BUILD_SUMMARY.md"
cat > "$SUMMARY" << EOF
# gusl-libc build summary

Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Test results
- Static musl binary test: $(cat "$ANALYSIS_DIR/static-test-result.txt" 2>/dev/null || echo "not run")
- Dynamic musl binary test: $(cat "$ANALYSIS_DIR/dynamic-test-result.txt" 2>/dev/null || echo "not run")

## Symbol analysis
- musl symbols found: $(wc -l < "$ANALYSIS_DIR/musl-symbols.txt" 2>/dev/null || echo "?")
- glibc symbols found (from Versions files): $(wc -l < "$ANALYSIS_DIR/glibc-all-symbols.txt" 2>/dev/null || echo "?")
- Matched (no work needed): $(wc -l < "$ANALYSIS_DIR/symbols-matched.txt" 2>/dev/null || echo "?")
- Missing (needs manual alias work): $(wc -l < "$ANALYSIS_DIR/symbols-missing-in-glibc.txt" 2>/dev/null || echo "?")

## Artifacts in this package
- gusl-libc-glibc-install.tar.gz — the built, patched glibc install tree
- gusl-libc-analysis.tar.gz — full symbol lists, test logs, generated reports
EOF

echo "[09] Package complete. Contents of $OUTPUT_DIR:"
ls -la "$OUTPUT_DIR"
