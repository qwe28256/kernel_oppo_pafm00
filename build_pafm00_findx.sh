#!/usr/bin/env bash
# ============================================================================
# build_pafm00_findx.sh — OPPO Find X (PAFM00) kernel build for lineage-22.2
# tree: /home/mcstark/android_kernel_oppo_sdm845
#
# Builds IN-TREE: the asm-generic wrapper sub-make (top Makefile asm-generic
# target) produces nothing under O= in this tree, so out-of-tree builds fail
# at prepare0 (kernel/bounds.s: asm/types.h not found). In-tree build verified
# working (chargers/motor/dtbs all compiled this way during porting).
#
# Evidence chain: FACTS.md / DRIVER_MAP.md / OPPO_TRAPS.md
# Reproducible: set -euo pipefail, logs, sha256 manifest.
# ============================================================================
set -euo pipefail

TREE="$(cd "$(dirname "$0")" && pwd)"
OUT="${TREE}/out-pafm00"          # logs + module install only
LOG="${OUT}/build-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "${OUT}"

export PATH="$HOME/toolchains/clang/bin:$HOME/toolchains/GCC-4.9.X-AARCH64/bin:$HOME/toolchains/GCC-4.9.X-ARM/bin:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-android-
export CROSS_COMPILE_ARM32=arm-linux-androideabi-
export CLANG_TRIPLE=aarch64-linux-gnu-
KCFLAGS="-w"

log(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }
die(){ log "FATAL: $*"; exit 1; }

command -v clang >/dev/null || die "clang not in PATH"
[ -f "${TREE}/arch/arm64/configs/findx_pafm00_defconfig" ] || die "defconfig missing"
log "clang: $(clang --version | head -1)"

cd "${TREE}"
log "== 1/5 defconfig =="
make CC=clang KCFLAGS="${KCFLAGS}" findx_pafm00_defconfig >>"$LOG" 2>&1

for sym in OPLUS_SDM845_Q_CHARGER OPPO_MOTOR MACH_OPLUS_FINDX QPNP_SMB2 \
           TOUCHSCREEN_OPLUS MFD_SPMI_PMIC; do
    grep -q "^CONFIG_${sym}=y" .config || die "CONFIG_${sym} missing in .config"
done
grep -q "^CONFIG_QCA_CLD_WLAN=m" .config || die "CONFIG_QCA_CLD_WLAN=m missing (stock init.target.rc:127 insmods qca_cld3_wlan.ko)"
log "config sanity: OK"

log "== 2/5 Image =="
make CC=clang KCFLAGS="${KCFLAGS}" -j"$(nproc)" Image >>"$LOG" 2>&1
[ -f arch/arm64/boot/Image ] || die "Image missing"
log "Image: $(stat -c%s arch/arm64/boot/Image) bytes"

log "== 3/5 dtbs =="
make CC=clang KCFLAGS="${KCFLAGS}" -j"$(nproc)" dtbs >>"$LOG" 2>&1
[ -f arch/arm64/boot/dts/qcom/sdm845-v2.1-17107.dtb ] || die "17107 dtb missing"
log "dtbs: OK (17107/17127, with __symbols__)"

log "== 4/5 modules =="
make CC=clang KCFLAGS="${KCFLAGS}" -j"$(nproc)" modules >>"$LOG" 2>&1
KERREL="$(make CC=clang kernelrelease 2>/dev/null | tail -1)"
log "kernelrelease: ${KERREL}"
make ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" \
     INSTALL_MOD_PATH="${OUT}/modules_install" INSTALL_MOD_STRIP=1 \
     modules_install >>"$LOG" 2>&1
log "modules_install: $(find "${OUT}/modules_install" -name '*.ko' | wc -l) ko"

# Rename wlan.ko -> qca_cld3_wlan.ko BEFORE depmod so modules.dep references
# the shipped filename. Evidence: stock qca_cld3_wlan.ko has
# __this_module.name = "wlan" (this_module section @0x4cd200), i.e. the
# in-tree MODNAME := wlan product is identical; only the FILE must be named
# qca_cld3_wlan.ko because init.target.rc:127 insmods that exact path.
QCACLD_DIR="${OUT}/modules_install/lib/modules/$(make CC=clang kernelrelease 2>/dev/null | tail -1)/kernel/drivers/staging/qcacld-3.0"
if [ -f "${QCACLD_DIR}/wlan.ko" ]; then
    mv "${QCACLD_DIR}/wlan.ko" "${QCACLD_DIR}/qca_cld3_wlan.ko"
    log "renamed wlan.ko -> qca_cld3_wlan.ko (stock __this_module.name=wlan; init.target.rc:127)"
fi
[ -f "${QCACLD_DIR}/qca_cld3_wlan.ko" ] || die "qca_cld3_wlan.ko not produced"

log "== 5/5 depmod + manifest =="
MODDIR="${OUT}/modules_install/lib/modules/${KERREL}"
depmod -b "${OUT}/modules_install" "${KERREL}" >>"$LOG" 2>&1
for f in modules.dep modules.alias modules.softdep; do
    [ -f "${MODDIR}/${f}" ] || die "depmod output ${f} missing"
    log "depmod: ${f} ok"
done
echo "${KERREL}" > "${OUT}/kernelrelease.txt"

sha256sum arch/arm64/boot/Image \
          arch/arm64/boot/dts/qcom/sdm845-v2.1-17107.dtb \
          arch/arm64/boot/dts/qcom/sdm845-v2.1-17127.dtb \
          > "${OUT}/SHA256SUMS.build"
cat "${OUT}/SHA256SUMS.build" | tee -a "$LOG"
log "== DONE — log: ${LOG} =="
