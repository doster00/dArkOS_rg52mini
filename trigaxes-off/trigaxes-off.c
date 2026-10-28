/*
 * trigaxes-off: an LD_PRELOAD library that hides the analog trigger axes of
 * the RG52 Mini's pad (rk3562-joystick, ABS_Z and ABS_RZ) from one process.
 *
 * For the GTA San Andreas port (folder gtasa): a wrapper around the Android
 * game that reads the pad through evdev itself, grabbing it before SDL
 * starts. It does not know rk3562-joystick and takes its R36S layout,
 * which feeds ABS_Z into the right stick's X and ABS_RZ into its Y (R36S
 * kernels report the right stick there) and takes every axis's rest as
 * (min + max) / 2. Here the triggers are 0..32767, 0 at rest, so after the
 * first event of L2 the right stick sits at full left and the camera turns
 * until the right stick is moved; R2 does the same to the vertical. A light
 * touch or the trigger's noise past the kernel's dead zone is enough (L2 rose
 * to 1000-1300 with nobody pressing it). The wrapper binds L2/R2 to
 * BTN_TL2/BTN_TR2, which the kernel reports as well, so with the axes gone
 * they work as buttons.
 *
 * runport.sh preloads it for that port. Reads of any other device, and of
 * every other event of the pad, pass unchanged.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <linux/input.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <unistd.h>

#define PAD_NAME "rk3562-joystick"
#define INPUT_MAJOR 13
#define MAX_FD 1024

/* per fd: 0 not looked at yet, 1 the pad, 2 anything else */
static unsigned char fd_kind[MAX_FD];
static ssize_t (*real_read)(int, void *, size_t);
static int (*real_close)(int);

static int is_pad(int fd)
{
    struct stat st;
    char name[64] = "";

    if (fd < 0 || fd >= MAX_FD)
        return 0;
    if (!fd_kind[fd]) {
        fd_kind[fd] = 2;
        if (fstat(fd, &st) == 0 && S_ISCHR(st.st_mode) &&
            major(st.st_rdev) == INPUT_MAJOR &&
            ioctl(fd, EVIOCGNAME(sizeof(name) - 1), name) >= 0 &&
            strcmp(name, PAD_NAME) == 0)
            fd_kind[fd] = 1;
    }
    return fd_kind[fd] == 1;
}

ssize_t read(int fd, void *buf, size_t count)
{
    if (!real_read)
        real_read = (ssize_t (*)(int, void *, size_t))dlsym(RTLD_NEXT, "read");
    if (count < sizeof(struct input_event) || !is_pad(fd))
        return real_read(fd, buf, count);

    for (;;) {
        ssize_t n = real_read(fd, buf, count);
        struct input_event *ev = buf;
        size_t i, kept = 0, total;

        if (n <= 0 || n % sizeof(struct input_event))
            return n;
        total = n / sizeof(struct input_event);
        for (i = 0; i < total; i++) {
            if (ev[i].type == EV_ABS && (ev[i].code == ABS_Z || ev[i].code == ABS_RZ))
                continue;
            if (kept != i)
                ev[kept] = ev[i];
            kept++;
        }
        if (kept)
            return kept * sizeof(struct input_event);
        /* all of it dropped: read on, so a non-blocking fd ends in EAGAIN as before */
    }
}

int close(int fd)
{
    if (!real_close)
        real_close = (int (*)(int))dlsym(RTLD_NEXT, "close");
    if (fd >= 0 && fd < MAX_FD)
        fd_kind[fd] = 0;
    return real_close(fd);
}
