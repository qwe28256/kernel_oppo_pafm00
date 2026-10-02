# 驱动差异汇总

## 1. 文件级差异表
| 文件路径 | ColorOS11 | oppo-oss | 差异类型 | 优先级 |
| -------- | --------- | -------- | -------- | ------ |
| `drivers/usb/dwc3/gadget.c` | 存在 | 存在 | 修改 (引入 `dwc->connected = false;`) | **极高** |
| `drivers/usb/gadget/configfs.c` | 存在 | 存在 | 修改 (`max_speed` 和 configfs attr) | 高 |
| `drivers/usb/gadget/function/f_fs.c` | 存在 | 存在 | 修改 (超高速描述符支持) | 中 |
| `arch/arm64/configs/sdm845_defconfig`| 存在 | 存在 | 修改 (Kconfig 配置) | 高 |
| `drivers/sensors/sensors_ssc.c` | 存在 | 存在 | 相同 | 低 |

## 2. 重点目录差异
### USB
- `drivers/usb/dwc3/`：
  - `dwc3/gadget.c` 中的中断复位处理存在严重 bug，人为置 `connected` 为 `false` 导致后续端点排队直接由于 `-ESHUTDOWN` 被拒绝。这会导致严重的 USB 连接不稳和 ADB 断连。
  - FIFO 大小计算和写屏障 (wmb) 存在变动，影响微观上的稳定。
- `drivers/usb/gadget/`：
  - configfs 注册中修改了最大支持的 speed，加入了部分 Android 特定的 composite 和 acc 配置。

### Sensors (传感器)
- 驱动均包含在 IIO 子系统或专有目录中，无主要传感器遭到直接阉割或删除。
- 依赖于 SSC 架构，底层通过 SLPI 处理，设备树 (DTS) 节点 `qcom,msm-ssc-sensors` 完整且 active。

## 3. Kconfig / Makefile 差异
- 对比了 `sdm845_defconfig`。ColorOS11 分支加入了诸多特定配置，但 USB/DWC3 的宏 (`CONFIG_USB_DWC3`, `CONFIG_USB_CONFIGFS`) 在 ColorOS11 中同样开启。
- 没有发现会导致 USB 核心功能或 Sensor 核心功能崩溃的 Kconfig 修改。

## 4. 潜在风险清单（按优先级）
1. **[优先级：极高]** `drivers/usb/dwc3/gadget.c:3142`：错误重置了 `connected`，直接引发 logcat 数据过大时的排队拒绝。
2. **[优先级：高]** `drivers/usb/gadget/configfs.c`：强行提升 Gadget 支持速度，可能会破坏端点描述符的选择逻辑，在没有适当降级策略的线缆连接下引起掉线。
3. **[优先级：中]** `dwc3/core.c`：FIFO 大小和读取逻辑。可能引起微弱的数据竞态，不过相比 1 和 2 风险较小。

## 5. 无法确认的部分
- Oppo 特定硬件的闭源驱动是否存在与 LineageOS (Android 15) 的兼容性问题。
- `drivers/media/` 或 `drivers/gpu/` 中可能的私有 vendor code 未深入展开，但当前任务焦点在于 USB 和 Sensors。
