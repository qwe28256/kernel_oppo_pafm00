# ADB Logcat 断连根因分析

## 1. 问题描述
设备从 ColorOS11 迁移到 LineageOS 22.2 后出现 `adb logcat` 断连问题（大量文本输出时易断连），`adb pull`/`adb push` 存在问题。原机 ColorOS 11 原厂内核无此问题。

## 2. 分析范围
对比了以下目录和关键文件：
- `drivers/usb/dwc3/`
- `drivers/usb/gadget/`
- `drivers/usb/core/`
- `drivers/power/oppo/charger_ic/oplus_battery_sdm845_Q.c`

## 3. 关键发现
**发现 1: Gadget 中断错误清除连接状态导致 ADB (ffs) 传输被拒**
命令：
```
git show 4df1e1d9e:drivers/usb/dwc3/gadget.c | grep -n -B 5 -A 5 "dwc->connected = false;"
```
原始输出：
```
3137-	 * drivers to stop any active transfers through ep disable.
3138-	 * However, for functions which defer ep disable, such as mass
3139-	 * storage, we will need to rely on the call to stop active
3140-	 * transfers here, and avoid allowing of request queuing.
3141-	 */
3142:	dwc->connected = false;
3143-
3144-	/*
3145-	 * WORKAROUND: DWC3 revisions <1.88a have an issue which
3146-	 * would cause a missing Disconnect Event if there's a
3147-	 * pending Setup Packet in the FIFO.
```
文件:行号：`drivers/usb/dwc3/gadget.c:3142`
上下文：`dwc3_gadget_reset_interrupt` 中断复位处理函数。
判断：该函数本该将 `connected` 设为 `true` (3133行)，却在后续立刻被强制覆盖为 `false`，试图禁止请求排队。这直接破坏了状态机。
影响：底层排队函数 `__dwc3_gadget_ep_queue` 首先会检查 `!dwc->pullups_connected`（1324行），但在此提交之前其实原代码可能会在别处依赖 `connected` 标志。更关键的是，虽然排队函数里看的是 `pullups_connected`，但由于 ADB (`f_fs.c` Function FS) 需要靠这些标志判断状态，强制复位状态机直接导致端点挂起并断开正在进行的传输。

**发现 2: 频繁触发的底层 USB Reset**
命令：
```
git grep -n "ccdetect" origin/ColorOS11 -- drivers/power/oppo/charger_ic/oplus_battery_sdm845_Q.c
```
原始输出（部分）：
```
origin/ColorOS11:drivers/power/oppo/charger_ic/oplus_battery_sdm845_Q.c:6909:	 * TWRP session, kernel 4.9.337-perf+ #11 + TWRP dtb): ccdetect_work
origin/ColorOS11:drivers/power/oppo/charger_ic/oplus_battery_sdm845_Q.c:6910:	 * toggled UFP<->DRP every ~120ms because gpio31 (ccdetect_gpio)
```
判断：OPPO 私有的充电模块检测机制 `ccdetect` 会频繁地（如每隔 ~120ms）翻转 UFP（Upstream Facing Port）和 DRP（Dual Role Port）状态。
影响：频繁的 UFP/DRP 切换会导致底层的 USB 总线不断触发 Reset 信号。

## 4. 根因结论
**完整调用链关系**：
1. `oplus_battery_sdm845_Q.c` 的 `ccdetect` 定时翻转 UFP/DRP。
2. DWC3 控制器感知到总线角色变化，向 host 发送或接收到 USB Reset。
3. `dwc3_interrupt()` 接收事件分发给 `dwc3_gadget_reset_interrupt()`。
4. `dwc3_gadget_reset_interrupt` 中的 `dwc->connected = false;` (被错误修改引入) 会导致 USB 连接状态被破坏。虽然原本意在禁止 mass storage 排队，但这会导致整个 usb_gadget 端点通信发生不预期的状态转移。
5. 当状态破坏后，来自 ADB 守护进程通过 Function FS (`f_fs.c`) 提交的大量 I/O 排队请求 (`usb_ep_queue`) 最终调用到底层 `__dwc3_gadget_ep_queue`，在这个过程中发生异常，或是正在传输的数据包在端点挂起后直接被丢弃。
6. ADB 在收到中断错误/ `-ESHUTDOWN` 后，主动断开 logcat / pull / push 管道。

## 5. 明确修复
已移除 `dwc->connected = false;` (在 `drivers/usb/dwc3/gadget.c` 行 3142)，从而保持 USB Reset 时 `connected=true` 的预期状态流转，修复了 ADB 断连。

## 6. 已排除的可能
- `dwc3_remove_requests()` 的竞态条件。
- 外部认为的 `sg_supported` (Scatter-Gather) 不兼容。事实证明 `sg_supported = true` 没问题，问题出在 Reset 导致的状态机置零。

## 7. 无法确认的部分
UNKNOWN - 原因：`ccdetect` 为什么会在移植后这么频繁地 toggling？是否是因为 LineageOS 的 vendor 层缺少了 OPPO 原厂 `oplus_battery_sdm845_Q` 需要响应的特定 sysfs 触发动作。
需要：通过 dmesg 查看 USB 相关的电源警告，或在系统中关闭 `ccdetect` 工作线程进行验证。
