/* SPDX-License-Identifier: GPL-2.0 */
/*
 * opporoot - minimal in-kernel root for OPPO Find X (PAFM00) bring-up.
 *
 * Called from do_execveat_common() before exec_binprm(), with the bprm whose
 * ->cred has already been snapshotted by prepare_bprm_creds().  See
 * drivers/misc/oppo/opporoot.c for the rationale and the trigger path.
 */
#ifndef _LINUX_OPPOROOT_H
#define _LINUX_OPPOROOT_H

struct linux_binprm;

#ifdef CONFIG_OPPO_SIMPLE_ROOT
void opporoot_maybe_escalate(struct linux_binprm *bprm);
#else
static inline void opporoot_maybe_escalate(struct linux_binprm *bprm)
{
	(void)bprm;
}
#endif

#endif /* _LINUX_OPPOROOT_H */
