# OPLUS internal build injects OPLUS_FEATURE_* globally; replicate for this subtree
ccflags-y += -DOPLUS_FEATURE_CHG_BASIC

# Main battery/charger drivers for OPLUS SDM845_Q (OPPO Find X / PAFM00).
# Mirrors oppo_oss charger_ic/Makefile OPLUS_SDM845_Q_CHARGER branch:
#   obj-y += oplus_battery_sdm845_Q.o / oplus_bq25882.o oplus_da9313.o / oplus_short_ic.o
# NOTE: oplus_battery_sdm845_Q.o is OPPO's full fork of qpnp-smb2 (compatible
# "qcom,qpnp-smb2"); the stock qpnp-smb2.o is therefore NOT built for this target
# (see drivers/power/supply/qcom/Makefile patch).
# OPPO's oplus_battery_sdm845_Q.h uses '#include "../../supply/qcom/smb-reg.h"',
# which relies on an -I search fallback (relative ../../ from charger_ic/ is
# drivers/, not drivers/power/). Provide it so the fallback resolves.
ccflags-y += -I$(srctree)/drivers/power/oppo/charger_ic

obj-y   += oplus_battery_sdm845_Q.o
obj-y   += oplus_bq25882.o oplus_da9313.o
obj-y   += oplus_short_ic.o
