#!/bin/bash
# Register qemu-user-static binfmt handlers under WSL.
# Ubuntu masks systemd-binfmt.service with ConditionVirtualization=!wsl,
# so nothing registers the qemu interpreters and every aarch64 chroot fails
# with "Exec format error".  Registering them by hand (flag F, so the
# interpreter stays reachable from inside a chroot) fixes that, and unlike
# `systemctl restart systemd-binfmt` it leaves the WSLInterop entry alone.

BFM=/proc/sys/fs/binfmt_misc

[ -w "${BFM}/register" ] || exit 0

reg() {
  local name="$1" magic="$2" mask="$3" interp="$4"
  [ -x "${interp}" ] || return 0
  [ -e "${BFM}/${name}" ] && return 0
  printf ':%s:M::%s:%s:%s:OCF\n' "${name}" "${magic}" "${mask}" "${interp}" > "${BFM}/register"
}

MASK='\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'

# aarch64: our own build when it is there (~/rg52/qemu-work: QEMU 8.2.10, -O3 -march=native, LTO,
# default CPU cortex-a53 instead of "max"). max emulates pointer authentication with QARMA5,
# which Debian's arm64 binaries run in every function: with cortex-a53 dpkg, apt and perl run
# 13x faster, gcc 1.7x (dArkOS docs/BUILDING.md). QEMU_CPU still overrides it.
AARCH64=/usr/bin/qemu-aarch64-static
[ -x /usr/local/bin/qemu-aarch64-darkos ] && AARCH64=/usr/local/bin/qemu-aarch64-darkos

reg qemu-aarch64 \
  '\x7f\x45\x4c\x46\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00' \
  "${MASK}" "${AARCH64}"

reg qemu-arm \
  '\x7f\x45\x4c\x46\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00' \
  "${MASK}" /usr/bin/qemu-arm-static

exit 0
