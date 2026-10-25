#!/bin/bash
# tools/qemu-host/build.sh: the build host's aarch64 interpreter (WSL2, x86-64). QEMU 8.2.10 user
# mode, static, -O3 -march=native and LTO, with cortex-a53 - the RK3562's cores - as its default
# CPU instead of "max". max emulates pointer authentication with QARMA5, and Debian's arm64
# binaries (built with -mbranch-protection) run PAC instructions in every function; without
# them (cortex-a53 has none, they are NOPs there) dpkg, apt and perl run 13x faster and gcc 1.7x
# in the build chroot (docs/BUILDING.md). QEMU_CPU still overrides the default.
#
# Installs /usr/local/bin/qemu-aarch64-darkos; /usr/local/sbin/register-qemu-binfmt.sh (the WSL
# workaround, docs/BUILDING.md) registers it for aarch64 when it is there. -march=native: the
# binary runs only on the machine that built it (or one with the same CPU features).
set -e
V=8.2.10
W=${W:-$HOME/rg52/qemu-work}
mkdir -p "$W" && cd "$W"
[ -f qemu-$V.tar.xz ] || wget -q https://download.qemu.org/qemu-$V.tar.xz
[ -d qemu-$V ] || tar xf qemu-$V.tar.xz
cd qemu-$V
grep -q '"cortex-a53"' linux-user/aarch64/target_elf.h ||
  sed -i 's/^    return "any";$/    return "cortex-a53";   \/* dArkOS: no pointer authentication to emulate *\//' \
    linux-user/aarch64/target_elf.h
grep -q '"cortex-a53"' linux-user/aarch64/target_elf.h
mkdir -p build-o3lto && cd build-o3lto
../configure --static --target-list=aarch64-linux-user --disable-system --disable-tools \
  --disable-docs --disable-plugins --disable-werror --enable-lto --extra-cflags="-O3 -march=native"
ninja qemu-aarch64
sudo install -m 755 qemu-aarch64 /usr/local/bin/qemu-aarch64-darkos
# take the new binary now (the registration opens it once, flag F)
if [ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
  echo -1 | sudo tee /proc/sys/fs/binfmt_misc/qemu-aarch64 > /dev/null
fi
sudo /usr/local/sbin/register-qemu-binfmt.sh
grep interpreter /proc/sys/fs/binfmt_misc/qemu-aarch64
