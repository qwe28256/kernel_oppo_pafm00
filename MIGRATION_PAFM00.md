# MIGRATION_PAFM00.md — OPPO Find X (PAFM00) 移植总档

日期：2026-10-01 · 执行者：自动化移植会话（全程证据化）

## 1. 目标设备与基准

| 项 | 值 | 证据 |
|---|---|---|
| 设备 | OPPO Find X PAFM00（prjversion 17107） | adb getprop / 运行态 |
| ColorOS | 11 (RKQ1.210510.002) / PAFM00_11.H.15_4150_202112132055 | ro.build.version.ota |
| 官方内核 | 4.9.227-perf+（verbatim: `4.9.227-perf+ SMP preempt mod_unload modversions aarch64`） | modinfo 实测 ko |
| 本 tree | lineage-22.2，内核 4.9.337 | Makefile |
| 移植基准 commit | 本 tree HEAD（见 §7 提交链） | git log |
| 官方源 | ~/oppo_oss @ oppo/sdm845_r_11.0_find_x @ d3aa37fcc18c；~/oppo_oss_module | git |
| 设备提取物 | oppo_device_out/（boot.img f299b804、dtbo 147a8e93、device.dtb=运行态 FDT 6bb1809f 等） | FACTS.md §1 |

## 2. 工具链与构建

```
~/toolchains/clang（Snapdragon LLVM 10.0.7 for Android NDK）
~/toolchains/GCC-4.9.X-AARCH64（CROSS_COMPILE=aarch64-linux-android-）
~/toolchains/GCC-4.9.X-ARM（CROSS_COMPILE_ARM32=arm-linux-androideabi-）
```
构建（in-tree，勿用 O= —— 本树 asm-generic 子 make 在 O= 下不产出，见 TRAP-05 补注）：
```
./build_pafm00_findx.sh          # 日志与产物在 out-pafm00/
./pack_pafm00_findx.sh           # 打包 boot/vendor-modules
```
产物（out-pafm00/pack-20261001-043858）：
| 文件 | sha256 |
|---|---|
| boot-pafm00.img | da5bbb8bee4c7952ed828911a722a43c36444db921db1141094cb8adaf72d900 |
| vendor-modules.tar | 92560fb4273f7afc8978159df269b6639cb6e3d9dfd3bbba3696bc4cbffedc74 |
| dtbo（沿用原机） | 147a8e93079cffebdf490d6b594631bb453cb3df06325ab81b287312be21a31e |
| Image（内含于 boot） | 1a0fec96e5b9...（33257496B） |
| sdm845-v2.1-17107.dtb | 6009a90cd56f...（414647B，含 __symbols__） |

boot 头核验（magiskboot 二次解包）：HEADER_VER=1 / PAGESIZE=4096 / OS 11.0.0 /
OS_PATCH 2021-10 / CMDLINE 与原机逐字一致 / KERNEL_FMT=gzip（单成员，python zlib）/ 
KERNEL_DTB_SZ=414647 / CHECKSUM 由 magiskboot 重算（a0abc1eb...）。

## 3. 驱动移植记录（commit 链见 §7）

| 驱动 | 来源 | commit | 关键点 |
|---|---|---|---|
| 充电框架 drivers/power/oppo（smb2 fork+bq27541+stm8s/pic16f VOOC+短检+ship） | oppo_oss | a8131df4da07 | Q_CHARGER 为真开关；supply/qcom 去掉原生 qpnp-smb2（TRAP-01/02） |
| 弹出摄像头马达+霍尔 drivers/misc/oppo（motor/drv8834/m1120） | oppo_oss | 279e601f7196 | stspin220 按 OPPO 原样不编（TRAP-08） |
| 音频补件 fsa4480/max989xx/as6313/ia6xx(=m) | oppo_oss_module | ec89fd141f7b | max989xx 的 DSM 保护为桩实现（§5 风险 1） |
| 内核核心胶水：msm_geni_serial（iacore pinctrl/uartlog）、i2c-qcom-geni（VOOC 速率切换）、qcom-geni-se.h、printk uartlog、power_supply.h PROP 扩展、-DVENDOR_EDIT/-DOPLUS_ARCH_EXTENDS | oppo_oss | a8131df4da07 + 本 commit | OPPO 内部构建注入宏改由顶层 Makefile 提供 |
| DTS 修复 | 本 tree 既有导入 6e9980f6fec8 的善后 | (phase3) | camera-sensor-mtp/pinctrl/sde-display 恢复；OPPO 节点移入 findx-common；MACH_OPLUS Kconfig；dtc -@ |
| defconfig | findx_official_defconfig + 11 行补充 | 本 commit | 补 MFD_SPMI_PMIC 等（TRAP-03） |

推迟项（有据，见 OPPO_TRAPS.md TRAP-09）：arch/Kconfig 安全块（OPLUS_MOUNT_BLOCK/EXECVE_BLOCK/KEVENT_UPLOAD/SECURE_GUARD/ROOT_CHECK）——依赖树外 vendor secureguard/keventupload 模块，OSS 快照不含实现；3D 人脸（vendor/oplus/secure 独立体系）。

## 4. DTS/DTB 验证（决定性）

- 自编 dtb（-@）+ 官方 dtbo entry0 经 fdtoverlay 应用成功；
- 结果 FDT 与设备运行态 /sys/firmware/fdt（=device.dtb）对比：12/12 关键 compatible 一比一存在（bq27541/stm8s/pic16f/motor-8834/motor-220/m1120/s6sy761/fsa4480/max98927L/as6313/oppo-devinfo/qpnp-smb2）；
- 差异仅为 __symbols__/label 与官方多出的非必需 audio_test_mod 节点。

## 5. 已知风险

1. **DSM 桩**：max989xx 的动态扬声器保护返回 -ENOTSUPP（OSS 缺实现）。扬声器可发声；极端工况保护缺失。
2. **版本代差**：内核 4.9.337 vs 官方 4.9.227（coloros）。全部 ko vermagic=4.9.337-perf+ 与新内核自洽；**必须整包替换内核+vendor 模块**，不得混用官方 ko。
3. **stspin220 未编**（OPPO 原样）：若 17107 实机用 220 驱动，弹出摄像头不动 → 改一行 obj-y 重测。
4. **OPPO 内部构建注入的宏/符号**（VENDOR_EDIT、OPLUS_ARCH_EXTENDS、OPLUS_FEATURE_*、MACH_*）在本树显式提供；后续 OPPO 驱动移植若再遇未定义特性宏，按 TRAP-04 模式注入。
5. kevent/secureguard 缺席：ColorOS 遥测/部分安全接口缺失，不影响硬件功能。
6. modules.load 由原机 22 ko 顺序 + 4 个新 codec 拼接；本树音频其余组件为 =y 内建，与官方 =m 布局不同（功能等价，加载清单已相应缩减）。

## 6. 回滚步骤

1. 恢复内核/ramdisk/dtbo：`fastboot flash boot <官方 boot 备份>`（官方 boot.img sha256 f299b804...，位于 oppo_device_out/boot.img）；dtbo 未改动，无需恢复。
2. 恢复模块：解包 vendor-modules.tar 前的官方副本在 `/cache/modules_backup_20261001-021905/modules/`（26 文件，15204KB，/cache 未做任何清除）。
3. 源码回滚：按 §7 commit 链 `git revert` 对应提交（每阶段独立提交，回滚面清晰）。

## 7. 提交链（阶段 commit）

```
7a8ae258c063 phase0: FACTS.md + official defconfig
b89e0b6aed8f phase1: DRIVER_MAP.md
a8131df4da07 phase2a: OPLUS SDM845_Q charger framework
279e601f7196 phase2b: pop-up camera motor + digital hall
480312d5da1d phase2e: OPPO_TRAPS.md
ec89fd141f7b phase2d: Find X codec extensions (fsa4480/max989xx/as6313/ia6xx)
(phase3)     arm64: dts: fix Find X import collateral damage + enable dtb build
(phase4)     build: findx_pafm00_defconfig + build script + OPPO kernel-core glue
(phase5)     pack: flat vendor module copy for stock layout
```

## 8. 备份与安全（阶段 6）

- /cache/modules_backup_20261001-021905/modules/：26 项，15204KB；逐文件 sha256 与宿主机副本（/tmp/pafm00_phase0/vendor_modules）一致；/cache 无任何清除操作。
- 本迁移不执行任何刷机；镜像仅生成于 out-pafm00/pack-*。
