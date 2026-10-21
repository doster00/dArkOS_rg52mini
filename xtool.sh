#!/bin/bash
#
# Compilers that run natively in the arm64 chroot (docs/BUILDING.md).
#
# The chroot runs under qemu, so every compiler process in it is emulated:
# Azahar's core took 573 minutes there. clang is a cross compiler by nature,
# and Debian builds the same clang for amd64. setup_xtool keeps an amd64
# Debian tree with that build of the chroot's clang, and mount_xtool puts it
# into the chroot, where the host's CPU runs it as it is (only arm64 programs
# go through qemu). It compiles there against the chroot's own headers,
# libraries and paths, as the chroot's clang would: the same version, the
# same target, the same GCC installation for libstdc++, and the same source
# paths, which a profile names functions by.
#
# A recipe installs clang in the chroot, calls setup_xtool, and between
# mount_xtool and umount_xtool builds with ${XTOOL_LLVM}/bin/aarch64-linux-gnu-
# clang(++); if setup_xtool fails it keeps the chroot's clang, under qemu.

XTOOL="Arkbuild_package_cache/xtool-${DEBIAN_CODE_NAME}-amd64"
# where the chroot sees the amd64 clang: its bin, lib and resource headers
XTOOL_LLVM=/usr/lib/llvm-19-amd64

function setup_xtool() {
  local want have rc
  want=$(sudo chroot Arkbuild dpkg-query -W -f='${source:Version}' clang-19 2>/dev/null)
  if [ -z "$want" ]; then
    echo "xtool: the chroot has no clang-19; the build stays under qemu"
    return 1
  fi
  if [ -e Arkbuild/lib64 ] && [ ! -L Arkbuild/lib64 ]; then
    echo "xtool: the chroot has a /lib64 of its own; the build stays under qemu"
    return 1
  fi
  if [ ! -x "$XTOOL/usr/bin/apt-get" ]; then
    sudo rm -rf "$XTOOL"
    if ! sudo debootstrap --variant=minbase --no-check-gpg --arch=amd64 \
         "${DEBIAN_CODE_NAME}" "$XTOOL" "${DEBIAN_LOCATION:-http://deb.debian.org/debian/}"; then
      echo "xtool: debootstrap failed; the build stays under qemu"
      sudo rm -rf "$XTOOL"
      return 1
    fi
  fi
  # The chroot's own sources, so apt picks the same clang
  sudo cp /etc/resolv.conf "$XTOOL/etc/resolv.conf"
  sudo cp Arkbuild/etc/apt/sources.list "$XTOOL/etc/apt/sources.list" 2>/dev/null
  sudo rm -rf "$XTOOL/etc/apt/sources.list.d"
  sudo cp -a Arkbuild/etc/apt/sources.list.d "$XTOOL/etc/apt/" 2>/dev/null
  sudo unshare -m sh -c "mount -t proc proc '$XTOOL/proc' && chroot '$XTOOL' apt-get -q update && \
    chroot '$XTOOL' env DEBIAN_FRONTEND=noninteractive apt-get -y -q --no-install-recommends \
      install clang-19 lld-19 llvm-19 libeatmydata1" >/dev/null
  have=$(sudo chroot "$XTOOL" dpkg-query -W -f='${source:Version}' clang-19 2>/dev/null)
  if [ "$have" != "$want" ]; then
    echo "xtool: amd64 clang-19 '$have', the chroot's '$want'; the build stays under qemu"
    return 1
  fi
  # clang takes its target from the name it is run by
  sudo ln -sfn clang "$XTOOL/usr/lib/llvm-19/bin/aarch64-linux-gnu-clang"
  sudo ln -sfn clang++ "$XTOOL/usr/lib/llvm-19/bin/aarch64-linux-gnu-clang++"
  # Smoke test: a program the amd64 clang links in the chroot runs there
  mount_xtool
  echo 'int main(void) { return 0; }' | sudo tee Arkbuild/tmp/xtool-test.c >/dev/null
  sudo chroot Arkbuild ${XTOOL_LLVM}/bin/aarch64-linux-gnu-clang -O2 -o /tmp/xtool-test /tmp/xtool-test.c && \
    sudo chroot Arkbuild /tmp/xtool-test
  rc=$?
  umount_xtool
  sudo rm -f Arkbuild/tmp/xtool-test.c Arkbuild/tmp/xtool-test
  if [ $rc != 0 ]; then
    # made again by the next build
    sudo rm -rf "$XTOOL"
    echo "xtool: the amd64 clang does not build in the chroot; the build stays under qemu"
    return 1
  fi
  echo "xtool: clang-19 ${want} for amd64 builds in the chroot"
}

# The x86-64 loader (/lib64, which arm64 Debian has not got), the amd64
# libraries and the amd64 LLVM, each where an amd64 system has it, read-only
# (remove_arkbuild's rm -rf must not reach the cache through them). Nothing
# arm64 looks in those places; umount_xtool takes them out of the tree again.
function mount_xtool() {
  local d
  umount_xtool
  sudo ln -s usr/lib/x86_64-linux-gnu Arkbuild/lib64
  sudo mkdir -p Arkbuild/usr/lib/x86_64-linux-gnu Arkbuild${XTOOL_LLVM}
  sudo mount --bind "$XTOOL/usr/lib/x86_64-linux-gnu" Arkbuild/usr/lib/x86_64-linux-gnu
  sudo mount --bind "$XTOOL/usr/lib/llvm-19" Arkbuild${XTOOL_LLVM}
  for d in /usr/lib/x86_64-linux-gnu ${XTOOL_LLVM}; do
    sudo mount -o remount,bind,ro Arkbuild$d
  done
}

function umount_xtool() {
  local d
  for d in ${XTOOL_LLVM} /usr/lib/x86_64-linux-gnu; do
    if mountpoint -q Arkbuild$d; then
      sudo umount Arkbuild$d
    fi
    if [ -d Arkbuild$d ]; then
      sudo rmdir Arkbuild$d 2>/dev/null
    fi
  done
  if [ -L Arkbuild/lib64 ]; then
    sudo rm -f Arkbuild/lib64
  fi
}
