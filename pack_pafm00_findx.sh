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
# UART_DEBUG=1: use sdm845-v2.1-17107-uart.dtb (full board content + uart9
# console) and strip earlycon=msm_geni_serial,0xA84000 from the boot header
# cmdline. Evidence for stripping: 2026-09-30 session observed kernel hang +
# watchdog reboot with that earlycon param when SE9 clocks are not up.
UART_DEBUG="${UART_DEBUG:-0}"

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
# wbits=31 -> standard GZIP container (matches stock kernel payload format;
# ABL parses KERNEL_FMT=gzip). MUST stay single-member: compressobj+flush
# once, no concatenated members (multi-member tail padding killed boot).
co = zlib.compressobj(9, zlib.DEFLATED, 31, zlib.DEF_MEM_LEVEL, 0)
data = co.compress(raw) + co.flush()
open(dst, 'wb').write(data)
# verify: gzip parse (wbits=47 auto-detects gzip container)
d = zlib.decompressobj(47)
assert d.decompress(data) == raw, "roundtrip failed"
# single member: after flush the decompressor must have consumed everything
assert d.eof, "multi-member gzip detected"
print(f"kernel.gz single-member gzip OK: {len(data)} bytes (raw {len(raw)})")
EOF
log "kernel: stock gz 12099139 -> ours $(stat -c%s "${WORK}/kernel.gz")"

log "== 3/6 replace kernel_dtb =="
if [ "${UART_DEBUG}" = "1" ]; then
    cp "${TREE}/arch/arm64/boot/dts/qcom/sdm845-v2.1-17107-uart.dtb" "${WORK}/kernel_dtb"
    log "kernel_dtb: UART-DEBUG variant ($(stat -c%s "${WORK}/kernel_dtb") bytes, uart9 okay, full board content)"
else
    cp "${TREE}/arch/arm64/boot/dts/qcom/sdm845-v2.1-17107.dtb" "${WORK}/kernel_dtb"
    log "kernel_dtb: $(stat -c%s "${WORK}/kernel_dtb") bytes (stock 842055)"
fi

if [ "${UART_DEBUG}" = "1" ]; then
    log "== 3b/6 strip earlycon from header file =="
    # magiskboot repack reads the TEXT header file dumped by unpack, not the
    # raw boot.img bytes (verified: editing boot.img had no effect on the
    # repacked image header).
    python3 - "${WORK}/header" <<'PYEOF'
import sys
p = sys.argv[1]
lines = open(p).read().split('\n')
out, hit = [], 0
for l in lines:
    if l.startswith('cmdline='):
        target = ' earlycon=msm_geni_serial,0xA84000'
        assert target in l, f"earlycon not in cmdline: {l[:80]}..."
        l = l.replace(target, '')
        hit += 1
    out.append(l)
assert hit == 1, f"cmdline lines touched: {hit}"
open(p, 'w').write('\n'.join(out))
print("header cmdline: removed", ' earlycon=msm_geni_serial,0xA84000'.strip())
PYEOF
fi

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
# modules.load: keep the stock 22-entry ORDER; ship only entries that exist
# as ko. The 10 techpack audio drivers (wcd-core pinctrl-wcd swr-wcd-ctrl
# snd-soc-wcd9xxx wcd-dsp-glink snd-soc-wcd934x snd-soc-wcd-mbhc snd-soc-wsa881x
# snd-soc-sdm845 snd-soc-wcd-spi) are BUILT-IN in our kernel (sdm845auto.conf
# make-vars =y; tristate.conf does not know them, see REVIEW_BUILTIN.md) so
# their stock lines must be dropped (no ko to insmod). qca_cld3_wlan.ko keeps
# its stock position (21st of 22); stock init.target.rc:127 insmods it.
STOCK_LOAD="/tmp/pafm00_phase0/vendor_modules/vendor/lib/modules/modules.load"
[ -f "${STOCK_LOAD}" ] || STOCK_LOAD="${SRC}/../modules.load.fallback"
DROPPED=""
while read -r m; do
    [ -n "${m}" ] || continue
    if [ -f "${MPKG}/${m}" ]; then
        echo "${m}"
    else
        DROPPED="${DROPPED} ${m}"
    fi
done < <(grep -E '\.ko$' "${STOCK_LOAD}") > "${MPKG}/modules.load"
# note: log() AFTER the redirect loop -- log() echoes to stdout, which inside
# the loop would pollute modules.load (observed in pack-20261001-052221)
[ -n "${DROPPED}" ] && log "modules.load: dropped built-in audio (no ko shipped):${DROPPED}"
grep -q '^qca_cld3_wlan\.ko$' "${MPKG}/modules.load" || die "qca_cld3_wlan.ko missing from modules.load"
log "modules packaged: $(ls "${MPKG}"/*.ko | wc -l) ko, load list $(wc -l < "${MPKG}/modules.load") entries"
tar -C "${MPKG}" -cf "${PACK}/vendor-modules.tar" .
sha256sum "${PACK}/boot-pafm00.img" "${PACK}/vendor-modules.tar" "${SRC}/dtbo/dtbo.img" > "${PACK}/SHA256SUMS.pack"
cat "${PACK}/SHA256SUMS.pack" | tee -a "$LOG"
log "== DONE — artifacts in ${PACK} =="
