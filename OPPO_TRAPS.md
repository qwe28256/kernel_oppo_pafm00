# OPPO_TRAPS.md — OPPO 移植陷阱记录（阶段 2）

每条：位置 / 证据 / 影响 / 修复 / 验证 / 回滚。禁止无证据删代码——本文档所有"修复"均给出 commit。

## TRAP-01 OPLUS_CHARGER 是残影符号，Q_CHARGER 才是真开关
- 位置：oppo_oss drivers/power/{Kconfig:18,Makefile:8,oppo/Kconfig,oppo/Makefile}
- 证据：`obj-$(CONFIG_OPLUS_SDM845_Q_CHARGER) += oppo/`；oppo/Makefile 内全部 obj-y；findx_official_defconfig 同时含 `# CONFIG_OPLUS_CHARGER is not set` 与 `CONFIG_OPLUS_SDM845_Q_CHARGER=y`。
- 影响：若按 OPLUS_CHARGER 符号理解开关，会误判充电框架未启用；若误开 OPLUS_CHARGER 旧框架会与 Q 框架双注册。
- 修复：commit（phase2a）——drivers/power/Makefile 用 `obj-$(CONFIG_OPLUS_SDM845_Q_CHARGER) += oppo/`；未定义 OPLUS_CHARGER。
- 验证：out 编译 23 个 .o；.config 中 OPLUS_SDM845_Q_CHARGER=y 且 OPLUS_CHARGER 不存在。
- 回滚：git revert phase2a commit。

## TRAP-02 原生 qpnp-smb2 被注释，OPPO fork 才是真驱动
- 位置：oppo_oss drivers/power/supply/qcom/Makefile:9,11
- 证据：line 9 `obj-$(CONFIG_QPNP_SMB2) += step-chg-jeita.o battery.o pmic-voter.o storm-watch.o`；line 11 `#obj-$(CONFIG_QPNP_SMB2) += ... qpnp-smb2.o smb-lib.o ...`（被注释）；oplus_battery_sdm845_Q.c 注册相同 compatible "qcom,qpnp-smb2"（.c:11592）与同名驱动。
- 影响：若两个都编，同名驱动/同 compatible 冲突，设备绑定不确定。
- 修复：commit phase2a——当前 tree supply/qcom/Makefile 移除 qpnp-smb2.o smb-lib.o（镜像 OPPO line 9）。
- 验证：make drivers/power/supply/qcom/ 通过，8 个 .o，无 qpnp-smb2.o。
- 回滚：git revert phase2a。

## TRAP-03 OSS defconfig 不完整：MFD_SPMI_PMIC 缺失
- 位置：findx_official_defconfig（无 CONFIG_MFD_SPMI_PMIC 行）
- 证据：`grep MFD_SPMI_PMIC findx_official_defconfig` 为空；drivers/power/Kconfig `OPLUS_SDM845_Q_CHARGER depends on MFD_SPMI_PMIC`。运行态 PMIC 驱动必然在（充电工作）。
- 影响：olddefconfig 会把 OPLUS_SDM845_Q_CHARGER 连带丢弃。
- 修复：生成目标 defconfig 时显式补 CONFIG_MFD_SPMI_PMIC=y（阶段 4 build 脚本）。
- 验证：.config grep =y（2026-10-01 实测）。
- 回滚：无破坏性。

## TRAP-04 OPLUS_FEATURE_* 宏由内部构建系统注入，OSS 树内无定义
- 位置：全树 #ifdef OPLUS_FEATURE_*；oplus_battery_sdm845_Q.c 内 205 处 OPLUS_FEATURE_CHG_BASIC
- 证据：oppo_oss 内 grep `define OPLUS_FEATURE_CHG_BASIC` 为空；Makefile/Kconfig/defconfig 均无。运行态证据：设备 /sys/class/power_supply/{battery,main,pc_port,ac,usb} 存在且 battery/charge_full=3730000（2026-10-01 adb 实测）→ 生产内核该特性开启。
- 影响：不定义则 OPPO 代码块整体编译剔除（include 链在 #ifdef 内断裂，出现"头文件部分可见"的诡异编译错误）。
- 修复：commit phase2a——drivers/power/oppo/{Makefile 及 4 个子目录 Makefile} `ccflags-y += -DOPLUS_FEATURE_CHG_BASIC`。
- 验证：整目录 0 error。
- 回滚：git revert。

## TRAP-05 4.9 kbuild 的 subdir-ccflags-y 无效
- 位置：scripts/Makefile.lib:10
- 证据：`export KBUILD_SUBDIR_CCFLAGS := ...` 后全树无任何消费者（grep KBUILD_SUBDIR_CCFLAGS 仅 1 处）。
- 影响：依赖它向子目录传 -I/-D 全部失效（含 ccflags 的 -DOPLUS_FEATURE_*）。
- 修复：各子目录 Makefile 显式 ccflags-y。
- 验证：V=1 检查编译命令包含 -I 与 -D。
- 回滚：无破坏性。

## TRAP-06 VENDOR_EDIT 由顶层 Makefile 无条件注入
- 位置：oppo_oss Makefile:439-443
- 证据：`KBUILD_CFLAGS += -DVENDOR_EDIT` 等四行处于活跃状态（# ifdef 行为 make 注释）。include/linux/power_supply.h 等 OPPO 扩展以 #ifdef VENDOR_EDIT 包裹。
- 影响：不注入则 OPPO 枚举/结构扩展失效（如 POWER_SUPPLY_PROP_*）。
- 修复：commit phase2a——当前 tree 顶层 Makefile 加同样四行；power_supply.h 枚举扩展 verbatim 移植（含 STATUS 无 "=0" 的顺延语义）。
- 验证：充电框架编译通过。
- 回滚：git revert。

## TRAP-07 TOUCHPANEL_OPPO(defconfig) vs TOUCHSCREEN_OPLUS(tree) 符号漂移
- 位置：findx_official_defconfig vs drivers/input/touchscreen/oplus_touchscreen/Kconfig
- 证据：defconfig 有 TOUCHPANEL_OPPO=y；两源树均无该 Kconfig 定义；当前 tree 框架符号为 TOUCHSCREEN_OPLUS。
- 影响：保留 defconfig 原行则符号被静默丢弃（无害但误导）；框架依赖 SAMSUNG 符号仍生效。
- 修复：阶段 4 生成 defconfig 时以 TOUCHSCREEN_OPLUS=y 替代（实测 olddefconfig 后 TOUCHSCREEN_OPLUS=y 已生效）。
- 验证：.config grep。
- 回滚：无。

## TRAP-08 马达 Makefile：stspin220 被注释，DTS 却有 motor_drv-220 节点
- 位置：oppo_oss drivers/misc/oppo/camera_motor_ic/Makefile；sdm845-v2.1-findx-common.dtsi:1044
- 证据：`#obj-y += oppo_stspin220.o`；DTS motor_drv1 compatible="motor_drv-220" 无 status 属性（默认 okay）。
- 影响：motor_drv1 节点无驱动绑定（无害空节点）；若 17107 实际用 220 驱动则弹出摄像头失效——待运行时验证。
- 修复：按 OPPO 原样（不编 stspin220）。运行时若 motor 不动，改 obj-y 重测。
- 验证：待运行时（弹出摄像头功能）。
- 回滚：加一行 obj-y 即可。

## TRAP-09 核心文件安全钩子依赖树外 vendor 模块（推迟决策）
- 位置：oppo_oss arch/Kconfig:825-833；fs/exec.c:1676,1735；fs/namespace.c:29,2793,2819
- 证据：OPLUS_MOUNT_BLOCK/EXECVE_BLOCK/KEVENT_UPLOAD/SECURE_GUARD 全部 `def_bool y`；钩子调用 oplus_mount_block()/oplus_exec_block() —— 实现在 oppo_oss_module vendor/oplus/kernel/secureguard/ 与 system/（树外）。
- 影响：只移植钩子不移植实现 = 死代码 + 潜在链接错误；不移植 = 无安全管控（root 检测等），硬件功能无影响。
- 修复：**推迟**。阶段 2 只移植硬件必需驱动。KEVENT/SECUREGUARD vendor 模块作为后续项（MIGRATION_PAFM00.md 已记录）。
- 验证：N/A（决策记录）。
- 回滚：N/A。

## TRAP-10 dtbo/kernel_dtb 的 board-id 差异是 ABL 行为，不是源码属性
- 位置：FACTS.md 第 4 节
- 证据：kernel_dtb board-id=<0x00 0x00>；运行态 device.dtb board-id=<0x08 0x00>（ABL+dtbo 注入）。
- 影响：若把 0x08 写死进 kernel dts，会改变 ABL 匹配行为（本机此前 dtbo-neutral+dtbfix 实验已验证此机制）。
- 修复：不动 findx DTS 的 board-id（保持 0x00，由 ABL/dtbo 路径处理）；打包沿用原机 dtbo 模板。
- 验证：阶段 5 打包产物头字段比对。
- 回滚：git checkout DTS 文件。

## TRAP-11 OPPO "ifdef 注释"模板语法（#ifdef OPLUS_ARCH_EXTENDS）
- 位置：oss_module techpack/audio/**（Makefile 与 auto.conf）
- 证据：`#ifdef OPLUS_ARCH_EXTENDS` 出现在 Makefile/auto.conf 中 —— 非 make 语法，系 OPPO 构建系统的模板标记。
- 影响：直接照抄会导致这些行被 make 当注释/错误处理。
- 修复：commit phase2d——按展开后的实际值移植（obj 行直接写，CONFIG=m 直接写）。
- 验证：techpack/audio 编译 21 个新 .o。
- 回滚：git revert。
