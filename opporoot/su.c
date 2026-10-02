/*
 * su - minimal root shell for OPPO Find X (PAFM00) bring-up.
 *
 * Companion of drivers/misc/oppo/opporoot.c (CONFIG_OPPO_SIMPLE_ROOT).
 * The kernel escalates this process inside do_execveat_common(), i.e. before
 * the binary even starts, so all this program does is sanity-check that it
 * really is uid 0 and then hand over to a shell.
 *
 * Must be executed from its trigger path, /data/local/tmp/su: the kernel
 * compares the execve() filename against that exact string.
 *
 * Usage:
 *   su                      interactive shell
 *   su -c "id"              run one command
 *   su cmd arg...           run one command (implicit -c)
 *
 * Build with the NDK clang, statically: see opporoot/build_su.sh
 */

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

#define SU_PATH		"/data/local/tmp/su"
#define CMD_MAX		4096

static void read_trim(const char *path, char *buf, size_t bufsz)
{
	ssize_t n;
	int fd;

	buf[0] = '\0';
	fd = open(path, O_RDONLY);
	if (fd < 0)
		return;

	n = read(fd, buf, bufsz - 1);
	close(fd);
	if (n <= 0) {
		buf[0] = '\0';
		return;
	}

	buf[n] = '\0';
	while (n > 0 && (buf[n - 1] == '\n' || buf[n - 1] == '\0'))
		buf[--n] = '\0';
}

/* One-line banner on stderr, so `su -c <cmd>` keeps stdout clean. */
static void announce(void)
{
	char ctx[256];
	char enf[32];

	read_trim("/proc/self/attr/current", ctx, sizeof(ctx));
	read_trim("/sys/fs/selinux/enforce", enf, sizeof(enf));

	fprintf(stderr, "su: uid=%d gid=%d context=%s selinux=%s\n",
		getuid(), getgid(),
		ctx[0] ? ctx : "?",
		enf[0] ? (enf[0] == '0' ? "permissive" : "enforcing") : "?");
}

int main(int argc, char **argv)
{
	char cmd[CMD_MAX];
	size_t len = 0;
	int i, first;

	if (getuid() != 0) {
		fprintf(stderr, "su: not root (uid=%d)\n", getuid());
		fprintf(stderr, "su: the kernel escalates only the execve() of %s\n",
			SU_PATH);
		fprintf(stderr, "su: check CONFIG_OPPO_SIMPLE_ROOT=y in the running kernel\n");
		return 1;
	}

	if (setgid(0) != 0 || setuid(0) != 0) {
		fprintf(stderr, "su: setuid/setgid failed: %s\n", strerror(errno));
		return 1;
	}

	announce();

	if (argc <= 1) {
		execl("/system/bin/sh", "-sh", (char *)NULL);
		goto fail;
	}

	first = (strcmp(argv[1], "-c") == 0) ? 2 : 1;
	for (i = first; i < argc; i++) {
		size_t alen = strlen(argv[i]);

		/* need room for the separator, the argument and the NUL */
		if (len + (len ? 1 : 0) + alen + 1 > sizeof(cmd)) {
			fprintf(stderr, "su: command too long\n");
			return 1;
		}
		if (len)
			cmd[len++] = ' ';
		memcpy(cmd + len, argv[i], alen);
		len += alen;
	}
	cmd[len] = '\0';

	if (len == 0) {
		fprintf(stderr, "su: empty command\n");
		return 1;
	}

	execl("/system/bin/sh", "sh", "-c", cmd, (char *)NULL);

fail:
	fprintf(stderr, "su: cannot exec /system/bin/sh: %s\n", strerror(errno));
	return 1;
}
