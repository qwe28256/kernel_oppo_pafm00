// SPDX-License-Identifier: GPL-2.0-only
/*
 * Copyright (C) 2026 Antigravity / OPPO SDM845 Port
 * Dummy/Compatibility nodes for OPLUS ORMS & Performance Services
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/uaccess.h>
#include <linux/kobject.h>
#include <linux/sysfs.h>

/* Simple value holder for proc/sysfs nodes */
static int wbfn_enable_val = 1;
static int wbfn_dynamic_tw_enable_val = 1;
static int sched_isolation_val = 0;
static int sched_deisolation_val = 0;
static int usrtch_val = 0;
static int fpsgo_force_onoff_val = 0;

static ssize_t generic_proc_write(struct file *file, const char __user *buffer,
				  size_t count, loff_t *pos)
{
	int *val = PDE_DATA(file_inode(file));
	char kbuf[32];
	size_t len = min(count, sizeof(kbuf) - 1);

	if (copy_from_user(kbuf, buffer, len))
		return -EFAULT;
	kbuf[len] = '\0';
	if (val)
		(void)sscanf(kbuf, "%d", val);
	return count;
}

static int generic_proc_show(struct seq_file *m, void *v)
{
	int *val = m->private;
	seq_printf(m, "%d\n", val ? *val : 0);
	return 0;
}

static int generic_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, generic_proc_show, PDE_DATA(inode));
}

static const struct file_operations generic_proc_fops = {
	.open    = generic_proc_open,
	.read    = seq_read,
	.write   = generic_proc_write,
	.llseek  = seq_lseek,
	.release = single_release,
};

/* Sysfs node for /sys/kernel/fpsgo/common/force_onoff */
static struct kobject *fpsgo_kobj;
static struct kobject *fpsgo_common_kobj;

static ssize_t fpsgo_force_onoff_show(struct kobject *kobj,
				      struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "%d\n", fpsgo_force_onoff_val);
}

static ssize_t fpsgo_force_onoff_store(struct kobject *kobj,
				       struct kobj_attribute *attr,
				       const char *buf, size_t count)
{
	(void)sscanf(buf, "%d", &fpsgo_force_onoff_val);
	return count;
}

static struct kobj_attribute fpsgo_force_onoff_attr =
	__ATTR(force_onoff, 0664, fpsgo_force_onoff_show, fpsgo_force_onoff_store);

static int __init oplus_dummy_nodes_init(void)
{
	struct proc_dir_entry *ufsplus_dir;
	struct proc_dir_entry *perfmgr_dir;
	struct proc_dir_entry *boost_ctrl_dir;
	struct proc_dir_entry *eas_ctrl_dir;
	struct proc_dir_entry *tchbst_dir;
	struct proc_dir_entry *user_dir;
	int ret;

	pr_info("oplus_dummy_nodes: Initializing ORMS compatibility nodes\n");

	/* /proc/ufsplus_ctrl/ */
	ufsplus_dir = proc_mkdir("ufsplus_ctrl", NULL);
	if (ufsplus_dir) {
		proc_create_data("wbfn_enable", 0664, ufsplus_dir,
				 &generic_proc_fops, &wbfn_enable_val);
		proc_create_data("wbfn_dynamic_tw_enable", 0664, ufsplus_dir,
				 &generic_proc_fops, &wbfn_dynamic_tw_enable_val);
	}

	/* /proc/perfmgr/boost_ctrl/eas_ctrl/ */
	perfmgr_dir = proc_mkdir("perfmgr", NULL);
	if (perfmgr_dir) {
		boost_ctrl_dir = proc_mkdir("boost_ctrl", perfmgr_dir);
		if (boost_ctrl_dir) {
			eas_ctrl_dir = proc_mkdir("eas_ctrl", boost_ctrl_dir);
			if (eas_ctrl_dir) {
				proc_create_data("set_sched_isolation", 0664,
						 eas_ctrl_dir, &generic_proc_fops,
						 &sched_isolation_val);
				proc_create_data("set_sched_deisolation", 0664,
						 eas_ctrl_dir, &generic_proc_fops,
						 &sched_deisolation_val);
			}
		}

		/* /proc/perfmgr/tchbst/user/usrtch */
		tchbst_dir = proc_mkdir("tchbst", perfmgr_dir);
		if (tchbst_dir) {
			user_dir = proc_mkdir("user", tchbst_dir);
			if (user_dir) {
				proc_create_data("usrtch", 0664, user_dir,
						 &generic_proc_fops, &usrtch_val);
			}
		}
	}

	/* /sys/kernel/fpsgo/common/force_onoff */
	fpsgo_kobj = kobject_create_and_add("fpsgo", kernel_kobj);
	if (fpsgo_kobj) {
		fpsgo_common_kobj = kobject_create_and_add("common", fpsgo_kobj);
		if (fpsgo_common_kobj) {
			ret = sysfs_create_file(fpsgo_common_kobj,
						&fpsgo_force_onoff_attr.attr);
			if (ret)
				pr_warn("oplus_dummy_nodes: failed to create force_onoff\n");
		}
	}

	return 0;
}

device_initcall(oplus_dummy_nodes_init);
MODULE_LICENSE("GPL v2");
