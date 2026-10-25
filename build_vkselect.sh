#!/bin/bash

# Build and install libvulkan_darkos.so (vk-driver-select/), the Vulkan driver the loader sees:
# it loads Arm's (libmali) or malisx2 for each program, as /etc/darkos/vulkan.conf or
# DARKOS_VULKAN in its environment says, and hands the loader that driver's entry points. Both
# cannot be drivers of one process: the second gets no display (DRM master). rk_vk.json, the
# only driver manifest the image keeps, is pointed at it by finishing_touches-rk3562.sh, which
# installs it. See docs/KNOWN-ISSUES.md.
sudo rm -rf Arkbuild/tmp/vk-driver-select
sudo cp -r vk-driver-select Arkbuild/tmp/
call_chroot "cd /tmp/vk-driver-select && sh build.sh"
if [ -f Arkbuild/tmp/vk-driver-select/libvulkan_darkos.so ]; then
  sudo install -m 644 Arkbuild/tmp/vk-driver-select/libvulkan_darkos.so Arkbuild/usr/lib/aarch64-linux-gnu/
  sudo mkdir -p Arkbuild/etc/darkos
  sudo install -m 644 vk-driver-select/vulkan.conf Arkbuild/etc/darkos/vulkan.conf
else
  echo "WARNING: libvulkan_darkos.so did not build; Vulkan stays on libmali only."
fi
sudo rm -rf Arkbuild/tmp/vk-driver-select
