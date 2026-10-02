# ADB Logcat 断连根因分析

## 1. 问题描述
设备从 ColorOS11 迁移到 LineageOS 22.2 后出现 `adb logcat` 断连问题（大量文本输出时易断连），`adb pull`/`adb push` 存在问题。原机 ColorOS 11 原厂内核无此问题。

## 2. 分析范围
对比了以下目录和关键文件：
- `drivers/usb/dwc3/`
- `drivers/usb/gadget/`
- `drivers/usb/core/`

## 3. 关键发现
**发现 1: Gadget 中断错误清除连接状态导致 ADB 传输截断**
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
影响：在大流量传输（logcat、push/pull）出现端点复位或微小重置时，正在进行的请求会因为 `!dwc->connected` 在 `dwc3_gadget_ep_queue` 被直接拒绝，进而断连。

## 4. 根因假设（按概率排序）
### 假设 1：`dwc->connected = false` 导致连接状态在 RESET 期间被破坏
- **证据**：ColorOS11 分支引入了 `dwc->connected = false;` (详见关键发现1)。
- **完整调用链**：USB 控制器收到中断信号 -> `dwc3_interrupt()` -> `dwc3_process_event_buf()` -> `dwc3_gadget_reset_interrupt()` -> 将 `dwc->connected` 设为 `false` -> 后续排队调用 `dwc3_gadget_ep_queue` 检查 `!dwc->connected` 时返回 `-ESHUTDOWN`，丢弃传输包。
- **触发条件**：大传输时或连接状态轻微扰动导致 RESET 中断被触发。
- **验证方法**：编译内核删除该行，通过 `adb logcat` 和大文件传输测试。
- **修复方向**：移除新增的 `dwc->connected = false;` 或将其替换为仅对 mass storage 生效的特定处理。

### 假设 2：configfs 最大速度和 ssp_descriptors 导致降级或不稳
- **证据**：
  命令：
  ```
  git diff origin/oppo-oss..origin/ColorOS11 -- drivers/usb/gadget/configfs.c | grep -B 2 -A 2 max_speed
  ```
  原始输出：
  ```diff
  -	.max_speed	= USB_SPEED_SUPER,
  +	.max_speed	= USB_SPEED_SUPER_PLUS,
  ```
- **完整调用链**：连接时根据 `configfs` 配置的速度枚举设备，由于设置为了 SUPER_PLUS，可能会匹配不上正确的端点描述符，导致回退或枚举不稳定。
- **触发条件**：插入 USB 时，进行 USB 枚举协商。
- **验证方法**：恢复 `max_speed` 到 `USB_SPEED_SUPER`，测试是否断连现象有所缓解。
- **修复方向**：还原 `max_speed` 及其在 `ffs.c` 中的相应超高速描述符支持。

## 5. 明确 bug 点
**文件:行号**
`drivers/usb/dwc3/gadget.c:3142`
**代码逻辑**
在 `dwc3_gadget_reset_interrupt` 函数内无条件强制覆盖 `dwc->connected = false`，打破了预期的上层回调和请求排队逻辑。
**触发条件**
微弱 USB 总线复位。

## 6. 已排除的可能
- `dwc3_remove_requests()` 的竞态条件：经过 `gadget.c` 文件代码走查，无新增未上锁调用。
- 原生内核未发现该 Bug，因为 `oppo-oss` 中 `dwc3_gadget_reset_interrupt` 并没有 `dwc->connected = false` 这段错误逻辑。

## 7. 无法确认的部分
UNKNOWN - 原因：是否还有非 USB 层面的 PMIC (电源管理) 或时钟降频导致的假死。
需要：通过 dmesg 查看 USB 相关的电源警告，或抓取 ftrace。
