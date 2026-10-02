// SPDX-License-Identifier: GPL-2.0
/*
 * opporoot - minimal in-kernel root for OPPO Find X (PAFM00) bring-up.
 *
 * Purpose: this kernel tree is under active porting, and the device needs a
 * root shell to collect evidence (dmesg, tinymix, /proc, /sys).  APatch was
 * used before, but patching every test boot image by hand slows the loop down.
 * This driver provides a deliberately minimal, in-tree escape hatch instead.
 *
 * Design (kept intentionally small):
 *   - one misc device /dev/opporoot (mode 0666 so the unprivileged caller can
 *     reach it; it must be openable before it holds any privilege),
 *   - exactly one ioctl: OPPOROOT_ESCALATE with argument OPPOROOT_MAGIC.
 *     A wrong command or a wrong magic value returns -EINVAL, so an accidental
 *     ioctl() from unrelated code does not escalate anything,
 *   - on a matching call the *calling* task gets init_cred-derived kernel
 *     credentials (uid/gid 0 and the full capability set) via
 *     commit_creds(prepare_kernel_cred(NULL)),
 *   - SELinux is switched to permissive, because uid 0 alone still carries the
 *     caller's u:r:shell:s0 label and every operation would be avc-denied.
 *     This is a debug facility, not a fix: `echo 1 > /sys/fs/selinux/enforce`
 *     restores enforcing at any time.
 *
 * WARNING: this is a debug backdoor for a device the owner physically controls.
 * It is gated only by the ioctl magic, so any process that can open
 * /dev/opporoot can become root.  Do not ship a kernel built with
 * CONFIG_OPPO_SIMPLE_ROOT=y.
 *
 * The root shell is not reachable until userspace is booted, so this cannot be
 * used to bypass the bootloader or any verified-boot chain.
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/fs.h>
#include <linux/ioctl.h>
#include <linux/miscdevice.h>
#include <linux/sched.h>
#include <linux/cred.h>

/* Keep in sync with opporoot/su.c */
#define OPPOROOT_ESCALATE	_IO(0x6f, 1)
#define OPPOROOT_MAGIC		0x524f4f54u	/* "ROOT" */

#ifdef CONFIG_SECURITY_SELINUX
extern int selinux_enforcing;
#endif

static long opporoot_ioctl(struct file *filp, unsigned int cmd,
			   unsigned long arg)
{
	struct cred *new;

	if (cmd != OPPOROOT_ESCALATE || arg != OPPOROOT_MAGIC)
		return -EINVAL;

	new = prepare_kernel_cred(NULL);
	if (!new)
		return -ENOMEM;

	/* prepare_kernel_cred(NULL) already yields uid 0 with a full capability
	 * set; spell the ids out so the intent is obvious.
	 */
	new->uid = new->euid = new->suid = new->fsuid = GLOBAL_ROOT_UID;
	new->gid = new->egid = new->sgid = new->fsgid = GLOBAL_ROOT_GID;
	commit_creds(new);

#ifdef CONFIG_SECURITY_SELINUX
	if (selinux_enforcing) {
		selinux_enforcing = 0;
		pr_info("opporoot: SELinux set permissive (debug root)\n");
	}
#endif

	pr_info("opporoot: pid %d (%s) escalated to uid 0\n",
		current->pid, current->comm);

	return 0;
}

static const struct file_operations opporoot_fops = {
	.owner		= THIS_MODULE,
	.unlocked_ioctl	= opporoot_ioctl,
	.llseek		= no_llseek,
};

static struct miscdevice opporoot_dev = {
	.minor	= MISC_DYNAMIC_MINOR,
	.name	= "opporoot",
	.fops	= &opporoot_fops,
	.mode	= 0666,
};

static int __init opporoot_init(void)
{
	int ret;

	ret = misc_register(&opporoot_dev);
	if (ret) {
		pr_err("opporoot: misc_register failed: %d\n", ret);
		return ret;
	}

	pr_info("opporoot: ready at /dev/opporoot\n");
	return 0;
}

static void __exit opporoot_exit(void)
{
	misc_deregister(&opporoot_dev);
}

module_init(opporoot_init);
module_exit(opporoot_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("minimal in-kernel root for OPPO PAFM00 bring-up");
