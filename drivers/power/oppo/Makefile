# OPLUS charging framework for SDM845 (OPPO Find X / PAFM00)
# Ported from oppo_oss drivers/power/oppo (branch oppo/sdm845_r_11.0_find_x @ d3aa37fcc18c).
# Entry gating happens in drivers/power/Makefile via obj-$(CONFIG_OPLUS_SDM845_Q_CHARGER) += oppo/
# (mirrors OPPO original). Inside, everything is obj-y like the OPPO original; ICs without
# matching DT nodes simply never bind.
# NOTE: subdir-ccflags-y is a no-op in this 4.9 kbuild (KBUILD_SUBDIR_CCFLAGS is
# exported but never consumed), so per-dir ccflags-y live in each subdir Makefile.
#
# OPLUS_FEATURE_CHG_BASIC: OPPO's internal build injects OPLUS_FEATURE_* macros
# globally; the OSS tree does not define them. Runtime evidence that the shipped
# PAFM00 kernel has this feature ACTIVE: /sys/class/power_supply/{battery,main,
# pc_port,ac,usb} exist and battery/charge_full is readable (2026-10-01, adb).
ccflags-y += -DOPLUS_FEATURE_CHG_BASIC
obj-y   += charger_ic/
obj-y   += gauge_ic/
obj-y   += vooc_ic/
obj-y   += adapter_ic/

obj-y   += oplus_charger.o
obj-y   += oplus_gauge.o
obj-y   += oplus_vooc.o
obj-y   += oplus_adapter.o
obj-y   += oplus_short.o
