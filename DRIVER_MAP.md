# DRIVER_MAP.md — PAFM00/Find X 驱动与功能映射（阶段 1）

来源与证据：
- 当前 tree HEAD：7a8ae258c063（lineage-22.2）
- OPPO 官方内核：~/oppo_oss，分支 `oppo/sdm845_r_11.0_find_x`，HEAD `d3aa37fcc18c "Synchronize code for OPPO PAFM00_11_H.15 Based on QCOM release TAG: AU_LINUX_ANDROID_LA.UM.9.3.R1.11.00.00.807.021_r1.0.r1_00040.1"`
- OPPO vendor 模块源：~/oppo_oss_module/source/android/vendor/oplus/kernel/** 与 ~/oppo_oss_module/source/android/kernel/msm-4.9/techpack/**
- defconfig：findx_official_defconfig（4622 行，4.9.227 基线）
- 运行态模块清单：FACTS.md 第 8 节

## 1. OPPO 构建体系结论

OPPO 将驱动分两处：
1. **in-tree**（oppo_oss 内核本体）：arch/Kconfig 的 OPLUS 块、drivers/power/oppo（充电框架）、drivers/misc/oppo（弹出式摄像头马达/霍尔）、drivers/soc/oppo、drivers/block/zram OPPO_ZRAM_OPT、drivers/scsi/ufs PADL、drivers/android OPPO_HANS。
2. **vendor 源**（oppo_oss_module）：vendor/oplus/kernel/{charger,system,secureguard,oplus_performance,touchpanel,vibrator,thermal,colorctrl,device_info}、kernel/msm-4.9/techpack/audio（as6313/fsa4480/max989xx/audience-ia6xx）。
   OPPO 构建系统把它们合入同一内核构建（Kconfig/Makefile 拼接）。移植时需手工合并到当前 tree 对应目录。

## 2. CONFIG 符号映射（findx_official_defconfig 48 个 OPLUS/OPPO/TOUCHPANEL 符号）

状态：TREE=当前 tree 已有；OSS=oppo_oss 有需移植；VENDOR=oppo_oss_module 有需移植；DEAD=两处源码均无 Kconfig 定义（C 级 #ifdef 特性或 OSS 精简）。

### 2.1 TREE（当前 tree 已有，7 个）
| 符号 | 定义位置 |
|---|---|
| OPLUS_FEATURE_PROJECTINFO | drivers/soc/oplus/Kconfig |
| OPLUS_FEATURE_RECORD_MDMRST | drivers/soc/oplus/Kconfig |
| OPPO_COMMON_SOFT | drivers/soc/oplus/Kconfig |
| TOUCHPANEL_SAMSUNG | drivers/input/touchscreen/oplus_touchscreen/Kconfig |
| TOUCHPANEL_SAMSUNG_S6SY761 | drivers/input/touchscreen/oplus_touchscreen/Samsung/S6SY761/Kconfig |
| （框架）TOUCHSCREEN_OPLUS | 同目录 Kconfig（注意：defconfig 写的是 TOUCHPANEL_OPPO，两套命名不一致，见 2.4 DEAD 注） |

### 2.2 OSS（oppo_oss in-tree，需移植，19 个）
| 符号 | oppo_oss 定义位置 | 对应源码 |
|---|---|---|
| OPLUS_EXECVE_BLOCK | arch/Kconfig | kernel/（oppo 补丁块） |
| OPLUS_KEVENT_UPLOAD | arch/Kconfig:831 | drivers/oplus_kevent 或 arch 内实现 |
| OPLUS_MOUNT_BLOCK | arch/Kconfig | fs/（挂载管控） |
| OPLUS_ROOT_CHECK | arch/Kconfig | security/（root 检测） |
| OPLUS_SECURE_GUARD | arch/Kconfig | security/ |
| OPLUS_CHECK_CHARGERID_VOLT | drivers/power/Kconfig | drivers/power/oppo/ |
| OPLUS_SDM845_Q_CHARGER | drivers/power/Kconfig | drivers/power/oppo/（Q 平台充电框架主开关） |
| OPLUS_SHIP_MODE_SUPPORT | drivers/power/Kconfig | drivers/power/oppo/ |
| OPLUS_SHORT_C_BATT_CHECK | drivers/power/oppo/Kconfig | 同上（电池短路检测） |
| OPLUS_SHORT_HW_CHECK | drivers/power/oppo/Kconfig | 同上 |
| OPLUS_SHORT_USERSPACE | drivers/power/oppo/Kconfig | 同上 |
| OPPO_MOTOR | drivers/misc/oppo/Kconfig | drivers/misc/oppo/oppo_motor.c + camera_motor_ic/{oppo_drv8834.c,oppo_stspin220.c} + digital_hall_ic/oppo_m1120.c |
| OPPO_ARCH_FILE | drivers/soc/oppo/Kconfig | drivers/soc/oppo/ |
| OPPO_DEVICE_IFNO | drivers/soc/oppo/Kconfig | drivers/soc/oppo/（device_info） |
| OPPO_SVELTE | drivers/soc/oppo/oppo_svelte/Kconfig | 同目录 |
| OPPO_HANS | drivers/android/Kconfig | drivers/android/（binder 相关优化） |
| OPPO_ZRAM_OPT | drivers/block/zram/Kconfig | drivers/block/zram/ |
| OPLUS_FEATURE_PADL_STATISTICS | drivers/scsi/ufs/Kconfig | drivers/scsi/ufs/ |
| OPLUS_SYSTEM_KERNEL_QCOM | 顶层 Kconfig | 顶层（平台选择） |

### 2.3 VENDOR（oppo_oss_module，需移植，16 个）
| 符号 | oppo_oss_module 定义位置 | 说明 |
|---|---|---|
| OPLUS_FEATURE_ACM / ACM_LOGGING | vendor/oplus/kernel/system/acm/ | ANR/卡死监控（acm.c） |
| OPLUS_FEATURE_DEATH_HEALER | vendor/oplus/kernel/system/misc/ | 死锁恢复 |
| OPLUS_FEATURE_DUMP_DEVICE_INFO | vendor/oplus/kernel/system/dump_device_info/ | |
| OPLUS_FEATURE_FUSE_FS_SHORTCIRCUIT | vendor/oplus/kernel/of2fs/ | |
| OPLUS_FEATURE_HUNG_TASK_ENHANCE | vendor/oplus/kernel/system/hung_task_enhance/ | |
| OPLUS_FEATURE_OPROJECT | vendor/oplus/kernel/system/oplus_project/ | |
| OPLUS_FEATURE_PHOENIX | vendor/oplus/kernel/system/oppo_phoenix/ | |
| OPLUS_FEATURE_PMIC_MONITOR | vendor/oplus/kernel/system/oppo_pmic_monitor/ | |
| OPLUS_FEATURE_QCOM_MINIDUMP_ENHANCE | vendor/oplus/kernel/system/qcom_minidump/ | |
| OPLUS_FEATURE_QCOM_PMICWD | vendor/oplus/kernel/system/qcom_pmicwd/ | |
| OPLUS_FEATURE_SELINUX_CONTROL_LOG | vendor/oplus/kernel/system/selinux/ | |
| OPLUS_FEATURE_SHUTDOWN_DETECT | vendor/oplus/kernel/system/shutdown_detect/ | |
| OPLUS_FEATURE_THEIA | vendor/oplus/kernel/system/theia/ | |
| OPLUS_FEATURE_UBOOT_LOG | vendor/oplus/kernel/system/uboot_log/ | |
| OPLUS_HEALTHINFO | vendor/oplus/kernel/oplus_performance/healthinfo/ | |
| OPLUS_MEM_MONITOR | vendor/oplus/kernel/oplus_performance/（memleak_detect/iomonitor 等） | |
| OPLUS_WAKELOCK_PROFILER | vendor/oplus/kernel/oppo_wakelock_profiler/ | |
| OPPO_FG_IO_OPT | vendor/oplus/kernel/oplus_performance/foreground_io_opt/ | |

（充电 IC 实现在 vendor/oplus/kernel/charger/{gauge_ic,vooc_ic,charger_ic,adapter_ic,wireless_ic}，与 OSS drivers/power/oppo 框架为同一框架的两份快照——移植时以 OSS in-tree 版本为主干，差异用 vendor 版校验。）

### 2.4 DEAD（两处源码均无定义，10 个）
OPLUS_FEATURE_ACM_LOGGING(部分在 acm 内联)、OPLUS_POWER_QCOM、OPLUS_SYSTEM_KERNEL、OPPO_3D_FACE、OPPO_3D_FACE_QCOM、TOUCHPANEL_OPPO、OPLUS_FEATURE_PADL_STATISTICS(部分内联)、OPPO_3D_FACE_QCOM 相关实现在 vendor/oplus/secure/biometrics/facerecognition/bsp/drivers（有独立 Kconfig，符号名不同）。
- **OPPO_3D_FACE 特例**：defconfig 有 OPPO_3D_FACE=y 但内核无此 Kconfig；实体在 `oppo_oss_module/source/android/vendor/oplus/secure/biometrics/facerecognition/bsp/drivers/`（mx6300_tac、oppo_face_ldmp、oppo_face_irflash、oppo_face_common），独立构建体系。**Find X 结构光 3D 人脸需单独评估**，不在常规内核树移植范围，阶段 2 只保留接口占位。
- **TOUCHPANEL_OPPO 特例**：defconfig 用 TOUCHPANEL_OPPO，当前 tree 框架符号为 TOUCHSCREEN_OPLUS。生成目标 defconfig 时需改名映射，否则符号被 Kconfig 静默丢弃。

## 3. DTS compatible → 驱动映射（Find X 专属节点）

DTS 事实源：arch/arm64/boot/dts/qcom/{sdm845-v2.1-17107.dts, sdm845-v2.1-17127.dts, sdm845-v2.1-findx-common.dtsi, sdm845-v2.1-mtp-overlay-17107.dts, dsi-panel-dsi_oppo17107_samsung_sofeg02_fhd_dsc_cmd.dtsi}（均由 commit 6e9980f6fec8 导入）。

| compatible | 功能 | 驱动源 | 当前 tree 状态 | 移植动作 |
|---|---|---|---|---|
| oppo-motor | 弹出摄像头马达总线 | oss drivers/misc/oppo/oppo_motor.c | 缺失 | 整目录移植 + Kconfig/Makefile + drivers/misc/Kconfig 挂载 |
| motor_drv-8834 | DRV8834 马达 IC | oss camera_motor_ic/oppo_drv8834.c | 缺失 | 同上 |
| motor_drv-220 | STSPIN220 马达 IC | oss camera_motor_ic/oppo_stspin220.c | 缺失 | 同上 |
| oppo,dhall-m1120 | 数字霍尔（滑轨检测） | oss digital_hall_ic/oppo_m1120.c | 缺失 | 同上 |
| oplus,bq27541-battery | 电量计 | oss drivers/power/oppo/gauge_ic/oplus_bq27541.c（vendor 版同） | 缺失 | 随充电框架移植（注意 V200/G1 固件差异，已在 U-Boot 阶段验证） |
| oplus,stm8s-fastcg | VOOC 快充 MCU | oss vooc_ic/oplus_stm8s.c | 缺失 | 同上 |
| oplus,pic16f-fastcg | VOOC 快充 MCU（备料） | oss vooc_ic/oplus_pic16f.c | 缺失 | 同上 |
| sec-s6sy761 | 三星触控 IC | tree oplus_touchscreen/Samsung/S6SY761/ | **已有** | 验证 DTS 绑定字段 |
| fsa,fsa4480 | 音频/USB-C 模拟开关 | oss_module techpack audio codecs/fsa4480 | 缺失 | techpack/audio 移植 |
| maxim,max98927L | 智能功放 | oss_module techpack audio codecs/max989xx | 缺失 | 同上 |
| oppo,as6313 | 红外接近/泛光（3D face 相关） | oss_module techpack audio codecs/as6313 | 缺失 | 同上（ALSA SoC 驱动） |
| （audience）ia6xx | 智能功放/传感器 hub | oss_module techpack audio codecs/audience | 缺失 | 同上 |
| qcom,cam-sensor / eeprom / actuator / ois / camera-flash / cam-res-mgr | 摄像头链 | oss drivers/media 或 vendor camera | 待查（阶段 2/3） | 以 device.dtb 节点为准补齐 |
| regulator-fixed ×8 | 固定稳压 | 内核自带 | 已有 | 核对 enable GPIO 与 device.dtb 一致 |
| proximity_power | 距离传感器供电 | 待查 | 待查 | |
| qcom,dsi-display | DSI 面板框架 | tree drivers/video/fbdev/msm（mdss） | 已有（CAF） | 面板 dtsi 已导入，验证时序 |

## 4. vendor ko → 构建来源映射（原机 /vendor/lib/modules 22 ko）

| ko | 当前 tree 构建目标 | 状态 |
|---|---|---|
| snd-soc-sdm845.ko | techpack/audio/asoc/sdm845.c | 待验证（lineage 树 techpack 已有 asoc） |
| wcd-core.ko | techpack audio codecs wcd9xxx-core 等 | 已有源码 |
| snd-soc-wcd9xxx.ko / wcd934x / wcd-mbhc / wcd-spi | techpack/audio/asoc/codecs/wcd934x | 已有源码 |
| snd-soc-wsa881x.ko | codecs/wsa881x | 已有源码 |
| snd-soc-fsa4480.ko | oss_module codecs/fsa4480 | 缺失，需移植 |
| snd-soc-max989xx.ko | oss_module codecs/max989xx | 缺失，需移植 |
| snd-soc-as6313.ko | oss_module codecs/as6313 | 缺失，需移植 |
| snd-soc-ia6xx.ko | oss_module codecs/audience | 缺失，需移植 |
| swr-wcd-ctrl.ko | techpack audio asoc soundwire | 已有源码（待验证） |
| pinctrl-wcd.ko | techpack audio asoc/pinctrl | 已有源码（待验证） |
| qca_cld3_wlan.ko | drivers/staging/qcacld-3.0 | 待验证（CAF wlan） |
| wil6210.ko | drivers/net/wireless/ath/wil6210 | CAF 上游 |
| msm_11ad_proxy.ko | drivers/net/wireless/msm11ad | CAF 上游 |
| rdbg.ko / llcc_perfmon.ko / tspp.ko / mpq-adapter.ko / mpq-dmx-hw-plugin.ko | CAF misc/dvb | 待验证 |
| wcd-dsp-glink.ko | techpack audio dsp | 待验证 |

模块元数据（modules.alias/dep/load/softdep）已备份：/cache/modules_backup_20261001-021905/。

## 5. 移植优先级（影响硬件功能 → 遥测）

1. **充电框架** drivers/power/oppo（bq27541 + stm8s/pic16f VOOC + 短路检测）——不移植则 ColorOS 无法正确显示电量/充电（健康度、VOOC 均依赖 sysfs 节点）。
2. **马达** drivers/misc/oppo（motor + drv8834 + stspin220 + m1120 霍尔）——不移植弹出摄像头完全不可用。
3. **触控** 已有 S6SY761，验证即可。
4. **音频补件** fsa4480/max989xx/as6313/ia6xx → techpack/audio（耳机检测、扬声器和 3D face 前端）。
5. **arch/Kconfig OPLUS 块 + kevent**（多个 oplus 驱动的错误上报依赖 oplus_kevent API）。
6. **soc/oppo（arch_file/device_info/svelte）、project info**——ColorOS 用户态读 sysfs。
7. **其余 telemetry（theia/phoenix/acm/…）**——可后置，不阻塞硬件。
8. **3D face**——独立体系，占位待评。

## 6. 已识别的陷阱候选（阶段 2 展开 OPPO_TRAPS.md）

- defconfig `# CONFIG_OPLUS_CHARGER is not set` 与 `CONFIG_OPLUS_SDM845_Q_CHARGER=y` 并存：Q 平台用新框架，旧 OPLUS_CHARGER 全关。若误开旧框架会双注册。
- TOUCHPANEL_OPPO(defconfig) vs TOUCHSCREEN_OPLUS(tree)：符号名漂移。
- defconfig 中 10 个 DEAD 符号：make defconfig 会静默丢弃，验证时不得视为回归。
- device.dtb（运行态 FDT）与 kernel_dtb 的 board-id 差异（0x08 vs 0x00）：ABL/dtbo 注入结果，源码移植时不要把 board-id=0x08 写死进 kernel dts。

## 7. 关键 commit 索引

| 内容 | 位置 |
|---|---|
| Find X DTS 导入 | 当前 tree 6e9980f6fec8（2026-08-30, WenHao2130） |
| 官方内核同步点 | oppo_oss d3aa37fcc18c（PAFM00_11_H.15, QCOM AU_LINUX_ANDROID_LA.UM.9.3.R1.11.00.00.807.021） |
| 当前 tree oplus 现状 | drivers/soc/oplus/{oppo_devinfo,oppo_mdmrst,oppo_project,project_info}、drivers/platform/oplus/Kconfig、oplus_touchscreen |
