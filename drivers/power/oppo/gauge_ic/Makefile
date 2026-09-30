# OPLUS internal build injects OPLUS_FEATURE_* globally; replicate for this subtree
ccflags-y += -DOPLUS_FEATURE_CHG_BASIC

# Gauge IC drivers (OPPO Find X uses oplus,bq27541-battery on i2c10 @ 0x55)
obj-y   += oplus_bq27541.o
obj-y   += oplus_sha1_hmac.o
