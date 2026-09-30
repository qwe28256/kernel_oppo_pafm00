#
# Makefile for the touchscreen drivers.
#

obj-$(CONFIG_TOUCHSCREEN_OPLUS) += util_interface/
obj-$(CONFIG_TOUCHSCREEN_OPLUS) += touchpanel_common_driver.o touchpanel_prevention.o touchpanel_healthinfo.o
obj-$(CONFIG_TOUCHPANEL_ALGORITHM) += touchpanel_algorithm.o
obj-$(CONFIG_TOUCHPANEL_SAMSUNG) += Samsung/
ccflags-y += -I$(src)
