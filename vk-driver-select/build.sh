#!/bin/sh
# build.sh: build libvulkan_darkos.so (run on aarch64, or in an aarch64 chroot, or with CC set to a
# cross compiler). No Vulkan headers needed.
set -e
cd "$(dirname "$0")"
${CC:-gcc} -O2 -Wall -Wextra -fPIC -shared -fvisibility=hidden \
    -o libvulkan_darkos.so darkos_vk_select.c -ldl -lpthread
echo "built: $(ls -l libvulkan_darkos.so)"
