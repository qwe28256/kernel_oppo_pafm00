# 传感器驱动审计

## 1. 传感器清单表
| 文件路径 | ColorOS11 | oppo-oss | oppo-oss-module | 差异 |
| -------- | --------- | -------- | --------------- | ---- |
| `drivers/sensors/sensors_ssc.c` | 存在 | 存在 | 无法确认 | 修改 |
| `drivers/iio/accel/bmc150-accel-core.c` | 存在 | 存在 | 无法确认 | 修改 |
| `drivers/iio/accel/kxcjk-1013.c` | 存在 | 存在 | 无法确认 | 修改 |
| `drivers/iio/accel/mma8452.c` | 存在 | 存在 | 无法确认 | 修改 |
| `drivers/iio/gyro/bmg160_core.c` | 存在 | 存在 | 无法确认 | 修改 |
| `drivers/iio/imu/bmi160/bmi160_core.c` | 存在 | 存在 | 无法确认 | 修改 |
| `drivers/iio/light/apds9960.c` | 存在 | 存在 | 无法确认 | 修改 |
| `drivers/iio/light/stk3310.c` | 存在 | 存在 | 无法确认 | 修改 |
| `drivers/iio/magnetometer/ak8974.c` | 存在 | 存在 | 无法确认 | 修改 |
| `drivers/iio/magnetometer/ak8975.c` | 存在 | 存在 | 无法确认 | 修改 |
| `drivers/iio/pressure/bmp280-core.c` | 存在 | 存在 | 无法确认 | 修改 |
| `drivers/input/sensors/bmi160/` | 存在 | 无法确认 | 无法确认 | 无法确认 |
| `drivers/input/sensors/smi130/` | 存在 | 无法确认 | 无法确认 | 无法确认 |

注：`oppo-oss-module` 未在当前检出提交中展现直接相关文件。

## 2. 逐个传感器分析

### 加速度计与陀螺仪 (IMU)
- **芯片型号**: Bosch BMI160 / SMI130 等。
- **驱动文件路径**: `drivers/iio/imu/bmi160/bmi160_core.c`, `drivers/input/sensors/bmi160/`
- **分支的存在性**: ColorOS11 与 oppo-oss 中存在。
- **Kconfig 编译开关**: 需要检查 `CONFIG_BMI160` (默认无关闭动作)。
- **DTS 节点**: 存在于 SSC 守护中。
- **状态判定**: 正常。

### 磁力计
- **芯片型号**: AKM ak8974 / ak8975 等。
- **驱动文件路径**: `drivers/iio/magnetometer/ak8974.c`。
- **分支的存在性**: ColorOS11 和 oppo-oss 均存在。
- **状态判定**: 正常。

### 光线与接近传感器
- **芯片型号**: APDS9960, STK3310 等常规型号。
- **驱动文件路径**: `drivers/iio/light/apds9960.c`。
- **分支的存在性**: 均存在，包含在 IIO 子系统。
- **状态判定**: 正常。

### 气压计
- **芯片型号**: BMP280 等。
- **驱动文件路径**: `drivers/iio/pressure/bmp280-core.c`。
- **状态判定**: 正常。

### 霍尔传感器
- **无法确认**: 未在直接的修改日志中看到霍尔传感器的明确标识。通常与磁力计结合，或由 GPIO / PMIC 处理。

## 3. DTS 节点对比
- **qcom,msm-ssc-sensors** (`arch/arm64/boot/dts/qcom/sdm845.dtsi`): 存在且状态为 `"ok"`，固件指向 `"slpi"`。
- **中断与供电**: SSC (Snapdragon Sensor Core) 集中管理底层传感器电源和中断。未见对 DTS 传感器节点的恶意删除。

## 4. 缺失或异常项
OPPO 深度依赖 Sensor Hub (SSC, `drivers/sensors/sensors_ssc.c`) 和 SLPI 来调度底层传感器事件。由于 `sensors_ssc.c` 存在差异，可能涉及 `sysfs` 节点变动，但该文件主体在各分支均健康存活，无被直接移除的迹象。

## 5. Kconfig/Makefile 差异
无传感器驱动被主动在 Kconfig 和 Makefile 中剔除。

## 6. 无法确认的部分
- 闭源或私有模块驱动是否依赖于 `oppo-oss-module` 中特有的 vendor 代码以与 `sensors.hal` 交互，这需要实际运行日志验证。
- 搜索范围：`drivers/sensors/`、`drivers/iio/`、`drivers/input/misc/`。
- 排除依据：核心驱动文件仍在。
- 剩余可能：部分专有传感器位于 `drivers/oplus/` 或 `drivers/oppo/` 但被上层闭源库直接驱动。
- 下一步需要什么：运行时使用 `dumpsys sensorservice` 取证。
