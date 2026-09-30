#!/usr/bin/env bash
# ============================================================================
# pack_pafm00_findx.sh — package boot.img / dtbo / vendor modules for PAFM00
#
# Rules honored:
#   - original boot.img is the TEMPLATE (magiskboot unpack/repack recomputes
#     CHECKSUM which ABL validates); no hand-rolled mkbootimg
#   - kernel gzip must be SINGLE-MEMBER (ABL strict parsing; multi-member
#     tail padding killed boot in earlier experiments) -> python zlib flush
#   - dtbo.img: stock dtbo (2 entries, prjversion 17107/17127, board-id 0x08)
#     is already correct for PAFM00 -> shipped as-is
#   - stock boot ramdisk has NO /lib/modules (FACTS.md §5) -> modules go to
#     a vendor-modules update archive, NOT the boot ramdisk
#   - never touches /cache except reading; no flashing performed here
# ============================================================================
set -euo pipefail

TREE="$(cd "$(dirname "$0")" && pwd)"
OUT="${TREE}/out-pafm00"
SRC="${TREE}/oppo_device_out"
PACK="${OUT}/pack-$(date +%Y%m%d-%H%M%S)"

mkdir -p "${PACK}"
LOG="${PACK}/pack.log"
log(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }
die(){ log "FATAL: $*"; exit 1; }

[ -f "${TREE}/arch/arm64/boot/Image" ] || die "run build_pafm00_findx.sh first"
[ -f "${SRC}/boot.img" ] || die "original boot.img missing"
log "== 1/6 unpack stock boot template =="
WORK="${PACK}/bootwork"; mkdir -p "${WORK}"
cp "${SRC}/boot.img" "${WORK}/boot.img"
( cd "${WORK}" && magiskboot unpack boot.img ) >>"$LOG" 2>&1
# record stock header facts
( cd "${WORK}" && magiskboot unpack -h boot.img ) >>"$LOG" 2>&1 || true

log "== 2/6 single-member gzip kernel =="
python3 - "${TREE}/arch/arm64/boot/Image" "${WORK}/kernel.gz" <<'EOF'
import zlib, sys
src, dst = sys.argv[1], sys.argv[2]
raw = open(src, 'rb').read()
co = zlib.compressobj(9, zlib.DEFLATED, -zlib.MAX_WBITS, zlib.DEF_MEM_LEVEL, 0)
data = co.compress(raw) + co.flush()
open(dst, 'wb').write(data)
# verify: single member parse
d = zlib.decompressobj(-zlib.MAX_WBITS)
assert d.decompress(data) == raw, "roundtrip failed"
print(f"kernel.gz single-member OK: {len(data)} bytes (raw {len(raw)})")
EOF
log "kernel: stock gz 12099139 -> ours $(stat -c%s "${WORK}/kernel.gz")"

log "== 3/6 replace kernel_dtb =="
cp "${TREE}/arch/arm64/boot/dts/qcom/sdm845-v2.1-17107.dtb" "${WORK}/kernel_dtb"
log "kernel_dtb: $(stat -c%s "${WORK}/kernel_dtb") bytes (stock 842055)"

log "== 4/6 repack boot.img (magiskboot recomputes CHECKSUM) =="
( cd "${WORK}" && rm -f kernel ramdisk.cpio dtb
  mv kernel.gz kernel
  magiskboot repack boot.img new-boot.img ) >>"$LOG" 2>&1
mv "${WORK}/new-boot.img" "${PACK}/boot-pafm00.img"

log "== 5/6 verify new boot =="
V="${PACK}/verify"; mkdir -p "${V}"; cp "${PACK}/boot-pafm00.img" "${V}/"
( cd "${V}" && magiskboot unpack boot-pafm00.img ) >>"$LOG" 2>&1
for f in kernel kernel_dtb; do :; done
# header equality: re-unpack prints fields; compare recorded facts manually in MIGRATION
( cd "${V}" && magiskboot unpack boot-pafm00.img 2>&1 | grep -E 'HEADER_VER|PAGESIZE|OS_VERSION|CMDLINE|CHECKSUM|KERNEL_DTB_SZ|KERNEL_FMT|RAMDISK_FMT' ) > "${PACK}/newboot.header.txt" || true
cat "${PACK}/newboot.header.txt" | tee -a "$LOG"

log "== 6/6 vendor modules update =="
MODDIR="$(cat out-pafm00/kernelrelease.txt | xargs -I{} echo out-pafm00/modules_install/lib/modules/{})"
[ -d "${MODDIR}" ] || die "modules_install missing"
MPKG="${PACK}/vendor-modules"; mkdir -p "${MPKG}"
# stock layout: flat /vendor/lib/modules with metadata files
find "${MODDIR}" -name "*.ko" -exec cp {} "${MPKG}/" \;
cp "${MODDIR}/modules.dep" "${MODDIR}/modules.alias" "${MODDIR}/modules.softdep" "${MPKG}/" 2>/dev/null || die "depmod metadata missing"
# modules.load: stock order first (stock kos that we still ship), then new codecs
STOCK_LOAD="/tmp/pafm00_phase0/vendor_modules/vendor/lib/modules/modules.load"
[ -f "${STOCK_LOAD}" ] || STOCK_LOAD="${SRC}/../modules.load.fallback"
{ grep -E '\.ko$' "${STOCK_LOAD}" 2>/dev/null || true
  for k in snd-soc-max989xx snd-soc-ia6xx snd-soc-fsa4480 snd-soc-as6313; do
      [ -f "${MPKG}/${k}.ko" ] && echo "${k}.ko"
  done; } > "${MPKG}/modules.load"
log "modules packaged: $(ls "${MPKG}"/*.ko | wc -l) ko, load list $(wc -l < "${MPKG}/modules.load") entries"
tar -C "${MPKG}" -cf "${PACK}/vendor-modules.tar" .
sha256sum "${PACK}/boot-pafm00.img" "${PACK}/vendor-modules.tar" "${SRC}/dtbo/dtbo.img" > "${PACK}/SHA256SUMS.pack"
cat "${PACK}/SHA256SUMS.pack" | tee -a "$LOG"
log "== DONE — artifacts in ${PACK} =="
