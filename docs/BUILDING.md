# Building

    git clone --recursive https://github.com/mamaich/dArkOS_rg52mini
    cd dArkOS_rg52mini
    make rg52mini

The first build takes most of a day; later ones are much shorter because the
Debian rootfs with the build's packages, ccache and every emulator are cached under
`Arkbuild_package_cache/` and `Arkbuild_ccache/`, and `make clean` leaves both
alone. Only `make clean_complete` throws them away.

`BUILD_KODI` defaults to `n`. Pass `BUILD_KODI=y` to include it — but read the
note in KNOWN-ISSUES first, because Kodi's dependency resolution has broken
other components before.

## Compilers that run natively in the chroot

Everything in `Arkbuild` runs under qemu, and a compiler under qemu is slow:
Azahar's core took 573 minutes there. `xtool.sh` keeps Debian's amd64 build of
the chroot's clang in `Arkbuild_package_cache/xtool-trixie-amd64` (a minbase
debootstrap with clang-19, lld-19, llvm-19 and libeatmydata1, about 1 GB) and
mounts it into the chroot for the recipes that build with clang:
`build_pcsx2sa.sh` (ARMSX2), `build_malisx2.sh` (its C and C++; its Rust stays
under qemu) and `build_a53_core azahar` in `build_retroarch.sh`.
The host's CPU runs it as it is; cmake, ninja, the shell, GNU ld and strip
still go through qemu. It compiles inside the chroot, against the chroot's
headers, libraries and GCC installation, at the chroot's paths, so a PGO
profile still finds its functions.

Checked on 2026-10-21: Azahar's core built that way in 11 minutes, and differs
from the one the chroot's own clang built in 573 only by the build time Azahar
writes into it and the build ID that follows from it.

How it is put together, for whoever has to touch it:

- The x86-64 loader is `/lib64/ld-linux-x86-64.so.2`, and arm64 Debian has no
  `/lib64`. `mount_xtool` makes it a symlink to `usr/lib/x86_64-linux-gnu`,
  where the amd64 libraries are bind-mounted read-only, and puts the amd64 LLVM
  at `/usr/lib/llvm-19-amd64`. The arm64 loader and ldconfig look in neither.
  `umount_xtool` takes all three out again, and `remove_arkbuild` calls it
  first, so the `rm -rf` of `make clean` cannot reach the cache through them.
- clang takes its target from the name it is run by:
  `aarch64-linux-gnu-clang(++)` are links in the amd64 tree.
- `setup_xtool` installs the source version of clang-19 the chroot has, from
  the chroot's own apt sources, and builds and runs a test program in the
  chroot. If any of that fails it says so in one line, and the recipe builds
  with the chroot's clang under qemu, as before.
- eatmydata preloads `libeatmydata.so` by name; the amd64 tree has its own, so
  the amd64 processes load that one.

## The chroot from the cache

`bootstrap_rootfs-rk3562.sh` and `build_deps.sh` took 30 minutes and 3 h 20 min
of the 2026-10-19 build, nearly all of it apt and dpkg under qemu, and on most
builds they do what they did the time before. `rootfs_cache.sh` keeps what they
leave in `Arkbuild_package_cache/rk3562/`:

- `rootfs-bootstrap.tar.zst`: the whole chroot after the bootstrap;
- `rootfs-deps.tar.zst` and `rootfs-deps.removed`: what `build_deps.sh` wrote,
  and what it deleted, on top of exactly that bootstrap copy.

Each has a key in its `.key`: a hash of the stage's script and package lists,
the functions and settings they use, the BSP files it installs, Debian's point
release (from `dists/trixie/Release`; the suite's packages change only then),
and, for deps, the bootstrap copy under it. A build whose keys match unpacks
the two in minutes. `rm Arkbuild_package_cache/rk3562/rootfs-*` makes the next
build run them again.

- The kernel step runs between the two and is not in either: the deps copy
  leaves out `/boot`, `/usr/lib/modules` and `/var/lib/initramfs-tools`. A new
  kernel unpacks both copies, and its initrd is made from the system as the
  bootstrap leaves it, as before. Running the kernel step after the deps
  instead would change the initrd: they install fuse3, ntfs-3g, dmsetup and
  xfsprogs, which add initramfs hooks.
- A copy is kept only if apt failed nowhere in the stage (`install_package`,
  and the bootstrap's own apt-get runs), and becomes one to unpack only when
  its build gets to the end (`commit_rootfs_cache`, after `create_image.sh`).
  A stage can go wrong without stopping the build, and the copy would put the
  same fault in every image after it. An older copy is deleted only when a new
  one replaces it.
- A build that cannot work out a key says so in its log ("rootfs cache: no key
  for ...") and runs the stage. The point release is asked of deb.debian.org up
  to five times: on 2026-10-22 one lost answer had a build run `build_deps.sh`
  with a matching copy at hand.
- What the stages fetch without a version (meson and libgo2 from their default
  branches, the 32-bit Mali blob from christianhaitian's repository) stays as
  it was when the copy was made, until a key changes.
- The deps copy leaves out the packages apt downloaded;
  `cleanup_filesystem.sh` deletes them anyway.
- Both are read and written through a bind mount of `Arkbuild` that has none of
  the mounts inside it: the copies hold the image's filesystem only, including
  what lies under `/dev` and the rest, and nothing deleted when the deps copy
  is unpacked can be the host's.

The deps copy is the difference between two lists of every path with its inode
and ctime, one taken before the stage and one after. A path that is new or has
another inode or ctime goes into the archive, with the directory it is in, and
a path that is gone into `rootfs-deps.removed`. ctime changes with anything
done to a file, its contents, mode, owner or links, and cannot be set back;
the mtime cannot tell, because dpkg sets it from the package.

## WSL

Upstream says WSL "will not work due to no support for chroot". That is not
the obstacle. chroot works fine under WSL2; what does not work is binfmt_misc,
and without it every aarch64 binary in the chroot fails with `Exec format
error` — starting with `debootstrap --second-stage`.

Ubuntu ships `/usr/lib/systemd/system/systemd-binfmt.service.d/wsl.conf` with
`ConditionVirtualization=!wsl`, so the qemu handlers are never registered:

    systemd-binfmt.service was skipped because of an unmet condition check
    (ConditionVirtualization=!wsl)

Do not fix this with `systemctl restart systemd-binfmt`. Its `ExecStop`
unregisters everything including `WSLInterop`, which is how Windows binaries
are launched from Linux, and the start half is still skipped. Register the two
handlers directly instead: qemu-aarch64 for the build chroot, qemu-arm for the
32-bit one. `tools/qemu-host/register-qemu-binfmt.sh` does that; run it as
root at boot, from a unit of your own. It registers qemu-aarch64 with
`/usr/local/bin/qemu-aarch64-darkos` when that exists (next section), else
Ubuntu's `/usr/bin/qemu-aarch64-static`, and qemu-arm with
`/usr/bin/qemu-arm-static`, both with flags `OCF`. A handler already
registered is left as it is, so to change the interpreter remove the entry
first (`echo -1 > /proc/sys/fs/binfmt_misc/qemu-aarch64`). With Ubuntu's
interpreters it writes:

    :qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-aarch64-static:OCF
    :qemu-arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-arm-static:OCF

Flag `F` matters: it opens the interpreter at registration time, so it stays
reachable from inside the chroot.

Two more things WSL needs:

* **btrfs must be loaded before the build starts.** The build filesystem is
  btrfs on a loop device. If the module is not loaded, `mkfs.btrfs` succeeds
  (it is userspace) and `mount` fails — and the build used to carry on for two
  and a half hours writing into a plain directory on the host filesystem
  instead of the image, only failing at `write_rootfs`. `setup_partition-rk3562.sh`
  now checks the mount, but keep `btrfs` in `/etc/modules-load.d/` anyway.
* **`sudo` without a password.** `./FreeSudo.sh` does this. Under WSL you can
  also reach root without one via `wsl -u root`, which is useful when sudo
  itself is what is misconfigured.

`wsl --shutdown` unloads kernel modules, so anything not in `modules-load.d`
has to be reloaded afterwards.

## qemu: emulate a Cortex-A53, not "max" (2026-10-25)

qemu-user runs an aarch64 binary on the CPU model "any", which is "max": every
feature, pointer authentication (PAuth) among them, computed with the QARMA5
cipher in C. Debian's arm64 packages are built with `-mbranch-protection`, so
their functions start and end with PAC instructions, and in the build chroot
most of the time went there. On a CPU without PAuth those instructions are
NOPs (they are in the hint space), so the same binaries run unchanged on a
Cortex-A53 model, which is also what the RK3562 has. Measured in the build
chroot, WSL2 on a Xeon E5-2680 v4 (20 of its 28 threads):

| qemu (aarch64 user mode) | g++ -O2 pugixml.cpp | dpkg -l, apt-cache, perl loop | python loop |
|---|---|---|---|
| Ubuntu's 8.2.2, default (max) | 134.7 s | 52.0 s | 150.2 s |
| the same, `QEMU_CPU=cortex-a53` | 80.8-82.0 s | 4.0 s | 7.5 s |
| 11.1.2, -O3 -march=native, LTO, cortex-a53 | 81.3 s | 4.3-4.4 s | 7.8-8.0 s |
| 11.1.2 the same, and a profile (PGO) | 80.5-88.7 s | 4.2-4.4 s | 7.7-7.8 s |
| 8.2.10, -O3 -march=native, LTO, cortex-a53 | 78.6-79.5 s | 3.8 s | 7.0-8.1 s |

`max,pauth-impdef=on` (16.4 s on the python loop) and `max,pauth=off` (8.4 s)
are in between. A newer QEMU and a profile do not help: the time is in the
code TCG generates, which neither touches.

So the build host runs the last row: `tools/qemu-host/build.sh` builds it with
cortex-a53 as the default CPU and installs `/usr/local/bin/qemu-aarch64-darkos`.
It then installs `tools/qemu-host/register-qemu-binfmt.sh` (above) as
`/usr/local/sbin/register-qemu-binfmt.sh`, removes the old aarch64 entry and
runs it, so aarch64 binaries go to the new interpreter at once; without
`qemu-aarch64-darkos` the script falls back to Ubuntu's. A default in the
binary, not `QEMU_CPU` in the environment: the build runs `sudo chroot`, and
sudo drops the environment.
Programs in the chroot that pick features at run time see the A53's (fp, asimd,
aes, pmull, sha1, sha2, crc32), as on the device; "max" offered them SVE.

## Patches that no other page describes

Most of our patches are described where their effect is (KNOWN-ISSUES.md,
PERFORMANCE.md, TODO.md). These are not:

| patch | what it does |
|---|---|
| `retroarch-patch-0000-rk3562-rotation-90` | drm_go2 on the portrait panel: `GO2_ROTATION_DEGREES_90`, no rejection of portrait displays, XRGB8888 |
| `retroarch-patch-0008-norotation-rga` | 0000 turned back to unrotated, for a second RetroArch build; the RK3562 never installs that build (TODO.md, "Left by the patch audit after 1.3") |
| `retroarch-patch-0016-rk3562-oga-rotation-90` | the oga video driver turned by another 180 degrees: with `video_driver = "oga"` everything was upside down |
| `retroarch-patches/retroarch-patch-0020-libgo2-rgba-format` | libgo2 maps XRGB8888 to `RK_FORMAT_RGBA_8888`, not BGRA: red and blue were swapped in the oga driver's RGA blits |
| `sdl2-patch-0004-odroidgoa-kmsdrm`, `sdl2-patch-0005-odroidgoa-rotate-cursor` (this repo) | SDL2 makes landscape GBM surfaces and RGA turns each frame onto the portrait panel, and the cursor with it; `build_sdl2.sh` copies them in as 0005 and 0006 for the RG52 Mini |
| `flycastsa-patch-004-rotate-270` | flycast's `rend.Rotate90` turns the other way, 270 degrees; it only acts with `Rotate90=yes`, which the image no longer sets since the rotate layer turns Vulkan |

Dropped from upstream in the merge of 2026-10-05 (core builds' c82b722),
because every patch that matches a recipe's glob applies on every device:
`dolphinsa-patch-011-miniloong-rotate270` and
`ppsspp-patch-0010-miniloong-vulkan-rotation` (the miniloong's own rotation,
which on top of ours would rotate twice), `retroarch-patch-0016-vulkan-miniloong-menu-fix`
(the miniloong's widget placement; our own 0016 has that number now) and
`retroarch-patch-0013-fix-color-rotated-build` (0000 already makes the
presenter XRGB8888, so 0013 does not apply). ECWolf's 002 went when upstream
took it in (KNOWN-ISSUES.md).

## Things that cost hours, once each

**The toolchain PATH used to be relative.** `utils.sh` put
`prebuilts/gcc/.../bin` on `PATH`, and `build_kernel-rk3562.sh` runs
`make -C kernel_rk3562`. make changes directory first, so the relative entry
then resolved against the kernel tree and the linker vanished:

    scripts/Kconfig.include:40: linker 'aarch64-linux-gnu-ld' not found

Fixed — it is absolute now. It only ever bit when the toolchain was not
installed system-wide in `/opt/toolchains`.

**A Windows reboot kills the build.** Everything else survives: the image, the
caches, the mounts. If the build dies late, the mounts and loop devices are
still in place and the remaining steps can be re-run by hand rather than
starting over — that is how the 2026-09-15 image was finished after
`fetch_compat_libs.sh` aborted in `finishing_touches`.

**Nothing started from `wsl.exe` outlives that invocation.** Not with `nohup`,
not with `setsid`, not with `disown` — WSL kills every process the invocation
spawned, not merely the foreground process group, so the usual detaching tricks
all fail. It is not cgroup-based: every client lands in a shared `/init.scope`
and separate invocations leave each other alone. What survives is a process
whose parent is systemd:

    sudo systemd-run --unit=darkos-build \
         --working-directory=/home/mamaich/rg52/dArkOS_rg52mini \
         --setenv=BUILD_KODI=y make rg52mini

    systemctl status darkos-build
    journalctl -u darkos-build -f

Start a build that way if the terminal — or the editor, or the agent session —
that launched it might not be there in nine hours. A build started the ordinary
way is tied to a live `wsl.exe` client, and closing it is the same as a reboot.
Nothing can be done about it afterwards: the running build has a controlling
terminal and a live parent, and neither can be changed from outside.

**`systemd-run` is necessary and not sufficient**, which cost three interrupted
builds on 2026-09-30 before it was understood. Two different things kill a
build, and the second one takes systemd with it:

* The agent session's own supervisor can reap a long-running background shell
  when the host is short of memory. A service is not a background shell, so
  `systemd-run` answers this one. Redirecting output to a file does not: the
  processes die with the invocation regardless of where their stdout points.
* **WSL shuts the whole VM down about a minute after the last `wsl.exe` client
  exits**, and that stops every systemd service with it. The default
  `vmIdleTimeout` is 60000 ms. The first build survived three hours and forty
  minutes only because a progress monitor happened to hold a client open the
  whole time; when the monitor died too, the VM went down a minute later.

So either keep a client alive for as long as the build runs, or raise the
timeout in `%UserProfile%\.wslconfig` and stop depending on it:

    [wsl2]
    vmIdleTimeout=7200000

It takes effect on the next VM start, so `wsl --shutdown` applies it — or
simply the next reboot, which is how it landed here.

**WSL 3 also stops the distro itself.** On 2026-10-05, with
`vmIdleTimeout=7200000` in place, a build died 45 seconds in: the journal shows
`systemd-logind: The system will power off now!` about 20 seconds after the
last `wsl.exe` client exited, while the VM stayed up (`uptime` unchanged). The
distro instance has an idle timeout of its own. Keep a client open for the
whole build — `wsl -e bash -c 'exec sleep infinity'` in a terminal that stays
open — or set `instanceIdleTimeout=-1` under `[general]` in `.wslconfig`.

**A build run as root misses every cache.** `systemd-run` without `--uid` runs
the build as root, while the clones under `Arkbuild/home/ark/` belong to uid
1000. git then refuses them (`fatal: detected dubious ownership`), `git rev-parse
HEAD` prints nothing, every cache key built from it is wrong, and each emulator
is compiled from source under qemu — Dolphin alone takes about three hours
(TODO.md, 2026-10-24). The build does
not stop or warn; the only trace is that line in the log. Allow the build tree
for root before starting:

    sudo git config --system --add safe.directory '*'

It is read on every git call, so adding it fixes a build that is already
running from its next component on. A key already written empty (it is one
byte long) has to be corrected by hand, or the next build misses that cache too.

Neither of those helps against the host rebooting for updates, which is what
ended the fourth attempt. That one is only survivable by being able to resume:
keep the image and rootfs files, re-attach and re-mount them, and restart from
the step after the kernel. Verify the content rather than the mounts before
continuing — a mounted filesystem proves nothing about what is in it.

**Silent losses.** Most `build_<emu>sa.sh` scripts have no `verify_action`: a
component that fails to patch or clone prints one line among tens of thousands
and the build moves on, leaving an empty `/opt/<name>` behind. `make rg52mini`
now ends with an audit (`scripts/audit-components.sh`) that lists directories
with no ELF in them, every step that gave up, and every package that would not
install. Read it.

**A defconfig is a request, not a result.** Appending `CONFIG_FOO=y` to
`rg52mini_defconfig` does nothing at all if `FOO`'s dependencies are unmet —
kconfig drops it without a word. That is how `CONFIG_LOGO` stayed out of three
images. The reverse bites too: turning something *off* can take an unrelated
option with it, because the thing you disabled was the only one `select`ing it.
`CONFIG_BLK_DEV_IO_TRACE` was the only selector of `CONFIG_DEBUG_FS` in this
tree, and `scripts/rk3562/ledctl.sh` drives the power LED through
`/sys/kernel/debug/regulator/vcc-led/enable`, so switching off blktrace would
have quietly taken out the LED.

Resolve the defconfig and diff it, every time. It can be done without touching
the working tree — useful while a build is running, since `make <unit>_defconfig`
would overwrite the `.config` the build is using, and `make O=<dir>` refuses
outright once the tree has object files in it:

    cd kernel_rk3562
    export ARCH=arm64 SRCARCH=arm64 srctree=. objtree=. \
           CROSS_COMPILE=aarch64-linux-gnu- CC=aarch64-linux-gnu-gcc \
           HOSTCC=gcc KERNELVERSION=$(make -s kernelversion)
    export PATH=$PWD/../prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin:$PATH
    export CC_VERSION_TEXT="$(aarch64-linux-gnu-gcc --version | head -n1)"
    KCONFIG_CONFIG=/tmp/newcfg scripts/kconfig/conf \
        --defconfig=arch/arm64/configs/rg52mini_defconfig Kconfig
    diff <(grep ^CONFIG_ .config | sort) <(grep ^CONFIG_ /tmp/newcfg | sort)

`scripts/kconfig/conf` is already built after any kernel build, and
`KCONFIG_CONFIG` sends the output somewhere harmless. Export `CC_VERSION_TEXT`
or every compiler probe fails: you get `CONFIG_GCC_VERSION=0`, `GCC_PLUGINS`
disappears and `KASAN` appears, and the diff fills with noise that has nothing
to do with your change. Read the whole diff, not just the symbols you edited.
