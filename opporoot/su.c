/*
 * su - minimal root shell for OPPO Find X (PAFM00) bring-up.
 *
 * Companion of drivers/misc/oppo/opporoot.c (CONFIG_OPPO_SIMPLE_ROOT).
 * The kernel side escalates whoever calls the ioctl; this program only opens
 * the device, performs that ioctl, drops into uid/gid 0 and execs a shell.
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
#include <sys/ioctl.h>

/* Keep in sync with drivers/misc/oppo/opporoot.c */
#define OPPOROOT_ESCALATE	_IO(0x6f, 1)
#define OPPOROOT_MAGIC		0x524f4f54u	/* "ROOT" */

#define CMD_MAX	4096

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
	int fd, i, first;

	fd = open("/dev/opporoot", O_RDWR);
	if (fd < 0) {
		fprintf(stderr, "su: open /dev/opporoot: %s\n", strerror(errno));
		fprintf(stderr, "su: is the kernel built with CONFIG_OPPO_SIMPLE_ROOT=y?\n");
		return 1;
	}

	if (ioctl(fd, OPPOROOT_ESCALATE, OPPOROOT_MAGIC) < 0) {
		fprintf(stderr, "su: escalation ioctl failed: %s\n", strerror(errno));
		close(fd);
		return 1;
	}
	close(fd);

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
