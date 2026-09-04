#!/usr/bin/env bash
set -euo pipefail
# 04-patch-glibc-symbols.sh — generate musl-compat symbol mapping from
# glibc's own Versions files (real data, not guessed names)

GUSL_ROOT="${GITHUB_WORKSPACE:-$PWD}"
SOURCES_DIR="$GUSL_ROOT/sources"
WORK_DIR="$GUSL_ROOT/work"
GLIBC_SRC="$SOURCES_DIR/glibc-src"
ANALYSIS_DIR="$WORK_DIR/analysis"

if [ ! -d "$GLIBC_SRC" ]; then
    echo "[04] ERROR: glibc source not found — run 01-fetch-sources.sh first" >&2
    exit 1
fi
if [ ! -f "$ANALYSIS_DIR/musl-symbols.txt" ]; then
    echo "[04] ERROR: musl symbol list not found — run 02-analyze-musl-abi.sh first" >&2
    exit 1
fi

mkdir -p "$ANALYSIS_DIR"

echo "[04] Locating all 'Versions' files in glibc source tree..."
find "$GLIBC_SRC" -type f -name "Versions" > "$ANALYSIS_DIR/glibc-versions-files.txt"
echo "[04] Found $(wc -l < "$ANALYSIS_DIR/glibc-versions-files.txt") Versions files."

echo "[04] Extracting every real symbol name declared inside them..."
# A Versions file looks like:
#   libc {
#     GLIBC_2.2.5 {
#       foo; bar; baz;
#     }
#     GLIBC_PRIVATE {
#       __internal_foo;
#     }
#   }
# We pull every identifier that appears before a ';' inside these blocks.
GLIBC_ALL_SYMS="$ANALYSIS_DIR/glibc-all-symbols.txt"
> "$GLIBC_ALL_SYMS"
while IFS= read -r vfile; do
    grep -oE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*;' "$vfile" 2>/dev/null \
        | tr -d ' ;' \
        >> "$GLIBC_ALL_SYMS" || true
done < "$ANALYSIS_DIR/glibc-versions-files.txt"
sort -u -o "$GLIBC_ALL_SYMS" "$GLIBC_ALL_SYMS"
echo "[04] Extracted $(wc -l < "$GLIBC_ALL_SYMS") unique glibc symbol names."

echo "[04] Separating GLIBC_PRIVATE-only symbols (internal, needed for aliasing)..."
GLIBC_PRIVATE_SYMS="$ANALYSIS_DIR/glibc-private-symbols.txt"
> "$GLIBC_PRIVATE_SYMS"
while IFS= read -r vfile; do
    awk '/GLIBC_PRIVATE[[:space:]]*\{/{flag=1; next} /\}/{flag=0} flag' "$vfile" 2>/dev/null \
        | grep -oE '[A-Za-z_][A-Za-z0-9_]*' >> "$GLIBC_PRIVATE_SYMS" || true
done < "$ANALYSIS_DIR/glibc-versions-files.txt"
sort -u -o "$GLIBC_PRIVATE_SYMS" "$GLIBC_PRIVATE_SYMS"
echo "[04] Found $(wc -l < "$GLIBC_PRIVATE_SYMS") GLIBC_PRIVATE symbols."

echo "[04] Cross-referencing musl symbol names against real glibc symbol set..."
MATCHED="$ANALYSIS_DIR/symbols-matched.txt"
MISSING="$ANALYSIS_DIR/symbols-missing-in-glibc.txt"
comm -12 "$ANALYSIS_DIR/musl-symbols.txt" "$GLIBC_ALL_SYMS" > "$MATCHED"
comm -23 "$ANALYSIS_DIR/musl-symbols.txt" "$GLIBC_ALL_SYMS" > "$MISSING"
echo "[04] Matched (same name already in glibc): $(wc -l < "$MATCHED")"
echo "[04] Missing (musl name not found in glibc Versions at all): $(wc -l < "$MISSING")"

echo "[04] Writing gusl-compat shim source into glibc tree..."
SHIM_DIR="$GLIBC_SRC/gusl-compat"
mkdir -p "$SHIM_DIR"
SHIM_FILE="$SHIM_DIR/musl_symbol_report.md"

cat > "$SHIM_FILE" << EOF
# gusl-libc symbol report (generated $(date -u +%Y-%m-%dT%H:%M:%SZ))

Source of truth: every `.` semicolon-terminated identifier found inside
this glibc checkout's own \`Versions\` files (found via \`find -name Versions\`),
cross-referenced against musl's actual exported dynamic symbols (from
02-analyze-musl-abi.sh's \`nm -D\` output on a real built musl libc.so).

- Total glibc symbol names found in Versions files: $(wc -l < "$GLIBC_ALL_SYMS")
- Of which GLIBC_PRIVATE (internal-only): $(wc -l < "$GLIBC_PRIVATE_SYMS")
- musl symbols with an identically-named glibc symbol: $(wc -l < "$MATCHED")
- musl symbols with NO matching name anywhere in glibc: $(wc -l < "$MISSING")

Matched symbols need no aliasing — glibc already exports the same name
(glibc's own Versions mechanism, e.g. \`weak_alias(__strverscmp, strverscmp)\`,
already surfaces the plain POSIX name in most cases).

Missing symbols (listed in symbols-missing-in-glibc.txt) are the real
work item for gusl-libc: each one needs to be checked manually against
glibc's actual implementation to find which internal function (if any)
provides equivalent behavior, since automated name-matching cannot
determine semantic equivalence — only name presence/absence.
EOF

echo "[04] Report written to $SHIM_FILE"
echo "[04] Full symbol data in $ANALYSIS_DIR/"
echo "[04] Done."
