# Bug 挖掘报告

## 1. 搜索策略
在此次 ADB 断连和传感器审计的排查中，采用了以下系统性搜索方法：
- **分支对比命令**：使用 `git diff origin/oppo-oss..origin/ColorOS11` 精确锚定 `drivers/usb/dwc3/`、`drivers/usb/gadget/`、`drivers/usb/core/` 等核心目录的修改。
- **关键字挖掘**：通过 `grep -rni` 在差异文件中搜索 `dwc->connected`、`TXFIFO`、`disconnect`、`sg_supported`、`ccdetect` 等由于经验已知容易出问题的高危节点。
- **代码历史溯源**：使用 `git log -p` 和 `git blame` 追溯具体可疑行的引入时间和目的（例如 commit `4df1e1d9e` 引入的 `dwc->connected = false` 以及相关的 `sg_supported` 注释）。
- **DTS/Kconfig 审计**：对比 defconfig（`sdm845_defconfig`），检查内核开关，搜索 `qcom,msm-ssc-sensors` 以验证 Sensor Hub 支持。

## 2. 已确认的 bug 点
**Bug 1: Gadget 中断错误清除连接状态导致 ADB 传输截断**
- **文件:行号**：`drivers/usb/dwc3/gadget.c:3142`
- **代码片段**：
  ```c
	dwc->connected = true;

	/*
	 * Ideally, dwc3_reset_gadget() would trigger the function
	 * drivers to stop any active transfers through ep disable.
	 * ...
	 */
	dwc->connected = false;
  ```
- **触发机制详解**：
  1. `drivers/power/oppo/charger_ic/oplus_battery_sdm845_Q.c` 中的 `ccdetect` 逻辑（OPPO 私有 Type-C 检测）可能由于系统移植后缺少某些上层交互，导致其发生高频的 UFP/DRP toggling（约 120ms 一次）。
  2. 这种翻转引发频繁的 USB Bus Reset 中断。
  3. 控制器进中断调用 `dwc3_gadget_reset_interrupt`，然而该代码在这里被无理强制设为 `dwc->connected = false;`。
  4. 此时任何排队请求如 `adb logcat` 和 `pull/push` 因为 `!dwc->connected` 被拦截抛弃返回 `-ESHUTDOWN`。
- **证据**：`git diff` 明确显示 ColorOS11 分支在此处强行插入了 `dwc->connected = false;`。相关 `ccdetect` 机制在代码的 `sg_supported` 注释中有直接旁证。

## 3. 高度可疑点（待运行时验证）
**可疑点 1: ConfigFS 的 max_speed 被篡改**
- **为什么可疑**：`drivers/usb/gadget/configfs.c` 中，设备的 `.max_speed` 被从 `USB_SPEED_SUPER` 提升至 `USB_SPEED_SUPER_PLUS`。结合 `f_fs.c` 的描述符支持改动，这可能引发速度协商错误（特别是 Find X 原硬件未必完全稳定支持 10Gbps USB 3.1 Gen 2），这也是促发底层 reset 不稳的原因之一。
- **需要什么命令验证**：在内核中加入 FTrace 或 `dmesg` 观察 USB 枚举时的实际速度（`cat /sys/class/udc/*/current_speed`）。

**可疑点 2: ccdetect 机制的健康度**
- **为什么可疑**：如果 `ccdetect` 会在 LineageOS (Android 15) 上一直死循环 toggling，那哪怕 ADB 的错误丢包补上了，设备功耗依然会有严重问题。
- **验证命令**：观察 `dmesg` 中是否有 `[OPLUS_CHG]...ccdetect_gpio is unstable` 之类的循环打印，或者关闭该功能测试。

## 4. 已排除的可能
- **`sg_supported` 引起的传输中断**：尽管之前有开发者通过关闭 `sg_supported` 来尝试解决连接问题，但这只是掩盖了真实 Bug (Reset 触发 `connected=false`)。
- **`dwc3_remove_requests()` 竞态条件**：通过代码比对，所有对该函数的调用仍在安全锁（`spin_lock`）保护内，予以排除。
- **传感器驱动代码被恶意阉割**：排查了 `drivers/sensors/` 和 `drivers/iio/`，所有关键驱动（BMI160、BMP280 等）代码均存在且正常。

## 5. 无法确认的部分
- **传感器与系统层的衔接**：内核传感器通过 SSC 子系统运行。至于 LineageOS 上的 `sensorservice` 和专有 Hal 是否能与 `sensors-ssc` 通信并接收事件，无法在静态代码树中确认。
- **下一步需要什么**：在实际设备运行 `adb shell dumpsys sensorservice` 取证。
