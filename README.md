# gusl-libc

Translation layer letting musl-compiled binaries run on glibc — the
reverse direction of a glibc-on-musl compatibility layer. Instead of
making musl understand glibc binaries, this project patches/builds
glibc so it can host musl-compiled binaries (static and dynamic).

## How it works

1. Analyze musl's real exported symbols and syscall usage (from an
   actual built musl libc.so, not assumptions).
2. Analyze glibc's real symbol set by scanning every `Versions` file
   in the glibc source tree — this is glibc's own source of truth for
   which names it exports, including internal `GLIBC_PRIVATE` symbols.
3. Cross-reference the two lists to find which musl symbol names
   already exist in glibc (no work needed) vs which ones don't
   (need manual alias/compat work).
4. Build glibc, locate its real built `ld.so`, and stage a symlink at
   musl's expected interpreter path (`/lib/ld-musl-x86_64.so.1`) so
   the kernel invokes glibc's loader when running a musl binary.
5. Test static musl binaries directly (they need no loader/symbol
   work — just syscall ABI compatibility, which Linux guarantees).
6. Test dynamic musl binaries against the patched loader, inside an
   isolated staged root/chroot (not the CI host's real `/`).
7. Package the built glibc + all analysis reports as build artifacts.

## Build scripts (scripts/00-09)

| Script | Purpose |
|---|---|
| `00-host-prep.sh` | Install build dependencies on the CI runner |
| `01-fetch-sources.sh` | Download glibc + musl source tarballs |
| `02-analyze-musl-abi.sh` | Build musl, extract its real exported symbols + syscalls |
| `03-toolchain.sh` | Verify host toolchain, prep build dirs |
| `04-patch-glibc-symbols.sh` | Scan glibc's `Versions` files, cross-reference against musl symbols |
| `05-patch-loader.sh` | Record the loader interpreter-symlink plan (musl path → glibc's future ld.so) |
| `06-build-glibc.sh` | Build + install glibc, apply the symlink plan to the real built loader |
| `07-static-test.sh` | Compile + run a static musl test binary directly |
| `08-dynamic-test.sh` | Compile + run a dynamic musl test binary via the patched loader in a staged chroot |
| `09-package.sh` | Bundle the glibc install + analysis reports into `output/` |

## Status

Phase 1 (CLI/simple binaries) pipeline implemented. Symbol aliasing for
names present in musl but absent from glibc's `Versions` files
(`symbols-missing-in-glibc.txt` in the analysis output) is not yet
automated — it's flagged for manual review after each build, since
name-matching alone can't establish semantic equivalence.

## CI

Runs on GitHub Actions (`ubuntu-latest`) via
`.github/workflows/build.yml` — pushes to `main` or manual dispatch.
