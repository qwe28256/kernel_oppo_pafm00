# 驱动差异汇总

## 1. 文件级差异（表 + 命令来源）
差异基于如下基线对比得出：`git diff origin/oppo-oss..origin/ColorOS11`。

| 文件路径 | ColorOS11 | oppo-oss | 差异类型 | 优先级 |
| -------- | --------- | -------- | -------- | ------ |
| `drivers/usb/dwc3/gadget.c` | 存在 | 存在 | 修改 (引入 `dwc->connected = false;` 及 `sg_supported` 注释等) | **极高** |
| `drivers/power/oppo/charger_ic/oplus_battery_sdm845_Q.c` | 存在 | 存在 | 修改 (ccdetect UFP/DRP toggling 相关) | **极高** |
| `drivers/usb/gadget/configfs.c` | 存在 | 存在 | 修改 (`max_speed` 设置为 SUPER_PLUS 等) | 高 |
| `drivers/usb/gadget/function/f_fs.c` | 存在 | 存在 | 修改 (加入了 ssp_descriptors) | 中 |
| `arch/arm64/configs/sdm845_defconfig`| 存在 | 存在 | 修改 (Oppo/Oplus 内核特性及防挂起增强) | 高 |
| `drivers/sensors/` | 存在 | 存在 | 相同 (无 diff) | 低 |
| `drivers/iio/` | 存在 | 存在 | 相同 (无 diff) | 低 |
| `drivers/input/misc/` | 存在 | 存在 | 相同 (无 diff) | 低 |

## 2. 重点目录差异（贴 diff）
### USB (drivers/usb/ & drivers/power/)
- **dwc3/gadget.c**：错误地修改了重置中断的行为：
命令：
```
git show 4df1e1d9e:drivers/usb/dwc3/gadget.c | grep -n -B 5 -A 5 "dwc->connected = false;"
```
原始输出（部分）：
```c
3137-	 * drivers to stop any active transfers through ep disable.
3138-	 * However, for functions which defer ep disable, such as mass
3139-	 * storage, we will need to rely on the call to stop active
3140-	 * transfers here, and avoid allowing of request queuing.
3141-	 */
3142:	dwc->connected = false;
```
这一修改会导致正常的 ADB 传输时发生微小重置便会中断数据。

- **charger_ic/oplus_battery_sdm845_Q.c**: ccdetect 频繁翻转
命令：
```
git grep -n "ccdetect" origin/ColorOS11 -- drivers/power/oppo/charger_ic/oplus_battery_sdm845_Q.c
```
这里包含了 OPPO 特有的供电检测逻辑，注释明确指出了 `ccdetect_work toggled UFP<->DRP every ~120ms`。这种极高频的重置行为与上述 `gadget.c` 的 Bug 相结合，导致了最终大规模的断连灾难。

- **gadget/configfs.c**：最大速度修改：
命令：
```
git diff origin/oppo-oss..origin/ColorOS11 -- drivers/usb/gadget/configfs.c | grep -B 2 -A 2 max_speed
```
原始输出：
```diff
-	.max_speed	= USB_SPEED_SUPER,
+	.max_speed	= USB_SPEED_SUPER_PLUS,
```
这可能引发硬件速度协商不稳。

## 3. Kconfig / Makefile 差异
命令：
```
git diff origin/oppo-oss..origin/ColorOS11 -- arch/arm64/configs/sdm845_defconfig | grep -E "USB|DWC3" | grep -v "#"
```
两分支在关键 USB/DWC3 开关（如 `CONFIG_USB_DWC3`, `CONFIG_USB_CONFIGFS`）上配置保持一致，没有因裁剪配置导致缺失模块。差异主要集中在 OPPO 的 `OPLUS_FEATURE_*` 上。

## 4. 优先级排序
1. **[极高]** `drivers/usb/dwc3/gadget.c:3142` 的逻辑破坏（必须并已回滚）。
2. **[极高]** `drivers/power/oppo/charger_ic/oplus_battery_sdm845_Q.c` 的 `ccdetect` 无脑 UFP/DRP 翻转。即使上面解决了断包，频繁 reset 依然会消耗设备性能。
3. **[高]** `configfs.c` 与 `f_fs.c` 关于 SUPER_PLUS 的适配。
4. **[低]** 传感器代码完全一致，不作为当前不稳的排查重点。

## 5. UNKNOWN 清单
- UNKNOWN — 原因：`ccdetect` 的持续触发是否是因为用户态特定的 `oplus-vendor-hal` 丢失导致？需要：提取 `dmesg | grep ccdetect` 以及 Android 的电量守护进程服务日志验证。
