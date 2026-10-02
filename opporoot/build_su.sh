#!/usr/bin/env bash
# ============================================================================
# build_su.sh — build the `opporoot` su helper with the NDK clang
#
# Toolchain note (verified 2026-10-02):
#   ~/toolchains/clang is "clang version 10.0.7 for Android NDK"
#   (Snapdragon LLVM ARM Compiler 10.0.7).  It ships bin/ + lib/ only: there is
#   NO Android sysroot (no libc.a, no crt*.o), so `--target=aarch64-linux-android29
#   -static` cannot link.  We therefore drive this same NDK clang with the host's
#   aarch64-linux-gnu sysroot and link statically, which is the exact recipe that
#   already produced the working /data/local/tmp/mediaenum probe binary on device.
#
# Output: out-pafm00/su/su (+ sha256)
# ============================================================================
set -euo pipefail

# readelf/file output is localized; force C locale so the checks below match
export LC_ALL=C LANG=C

TREE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TREE}/out-pafm00/su"
CLANG="${CLANG:-$HOME/toolchains/clang/bin/clang}"
SYSROOT="${SYSROOT:-/usr/aarch64-linux-gnu}"
GCCLIB="${GCCLIB:-$(ls -d /usr/lib/gcc-cross/aarch64-linux-gnu/*/ 2>/dev/null | head -1)}"

mkdir -p "${OUT}"
LOG="${OUT}/build_su.log"
log(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }
die(){ log "FATAL: $*"; exit 1; }

[ -x "${CLANG}" ]  || die "clang not found: ${CLANG}"
[ -d "${SYSROOT}" ] || die "sysroot not found: ${SYSROOT} (apt install libc6-dev-arm64-cross)"
[ -n "${GCCLIB}" ] && [ -d "${GCCLIB}" ] || die "aarch64 gcc runtime not found (apt install gcc-aarch64-linux-gnu)"
[ -f "${TREE}/opporoot/su.c" ] || die "opporoot/su.c missing"

log "clang: $("${CLANG}" --version | head -1)"
log "sysroot: ${SYSROOT}, gcc runtime: ${GCCLIB}"

"${CLANG}" \
	--target=aarch64-linux-gnu \
	--sysroot="${SYSROOT}" \
	-B"${GCCLIB}" -L"${GCCLIB}" \
	-static -O2 -Wall -Wextra \
	-o "${OUT}/su" "${TREE}/opporoot/su.c" >>"$LOG" 2>&1 \
	|| die "compile failed, see ${LOG}"

file "${OUT}/su" | tee -a "$LOG"
readelf -h "${OUT}/su" | grep -E "Class|Machine|Type" | tee -a "$LOG"

# must be a static aarch64 executable: no PT_INTERP, no NEEDED
if readelf -l "${OUT}/su" | grep -q INTERP; then
	die "su is dynamically linked (PT_INTERP present)"
fi
if readelf -d "${OUT}/su" 2>/dev/null | grep -q NEEDED; then
	die "su has shared-library dependencies"
fi

sha256sum "${OUT}/su" | tee -a "$LOG"
log "OK -> ${OUT}/su"
log "push:  adb push ${OUT}/su /data/local/tmp/su && adb shell chmod 755 /data/local/tmp/su"
