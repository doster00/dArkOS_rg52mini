#!/bin/bash

# Write rootfs to disk
# the chroot's git wrapper (utils.sh) is the build's, not the image's
sudo rm -rf Arkbuild/root/.darkos-git
sync Arkbuild
if [ "${ROOT_FILESYSTEM_FORMAT}" == "xfs" ]; then
  mkdir Arkbuild-final
  sudo mount -o loop ${LOOP_DEV}p4 Arkbuild-final/
  sudo rsync -aHAXv --exclude={'home/ark/Arkbuild_ccache','proc','dev','sys'} Arkbuild/ Arkbuild-final/
  sudo umount Arkbuild-final/
  sudo rm -rf Arkbuild-final/
elif [[ "${ROOT_FILESYSTEM_FORMAT}" == *"ext"* ]]; then
  e2fsck -p -f ${FILESYSTEM}
  resize2fs -M ${FILESYSTEM}
  sudo dd if="${FILESYSTEM}" of="${LOOP_DEV}p4" bs=512 conv=fsync,notrunc
elif [ "${ROOT_FILESYSTEM_FORMAT}" == "btrfs" ]; then
  sudo btrfs balance start --full-balance Arkbuild
  sync Arkbuild
  sudo btrfs filesystem resize 7300M Arkbuild/
  verify_action
  sync Arkbuild
  sudo truncate -s 7650MB ${FILESYSTEM}
  sync Arkbuild
  sudo dd if="${FILESYSTEM}" of="${LOOP_DEV}p4" bs=512 conv=fsync,notrunc
fi
sync ${DISK}