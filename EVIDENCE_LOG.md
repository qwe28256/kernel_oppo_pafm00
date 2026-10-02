# 证据日志

### [1] [命令] 查找 connected 相关的日志
$ git log --all --oneline | grep 4df1e1d9e
4df1e1d9e gitignore: exclude gg.img test boot image (65MB artifact)

### [2] [命令] 查看 4df1e1d9e 引入的 dwc->connected 改动
$ git show 4df1e1d9e:drivers/usb/dwc3/gadget.c | grep -n -B 5 -A 5 "dwc->connected = false;"
3120-	dwc->gadget.speed = USB_SPEED_UNKNOWN;
3121-	dwc->setup_packet_pending = false;
3122-	dwc->link_state = DWC3_LINK_STATE_SS_DIS;
3123-	usb_gadget_set_state(&dwc->gadget, USB_STATE_NOTATTACHED);
3124-
3125:	dwc->connected = false;
3126-	wake_up_interruptible(&dwc->wait_linkstate);
3127-}
3128-
3129-static void dwc3_gadget_reset_interrupt(struct dwc3 *dwc)
3130-{
--
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

### [3] [命令] 查看 oppo-oss 中同样的上下文
$ git show origin/oppo-oss:drivers/usb/dwc3/gadget.c | sed -n '3129,3150p'
	dwc->connected = true;

	/*
	 * WORKAROUND: DWC3 revisions <1.88a have an issue which
	 * would cause a missing Disconnect Event if there's a
	 * pending Setup Packet in the FIFO.
	 *
	 * There's no suggested workaround on the official Bug
	 * report, which states that "unless the driver/application
	 * is doing any special handling of a disconnect event,
	 * there is no functional issue".
	 *
	 * Unfortunately, it turns out that we _do_ some special
	 * handling of a disconnect event, namely complete all
	 * pending transfers, notify gadget driver of the
	 * disconnection, and so on.
	 *
	 * Our suggested workaround is to follow the Disconnect
	 * Event steps here, instead, based on a setup_packet_pending
	 * flag. Such flag gets set whenever we have a SETUP_PENDING
	 * status for EP0 TRBs and gets cleared on XferComplete for the
	 * same endpoint.

### [4] [命令] 对比 configfs.c 的 max_speed
$ git diff origin/oppo-oss..origin/ColorOS11 -- drivers/usb/gadget/configfs.c | grep -B 2 -A 2 max_speed
	.resume		= configfs_composite_resume,

-	.max_speed	= USB_SPEED_SUPER,
+	.max_speed	= USB_SPEED_SUPER_PLUS,
	.driver = {
		.owner          = THIS_MODULE,
--
	gi->composite.suspend = NULL;
	gi->composite.resume = NULL;
-	gi->composite.max_speed = USB_SPEED_SUPER;
+	gi->composite.max_speed = USB_SPEED_SUPER_PLUS;

	spin_lock_init(&gi->spinlock);

### [5] [命令] 检查 f_fs.c 的 ssp_descriptors
$ git diff origin/oppo-oss..origin/ColorOS11 -- drivers/usb/gadget/function/f_fs.c | grep -B 2 -A 2 ssp_descriptors
	if (likely(super)) {
-		func->function.ss_descriptors = vla_ptr(vlabuf, d, ss_descs);
+		func->function.ss_descriptors = func->function.ssp_descriptors =
+			vla_ptr(vlabuf, d, ss_descs);
		ss_len = ffs_do_descs(ffs->ss_descs_count,
--
	func->function.hs_descriptors = NULL;
	func->function.ss_descriptors = NULL;
+	func->function.ssp_descriptors = NULL;
	func->interfaces_nums = NULL;


### [6] [命令] 检查传感器驱动差异
$ git diff --stat origin/oppo-oss..origin/ColorOS11 -- drivers/sensors/ drivers/iio/ drivers/input/misc/
 drivers/iio/accel/bma180.c                        |  88 ++--
 drivers/iio/accel/bma220_spi.c                    |  10 +-
 drivers/iio/accel/bmc150-accel-core.c             |  15 +-
 drivers/iio/accel/kxcjk-1013.c                    |  44 +-
 drivers/iio/accel/kxsd9.c                         |  22 +-
 drivers/iio/accel/mma7455_core.c                  |  16 +-
 drivers/iio/accel/mma8452.c                       |  28 +-
 drivers/iio/accel/stk8312.c                       |  12 +-
 drivers/iio/accel/stk8ba50.c                      |  17 +-
 drivers/iio/adc/ad7793.c                          |   1 +
 drivers/iio/adc/ad_sigma_delta.c                  |   8 +-
 drivers/iio/adc/at91-sama5d2_adc.c                |   2 +-
 drivers/iio/adc/at91_adc.c                        |   4 +-
 drivers/iio/adc/ina2xx-adc.c                      |  11 +-
 drivers/iio/adc/mcp3422.c                         |  16 +-
 drivers/iio/adc/men_z188_adc.c                    |   9 +-
 drivers/iio/adc/palmas_gpadc.c                    |   4 +-
 drivers/iio/adc/rockchip_saradc.c                 |   2 +-
 drivers/iio/adc/ti-adc081c.c                      |  11 +-
 drivers/iio/adc/ti-adc12138.c                     |  13 +-
 drivers/iio/adc/ti-adc128s052.c                   |   6 +
 drivers/iio/adc/ti-ads1015.c                      |  22 +-
 drivers/iio/adc/twl6030-gpadc.c                   |   2 +
 drivers/iio/adc/vf610_adc.c                       |  10 +-
 drivers/iio/common/ssp_sensors/ssp_spi.c          |  11 +-
 drivers/iio/dac/ad5446.c                          |  11 +-
 drivers/iio/dac/ad5504.c                          |   4 +-
 drivers/iio/dac/ad5592r-base.c                    |   6 +-
 drivers/iio/dac/ad5593r.c                         |  46 ++-
 drivers/iio/dac/ad5624r_spi.c                     |  18 +-
 drivers/iio/dummy/iio_simple_dummy.c              |  20 +-
 drivers/iio/gyro/bmg160_core.c                    |  10 +-
 drivers/iio/gyro/itg3200_buffer.c                 |  17 +-
 drivers/iio/health/afe4403.c                      |  18 +-
 drivers/iio/health/afe4404.c                      |  20 +-
 drivers/iio/humidity/am2315.c                     |  16 +-
 drivers/iio/imu/adis16400_buffer.c                |   5 +-
 drivers/iio/imu/adis16400_core.c                  |   3 +-
 drivers/iio/imu/adis_buffer.c                     |   8 +-
 drivers/iio/imu/bmi160/bmi160_core.c              |  12 +-
 drivers/iio/industrialio-buffer.c                 |   6 +-
 drivers/iio/industrialio-sw-trigger.c             |   6 +-
 drivers/iio/inkern.c                              |  40 +-
 drivers/iio/light/apds9960.c                      |  12 +-
 drivers/iio/light/hid-sensor-prox.c               |  14 +-
 drivers/iio/light/isl29125.c                      |  10 +-
 drivers/iio/light/ltr501.c                        |  32 +-
 drivers/iio/light/max44000.c                      |  12 +-
 drivers/iio/light/opt3001.c                       |   6 +-
 drivers/iio/light/si1145.c                        |  19 +-
 drivers/iio/light/stk3310.c                       |   6 +-
 drivers/iio/light/tcs3414.c                       |  10 +-
 drivers/iio/magnetometer/ak8974.c                 |  29 +-
 drivers/iio/magnetometer/ak8975.c                 |  27 +-
 drivers/iio/magnetometer/mag3110.c                |  13 +-
 drivers/iio/pressure/bmp280-core.c                |   7 +-
 drivers/iio/pressure/mpl3115.c                    |   9 +-
 drivers/iio/pressure/ms5611_core.c                |  11 +-
 drivers/iio/pressure/ms5611_spi.c                 |   2 +-
 drivers/iio/pressure/zpa2326.c                    |   4 +-
 drivers/iio/proximity/pulsedlight-lidar-lite-v2.c |  11 +-
 drivers/iio/trigger/iio-trig-sysfs.c              |   7 +-
 drivers/input/misc/adxl34x.c                      |   2 +-
 drivers/input/misc/cm109.c                        |   7 +-
 drivers/input/misc/qpnp-power-on.c                | 466 +---------------------
 drivers/input/misc/sparcspkr.c                    |   1 +
 drivers/input/misc/uinput.c                       |  18 +
 67 files changed, 629 insertions(+), 756 deletions(-)

### [7] [命令] 检查 DTS 中的传感器节点
$ git grep -n "qcom,msm-ssc-sensors" origin/oppo-oss -- arch/arm64/boot/dts/qcom/sdm845.dtsi
origin/oppo-oss:arch/arm64/boot/dts/qcom/sdm845.dtsi:1968:	ssc_sensors: qcom,msm-ssc-sensors {
origin/oppo-oss:arch/arm64/boot/dts/qcom/sdm845.dtsi:1969:		compatible = "qcom,msm-ssc-sensors";

### [8] [命令] 检查 Kconfig 差异 (sdm845_defconfig)
$ git diff origin/oppo-oss..origin/ColorOS11 -- arch/arm64/configs/sdm845_defconfig
diff --git a/arch/arm64/configs/sdm845_defconfig b/arch/arm64/configs/sdm845_defconfig
old mode 100755
new mode 100644
index 4067a36f1..270075fed
--- a/arch/arm64/configs/sdm845_defconfig
+++ b/arch/arm64/configs/sdm845_defconfig
@@ -1,10 +1,5 @@
 # CONFIG_LOCALVERSION_AUTO is not set
 # CONFIG_FHANDLE is not set
-#ifdef OPLUS_BUG_STABILITY
-#system_server VintfObject.verify return 1
-#Runtime info and framework compatibility matrix are incompatible: For config CONFIG_USELIB, value = y but required n
-# CONFIG_USELIB is not set
-#endif
 CONFIG_AUDIT=y
 # CONFIG_AUDITSYSCALL is not set
 CONFIG_NO_HZ=y
@@ -317,17 +312,13 @@ CONFIG_KEYBOARD_GPIO=y
 # CONFIG_INPUT_MOUSE is not set
 CONFIG_INPUT_JOYSTICK=y
 CONFIG_INPUT_TOUCHSCREEN=y
-#ifndef VENDOR_EDIT
-#ONFIG_TOUCHSCREEN_SYNAPTICS_DSX_CORE=y
-#CONFIG_TOUCHSCREEN_SYNAPTICS_DSX_RMI_DEV=y
-#CONFIG_TOUCHSCREEN_SYNAPTICS_DSX_FW_UPDATE=y
-#CONFIG_TOUCHSCREEN_SYNAPTICS_DSX_FW_UPDATE_EXTRA_SYSFS=y
-#CONFIG_TOUCHSCREEN_SYNAPTICS_DSX_TEST_REPORTING=y
-#endif
+CONFIG_TOUCHSCREEN_SYNAPTICS_DSX_CORE=y
+CONFIG_TOUCHSCREEN_SYNAPTICS_DSX_RMI_DEV=y
+CONFIG_TOUCHSCREEN_SYNAPTICS_DSX_FW_UPDATE=y
+CONFIG_TOUCHSCREEN_SYNAPTICS_DSX_FW_UPDATE_EXTRA_SYSFS=y
+CONFIG_TOUCHSCREEN_SYNAPTICS_DSX_TEST_REPORTING=y
 CONFIG_INPUT_MISC=y
-#ifndef VENDOR_EDIT
-#CONFIG_INPUT_HBTP_INPUT=y
-#endif
+CONFIG_INPUT_HBTP_INPUT=y
 CONFIG_INPUT_QPNP_POWER_ON=y
 CONFIG_INPUT_UINPUT=y
 # CONFIG_SERIO_SERPORT is not set
@@ -360,17 +351,10 @@ CONFIG_QCOM_DLOAD_MODE=y
 CONFIG_POWER_RESET_XGENE=y
 CONFIG_POWER_RESET_SYSCON=y
 CONFIG_QPNP_FG_GEN3=y
-#ifdef VENDOR_EDIT
-#CONFIG_SMB1355_SLAVE_CHARGER=y
+CONFIG_SMB1355_SLAVE_CHARGER=y
 CONFIG_QPNP_SMB2=y
-#CONFIG_QPNP_QNOVO=y
-CONFIG_OPLUS_SDM845_Q_CHARGER=y
-CONFIG_OPLUS_CHECK_CHARGERID_VOLT=y
-CONFIG_OPLUS_SHORT_C_BATT_CHECK=y
-CONFIG_OPLUS_SHIP_MODE_SUPPORT=y
-CONFIG_OPLUS_SHORT_HW_CHECK=y
-CONFIG_OPLUS_SHORT_USERSPACE=y
-#endif
+CONFIG_QPNP_QNOVO=y
+CONFIG_SMB1390_CHARGE_PUMP=y
 CONFIG_SENSORS_QPNP_ADC_VOLTAGE=y
 CONFIG_THERMAL=y
 CONFIG_THERMAL_WRITABLE_TRIPS=y
@@ -608,9 +592,7 @@ CONFIG_QCOM_DCC_V2=y
 CONFIG_QTI_RPM_STATS_LOG=y
 CONFIG_QCOM_FORCE_WDOG_BITE_ON_PANIC=y
 CONFIG_QMP_DEBUGFS_CLIENT=y
-#ifndef VENDOR_EDIT
-#CONFIG_MEM_SHARE_QMI_SERVICE=y
-#endif /*VENDOR_EDIT*/
+CONFIG_MEM_SHARE_QMI_SERVICE=y
 CONFIG_MSM_REMOTEQDSS=y
 CONFIG_QSEE_IPC_IRQ_BRIDGE=y
 CONFIG_CNSS_CRYPTO=y
@@ -654,10 +636,6 @@ CONFIG_EFIVAR_FS=y
 CONFIG_ECRYPT_FS=y
 CONFIG_ECRYPT_FS_MESSAGING=y
 CONFIG_SDCARD_FS=y
-#ifdef VENDOR_EDIT
-CONFIG_NLS_UTF8=y
-CONFIG_EXFAT_FS=y
-# endif
 # CONFIG_NETWORK_FILESYSTEMS is not set
 CONFIG_NLS_CODEPAGE_437=y
 CONFIG_NLS_ISO8859_1=y
@@ -749,114 +727,3 @@ CONFIG_CRYPTO_AES_ARM64_NEON_BLK=y
 CONFIG_CRYPTO_CRC32_ARM64=y
 CONFIG_XZ_DEC=y
 CONFIG_QMI_ENCDEC=y
-# ifdef VENDOR_EDIT
-CONFIG_OPPO_COMMON_SOFT=y
-CONFIG_OPPO_DEVICE_IFNO=y
-CONFIG_OPPO_ARCH_FILE=y
-# endif /*VENDOR_EDIT*/
-
-#ifdef OPLUS_SYSTEM_KERNEL
-CONFIG_DETECT_HUNG_TASK=y
-CONFIG_OPLUS_FEATURE_HUNG_TASK_ENHANCE=y
-CONFIG_DEFAULT_HUNG_TASK_TIMEOUT=60
-#endif
-
-#ifdef VENDOR_EDIT
-CONFIG_TOUCHPANEL_SAMSUNG_S6SY761=y
-CONFIG_TOUCHPANEL_SAMSUNG=y
-CONFIG_TOUCHPANEL_OPPO=y
-CONFIG_TOUCHIRQ_UPDATE_QOS=y
-#endif /* VENDOR_EDIT */
-#ifdef VENDOR_EDIT
-#CONFIG_RECORD_MDMRST=y
-#endif /* VENDOR_EDIT */
-#ifdef OPLUS_FEATURE_ACM
-CONFIG_OPLUS_FEATURE_ACM=y
-CONFIG_OPLUS_FEATURE_ACM_LOGGING=y
-#endif /* OPLUS_FEATURE_ACM */
-#ifdef OPLUS_FEATURE_MODEM_MINIDUMP
-CONFIG_OPLUS_FEATURE_RECORD_MDMRST=y
-#endif /*OPLUS_FEATURE_MODEM_MINIDUMP*/
-
-#ifdef OPLUS_FEATURE_FACERECOGNITION
-CONFIG_OPPO_3D_FACE=y
-CONFIG_OPPO_3D_FACE_QCOM=y
-#endif /* OPLUS_FEATURE_FACERECOGNITION  */
-
-#ifdef OPLUS_FEATURE_CHG_BASIC
-CONFIG_OPPO_MOTOR=y
-CONFIG_MOTOR_CLASS_INTERFACE=y
-#endif
-
-#ifdef OPLUS_BUG_STABILITY
-CONFIG_OPLUS_FEATURE_OPROJECT=y
-#endif /* OPLUS_BUG_STABILITY */
-
-#ifdef OPLUS_BUG_STABILITY
-CONFIG_OPLUS_FEATURE_PHOENIX=y
-#endif /* OPLUS_BUG_STABILITY */
-CONFIG_OPLUS_FEATURE_PMIC_MONITOR=y
-
-CONFIG_OPLUS_FEATURE_SLABTRACE_DEBUG=y
-
-#ifdef OPLUS_FEATURE_HANS_FREEZE
-CONFIG_OPPO_HANS=y
-#endif /*OPLUS_FEATURE_HANS_FREEZE*/
-CONFIG_OPLUS_FEATURE_QCOM_MINIDUMP_ENHANCE=y
-CONFIG_OPLUS_FEATURE_SHUTDOWN_DETECT=y
-
-#BSP.Kernel.Stability, 2020/12/14, add uboot log
-CONFIG_OPLUS_FEATURE_UBOOT_LOG=y
-
-#ifdef OPLUS_FEATURE_POWERINFO_STANDBY
-CONFIG_OPLUS_POWER_QCOM=y
-CONFIG_OPLUS_WAKELOCK_PROFILER=y
-#endif
-
-#ifdef OPLUS_FEATURE_QCOM_PMICWD
-CONFIG_OPLUS_FEATURE_QCOM_PMICWD=y
-
-#ifdef OPLUS_FEATURE_FUSE_FS_SHORTCIRCUIT
-CONFIG_OPLUS_FEATURE_FUSE_FS_SHORTCIRCUIT=y
-#endif
-
-#ifdef VENDOR_EDIT
-CONFIG_EMMC_SDCARD_OPTIMIZE=y
-#endif
-
-# ifdef VENDOR_EDIT
-CONFIG_CRYPTO_LZ4=y
-CONFIG_OPPO_ZRAM_OPT=y
-# endif
-# ifdef VENDOR_EDIT
-CONFIG_PGTABLE_MAPPING=y
-# endif
-CONFIG_OPLUS_FEATURE_PADL_STATISTICS=y
-#ifdef VENDOR_EDIT
-CONFIG_OPPO_MEM_MONITOR=y
-CONFIG_OPLUS_MEM_MONITOR=y
-CONFIG_FG_TASK_UID=y
-CONFIG_OPLUS_HEALTHINFO=y
-CONFIG_SLAB_STAT_DEBUG=y
-CONFIG_SLUB_DEBUG=y
-#endif /*VENDOR_EDIT*/
-CONFIG_PROCESS_RECLAIM=y
-CONFIG_PROCESS_RECLAIM_ENHANCE=y
-CONFIG_OPLUS_FEATURE_DUMP_DEVICE_INFO=y
-#ifdef OPLUS_FEATURE_DUMPDEVICE
-CONFIG_PSTORE=y
-CONFIG_PSTORE_CONSOLE=y
-CONFIG_PSTORE_PMSG=y
-CONFIG_PSTORE_RAM=y
-#endif
-
-CONFIG_OPLUS_FEATURE_THEIA=y
-
-#ifdef VENDOR_EDIT
-CONFIG_KMALLOC_DEBUG=y
-CONFIG_VMALLOC_DEBUG=y
-CONFIG_DUMP_TASKS_MEM=y
-
-CONFIG_OPPO_SVELTE=y
-#endif /*VENDOR_EDIT*/
-
