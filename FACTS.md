# FACTS.md — OPPO PAFM00 / Find X 移植事实固化（阶段 0）

生成时间：2026-10-01 02:20 (Asia/Shanghai)
设备序列号：a903ae7b（adb connected）
所有命令均在本机实际执行，输出摘要可直接复核。

## 0. 当前 tree

| 项 | 值 | 证据命令 |
|---|---|---|
| 路径 | /home/mcstark/android_kernel_oppo_sdm845 | pwd |
| 分支 | lineage-22.2（与 origin 一致） | git branch --show-current |
| HEAD | 3d5e56abc2c1562a757b49756ceda88506f0dcc1 2026-09-07 "ARM64: configs: oplus: Enable pstore support" | git log -1 |
| remote | origin https://gh-proxy.com/https://github.com/WenHao-Dev/android_kernel_oppo_sdm845 | git remote -v |
| 内核版本 | 4.9.337（Makefile: VERSION=4 PATCHLEVEL=9 SUBLEVEL=337） | head -5 Makefile |
| 工作区 | 干净，未跟踪：AGENTS.md、findx_official_defconfig、oppo_device_out/ | git status |

**关键矛盾（未决）**：设备运行内核 `4.9.227-perf+`（ColorOS 官方），当前 tree 为 `4.9.337`。
原机 ko vermagic = `4.9.227-perf+ SMP preempt mod_unload modversions aarch64`，且 **CONFIG_MODVERSIONS 开启**。
→ 自编译 ko 无法混入原机 vendor（vermagic+modversions CRC 均不匹配）；必须整内核+整模块一起替换，或对齐版本号。见 MIGRATION_PAFM00.md 决策记录。

## 1. oppo_device_out 提取物清单（sha256 + file）

```
f299b804796776c76d4d8933ae657d77cc29b6096802c6c1384811f0533925c1  boot.img                 Android bootimg, 64MB, pagesize 4096
6bb1809f8666197a40c47dd0f0a1f29c4913c6e998f3bc0559a7e95ede897dc2  device_fdt/device.dtb    DTB v17, 546292B
5da887b43babbee9698a9eb422a20518d6cb52700ba15393b9e891560fe7e9ad  device_fdt/device-tree.tar.gz  仅 121B，内容为符号链接快照（proc/device-tree -> /sys/firmware/devicetree/base），非真实 DT 源
ac1253f782c09bc16119e380b0f32a7c72152f61a3924eaf26ef9df040f23bf0  dtbo/dtbo.img            dt_table, 8MB(填充), 实际 396234B
2e9f3a7823558e8e917700d5d79d97dc5ba3d19c2f69861b57145fb3be905f91  kernel                   ARM64 Image 未压缩, 33458200B
266fe65c5e323625bea97c26e814c6f84164bb36395153c67abf254d6872cac4  kernel_dtb               DTB v17, 420780B
8a9a3c777208932574b5df1f18110a9aa1028e93a18b269d1c7c5331eb01ad2e  kernel_dtb.dtsi          560543B
1b65f7bc9b89d8a2d6e4a248d7066e089f94d6a8c686dd274339e3d36c4af773  ramdisk.cpio             SVR4 cpio, 2260224B
```

## 2. boot.img header 事实（magiskboot unpack 输出原文）

```
HEADER_VER      [1]
KERNEL_SZ       [12099139]          <- gzip 压缩后
RAMDISK_SZ      [1003430]           <- gzip 压缩后
SECOND_SZ       [0]
RECOV_DTBO_SZ   [0]
OS_VERSION      [11.0.0]
OS_PATCH_LEVEL  [2021-10]
PAGESIZE        [4096]
NAME            []
CMDLINE         [console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0xA84000 androidboot.hardware=qcom androidboot.console=ttyMSM0 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 ehci-hcd.park=3 lpm_levels.sleep_disabled=1 service_locator.enable=1 swiotlb=2048 androidboot.configfs=true loop.max_part=7 androidboot.usbcontroller=a600000.dwc3 buildvariant=user]
CHECKSUM        [5a8657037ce720ad5d8c7140ccb8c725e288788b000000000000000000000000]
KERNEL_DTB_SZ   [842055]            <- kernel_dtb 追加在 kernel 之后（v1 格式 OPPO 风格）
KERNEL_FMT      [gzip]
RAMDISK_FMT     [gzip]
VBMETA
```

- 解包后未压缩 kernel sha256 = 2e9f3a78... 与 oppo_device_out/kernel 一致（同物）。
- repack 时 magiskboot 会重算 CHECKSUM，必须用原 boot.img 模板打包（铁律 10）。

## 3. dtbo.img 事实（python 解析 dt_table）

```
magic=0xd7b7ab1e total_size=396234 header_size=32 entry_size=32 entry_count=2 entries_offset=32 page_size=4096 version=0
entry[0]: size=199206 offset=0x60    id=0x0 rev=0x0  -> prjversion = <0x01 0x42d3>  (17107 = PAFM00)
entry[1]: size=196932 offset=0x30a86 id=0x0 rev=0x0  -> prjversion = <0x01 0x42e7>  (17127)
两个 entry 均为 /dts-v1/;/plugin/ fragment overlay，root: model="SDM845 v2.1 MTP"
qcom,msm-id = <0x141 0x20001>; qcom,board-id = <0x08 0x00>
fragment@0 target = <&mdss_mdp>（DSI 面板配置）
```

注意：本 dtbo.img 只有 2 个 entry（此前 memory 记载"官方 114 fragment"指的是另一份 OP 桌面提取的 dtbo，两份不是同一文件）。打包新 dtbo 时以本文件为模板。

## 4. FDT 事实

- **device.dtb（546292B）= 设备运行态 /sys/firmware/fdt**：宿主机读取 `/sys/firmware/fdt` sha256 = 6bb1809f8666...897dc2，与 device_fdt/device.dtb 完全一致（命令：adb shell su -c 'cat /sys/firmware/fdt | sha256sum'）。即 device.dtb 是 ABL 应用 overlay 后的最终 FDT。
- device.dtb root: board-id=<0x08 0x00>，prjversion=<0x01 0x42d3>；kernel_dtb root: board-id=<0x00 0x00>，prjversion=<0x01 0x42d3>（board-id 由 ABL/dtbo 阶段补齐）。
- 反编译产物：/tmp/pafm00_phase0/device.dts（26351 行）、/tmp/pafm00_phase0/kernel_dtb.dts（21064 行），仅 unit_address_vs_reg 警告（OPPO 原生如此）。
- 设备运行态 /proc/device-tree/qcom,board-id 原始字节 = `00000008 00000000`（xxd），与 dtbo/dtb 一致。

## 5. ramdisk.cpio 事实

解包（cpio -idm，4415 blocks）顶层内容：
```
debug_ramdisk/  dev/  init(2251352B)  mnt/  oplus.fstab(2651B)  proc/  sys/  fstab.qcom(4965B)
```
- **不含 /lib/modules，不含任何 modules.* 元数据**。原机模块全部位于 vendor 分区 /vendor/lib/modules。
- 新模块只能打进 vendor 包或另寻挂载路径，不能靠改 boot ramdisk 携带。

## 6. findx_official_defconfig 事实

- 头部：Linux/arm64 4.9.227 Kernel Configuration，`CONFIG_OPLUS_SYSTEM_KERNEL_QCOM=y`，`CONFIG_LOCALVERSION="-perf"`，共 4622 行 CONFIG。
- 当前 tree 无 findx/pafm00 专属 defconfig；`arch/arm64/configs/sdm845_defconfig` 与之 diff 5559 行。
- OPLUS/OPPO 特性（节选，证据：grep OPLUS findx_official_defconfig）：
  - y: OPLUS_SYSTEM_KERNEL_QCOM, OPLUS_ROOT_CHECK, OPLUS_MOUNT_BLOCK, OPLUS_EXECVE_BLOCK, OPLUS_KEVENT_UPLOAD, OPLUS_SECURE_GUARD, OPPO_FG_IO_OPT, OPLUS_MEM_MONITOR, OPPO_ZRAM_OPT, **OPPO_MOTOR**, OPLUS_FEATURE_PADL_STATISTICS, **TOUCHPANEL_OPPO**, OPPO_3D_FACE(+QCOM), **OPLUS_SDM845_Q_CHARGER**, OPLUS_SHORT_C_BATT_CHECK, OPLUS_CHECK_CHARGERID_VOLT, OPLUS_SHIP_MODE_SUPPORT, OPLUS_SHORT_HW_CHECK, OPLUS_SHORT_USERSPACE, OPPO_ARCH_FILE, OPPO_COMMON_SOFT
  - not set: OPPO_TP_APK, OPLUS_SDM845_CHARGER, OPLUS_SDM845P_CHARGER, OPLUS_RTC_DET_SUPPORT, OPLUS_CHARGER(!), OPLUS_FEATURE_MODEM_MINIDUMP, HID_ZEROPLUS
  - 注意 `# CONFIG_OPLUS_CHARGER is not set` 与 `CONFIG_OPLUS_SDM845_Q_CHARGER=y` 并存 —— Q 平台走专用充电框架，通用 OPLUS_CHARGER 被关。属 OPPO 配置陷阱候选，阶段 2 记入 OPPO_TRAPS.md。

## 7. 当前 tree oplus 现状

```
drivers/platform/oplus/   drivers/soc/oplus/   include/soc/oplus/
drivers/input/touchscreen/oplus_touchscreen/ (含 Samsung/)
techpack/: audio  Kbuild  stub
```
即 lineage 树已携带部分 OPPO 框架代码，阶段 1 需逐驱动比对缺口。

## 8. 设备运行态（adb 取证）

| 项 | 值 |
|---|---|
| 型号 | PAFM00 |
| Android | 11（RKQ1.210510.002, user/release-keys） |
| ColorOS | PAFM00_11.H.15_4150_202112132055（display: PAFM00_11_H.15） |
| oplus ext 分区 | my_product my_engineering my_stock my_heytap my_region my_carrier my_preload my_company |
| 运行内核 | 4.9.227-perf+ |
| /lib/modules | 不存在（ls: No such file or directory） |
| /vendor/lib/modules | 26 项 = 22 ko + modules.alias/dep/load/softdep（modules.dep 1924B） |
| ko vermagic | 4.9.227-perf+ SMP preempt mod_unload modversions aarch64（intree: Y，实测 snd-soc-sdm845.ko / qca_cld3_wlan.ko） |
| modules.load 头部 | wil6210, msm_11ad_proxy, mpq-adapter, mpq-dmx-hw-plugin, tspp, wcd-core, pinctrl-wcd, swr-wcd-ctrl, snd-soc-wcd9xxx, wcd-dsp-glink ... |
| modules.alias 样例 | alias platform:sdm845-asoc-snd snd_soc_sdm845 |

/vendor/lib/modules 完整 ko 清单（22）：
llcc_perfmon, mpq-adapter, mpq-dmx-hw-plugin, msm_11ad_proxy, pinctrl-wcd, qca_cld3_wlan, rdbg, snd-soc-as6313, snd-soc-fsa4480, snd-soc-ia6xx, snd-soc-max989xx, snd-soc-sdm845, snd-soc-wcd-mbhc, snd-soc-wcd-spi, snd-soc-wcd934x, snd-soc-wcd9xxx, snd-soc-wsa881x, swr-wcd-ctrl, tspp, wcd-core, wcd-dsp-glink, wil6210

## 9. 备份（阶段 6 前置项，已完成）

- 路径：**/cache/modules_backup_20261001-021905/modules/**（26 文件，15204 KB）
- 校验：snd-soc-sdm845.ko sha256 = 21285ff2...、qca_cld3_wlan.ko = a05fcd0f...、modules.dep = 7fcc6913...，与宿主机副本 /tmp/pafm00_phase0/vendor_modules/vendor/lib/modules 逐文件一致。
- /cache 未做任何清除操作。宿主机留证副本聚合 sha256 = fcaf2c591495e9d28c6c9d988fa495eb21983aa6f7093c9007c4160375688b7f。

## 10. 未验证项 / 风险

1. 4.9.337 vs 4.9.227 vermagic/modversions 冲突（见第 0 节）——策略待定。
2. findx_official_defconfig 在 4.9.337 tree 上 make defconfig 未必能完整解析（部分 OPLUS Kconfig 符号可能缺失），需阶段 4 实测 olddefconfig 后 diff。
3. device.dtb 为运行态最终 FDT，包含 ABL 注入的内存/保留内存信息；用它反推源级 dts 时需区分"运行时注入"与"源码定义"。
4. 本 dtbo.img 的 2 个 entry 是否为 ABL 全量可选面板集未验证（此前 memory 中"114 fragment"的官方 dtbo 另有其物，勿混用）。
5. 原机 boot.img 的 AVB/VBMETA 标志：magiskboot 输出含 VBMETA 行但未深入解析 AVB 描述符，刷机侧风险已知（用户此前已成功刷写自制镜像，说明 ABL 未锁 AVB）。
