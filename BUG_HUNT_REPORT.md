# Bug 挖掘报告

## 1. 搜索策略
在此次 ADB 断连和传感器审计的排查中，采用了以下系统性搜索方法：
- **分支对比命令**：使用 `git diff origin/oppo-oss..origin/ColorOS11` 精确锚定 `drivers/usb/dwc3/`、`drivers/usb/gadget/`、`drivers/usb/core/` 等核心目录的修改。
- **关键字挖掘**：通过 `grep -rni` 在差异文件中搜索 `dwc->connected`、`TXFIFO`、`disconnect`、`sg_supported` 等由于经验已知容易出问题的高危节点。
- **代码历史溯源**：使用 `git log -p` 和 `git blame` 追溯具体可疑行的引入时间和目的（例如 commit `4df1e1d9e` 引入的 `dwc->connected = false`）。
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
- **触发条件**：在大量数据传输（如 `adb logcat` 或 `adb push/pull`）期间，USB 控制器触发微小重置或中断刷新，该函数被调用。
- **影响范围**：会导致正在进行的请求直接因为 `!dwc->connected` 在 `dwc3_gadget_ep_queue` 被拒绝，进而断连。
- **证据**：`git diff` 明确显示 ColorOS11 分支在此处强行插入了 `dwc->connected = false;`，覆写了前面原汁原味的 `dwc->connected = true;`。

## 3. 高度可疑点（待运行时验证）
**可疑点 1: ConfigFS 的 max_speed 被篡改**
- **为什么可疑**：`drivers/usb/gadget/configfs.c` 中，设备的 `.max_speed` 被从 `USB_SPEED_SUPER` 提升至 `USB_SPEED_SUPER_PLUS`。结合 `f_fs.c` 的描述符支持改动，这可能引发速度协商错误（特别是 Find X 原硬件未必完全稳定支持 10Gbps USB 3.1 Gen 2），这会导致 USB 控制器重置频繁，进而促发上述 Bug 1。
- **需要什么命令验证**：在内核中加入 FTrace 或 `dmesg` 观察 USB 枚举时的实际速度（`cat /sys/class/udc/*/current_speed`）。

**可疑点 2: dwc3_prepare_one_trb 中的 wmb()**
- **为什么可疑**：添加了显式内存屏障以防止 HWO 位提前置起。这是好意，但如果引起了非预期的延迟或状态机卡死，可能引发长传丢包。
- **验证命令**：观察 `dmesg` 中是否有大量的 TX FIFO Underrun/Overrun 事件。

## 4. 已排除的可能
- **`dwc3_remove_requests()` 竞态条件**：通过代码比对，所有对该函数的调用仍在安全锁（`spin_lock`）保护内，且并未遭到破坏，予以排除。
- **传感器驱动代码被恶意阉割**：排查了 `drivers/sensors/` 和 `drivers/iio/`，所有关键驱动（BMI160、BMP280 等）代码均存在且正常。

## 5. 无法确认的部分
- **传感器与系统层的衔接**：内核传感器通过 SSC 子系统运行。至于 Android 15 (LineageOS) 上的 `sensorservice` 和专有 Hal 是否能与 `sensors-ssc` 通信并接收事件，无法在仅静态分析代码树时确认。
- **下一步需要什么**：在实际设备运行 `adb shell dumpsys sensorservice` 和 `logcat | grep Sensors`，如果发现无数据流出，则可能是 SLPI 固件丢失或 vendor 库需要重置。
