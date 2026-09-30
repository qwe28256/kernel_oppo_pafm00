
snd-soc-ia6xx-objs := ia6xx-iacore.o iacore.o \
			iacore-cdev.o iacore-vs.o \
			iacore-fsm.o iacore-raw.o \
			iacore-pm.o ia6xx-i2s.o \
			iacore-uart.o iacore-uart-common.o

obj-$(CONFIG_SND_SOC_IA6XX)	+= snd-soc-ia6xx.o

# OPLUS port note: iacore.h uses #include <wakelock.h>; the header ships in this
# dir (Google's old Android wakelock API, self-contained).
ccflags-y += -I$(srctree)/techpack/audio/asoc/codecs/audience
