// SPDX-License-Identifier: GPL-2.0
/*
 * opporoot - minimal in-kernel root for OPPO Find X (PAFM00) bring-up.
 *
 * Purpose: this kernel tree is under active porting and the device needs a
 * root shell to collect evidence (dmesg, tinymix, /proc, /sys).  APatch was
 * used before, but re-patching every test boot image by hand slowed the loop
 * down.  This is a deliberately minimal, in-tree escape hatch instead.
 *
 * Trigger: executing the file /data/local/tmp/su.  do_execveat_common() calls
 * opporoot_maybe_escalate() with the bprm right before exec_binprm(), and the
 * helper rewrites bprm->cred -- the credential object that install_exec_creds()
 * commits -- to uid/gid 0 with the full capability set.
 *
 * Note on placement: bprm->cred is snapshotted by prepare_bprm_creds() (via
 * prepare_exec_creds()) long before this point, while the task still holds the
 * unprivileged credentials.  Escalating current_cred() here instead only
 * changed SELinux state and left the new program at uid 2000 (observed with
 * kernel #40); the credential that actually gets installed is bprm->cred.
 *
 * Why an execve hook and not a character device:
 *   - a misc device node lands in /dev, and Android's ueventd re-creates
 *     unlisted nodes with mode 0600 (observed: crw------- root root on
 *     /dev/opporoot), so the unprivileged caller can never open it;
 *   - the trigger path lives in /data/local/tmp, which is 0771 shell:shell.
 *     Only uid 2000 (adb shell) or root can traverse it, so no ordinary app
 *     can reach the trigger even though the mechanism itself is not a secret.
 *
 * SELinux is switched to permissive on the first escalation: uid 0 alone
 * still carries the caller's u:r:shell:s0 label, and every operation would be
 * avc-denied.  This is a debug facility, not a fix -- `echo 1 >
 * /sys/fs/selinux/enforce` restores enforcing at any time.
 *
 * WARNING: debug backdoor for a device the owner physically controls.  It is
 * gated only by the trigger path, so never ship a kernel built with
 * CONFIG_OPPO_SIMPLE_ROOT=y.
 *
 * The trigger is userspace-only: nothing is reachable before the root
 * filesystem is up, so this cannot bypass the bootloader or verified boot.
 */

#include <linux/kernel.h>
#include <linux/string.h>
#include <linux/sched.h>
#include <linux/cred.h>
#include <linux/binfmts.h>
#include <linux/capability.h>
#include <linux/opporoot.h>

/* Keep in sync with opporoot/build_su.sh (where the binary is pushed). */
#define OPPOROOT_TRIGGER_PATH	"/data/local/tmp/su"

#ifdef CONFIG_SECURITY_SELINUX
extern int selinux_enforcing;
#endif

void opporoot_maybe_escalate(struct linux_binprm *bprm)
{
	struct cred *cred;

	if (!bprm || !bprm->cred || !bprm->filename)
		return;
	if (strcmp(bprm->filename, OPPOROOT_TRIGGER_PATH))
		return;

	cred = bprm->cred;

	cred->uid = cred->euid = cred->suid = cred->fsuid = GLOBAL_ROOT_UID;
	cred->gid = cred->egid = cred->sgid = cred->fsgid = GLOBAL_ROOT_GID;

	/* Same shape as init_cred: no securebits, everything in the bounding
	 * and permitted/effective sets.
	 */
	cred->securebits = 0;
	cred->cap_inheritable = CAP_EMPTY_SET;
	cred->cap_permitted = CAP_FULL_SET;
	cred->cap_effective = CAP_FULL_SET;
	cred->cap_bset = CAP_FULL_SET;
	cred->cap_ambient = CAP_EMPTY_SET;

#ifdef CONFIG_SECURITY_SELINUX
	if (selinux_enforcing) {
		selinux_enforcing = 0;
		pr_info("opporoot: SELinux set permissive (debug root)\n");
	}
#endif

	pr_info("opporoot: pid %d (%s) escalated via %s\n",
		current->pid, current->comm, OPPOROOT_TRIGGER_PATH);
}
