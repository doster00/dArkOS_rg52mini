#!/bin/bash
# 1.3: EMULATOR SETTINGS offers a VULKAN DRIVER choice (libvulkan_darkos.so, vk-driver-select/) for
# the systems /etc/darkos/vulkan.conf names on its es_systems line. A device that has the file
# without that line (the user's own copy, kept by the update with the image's beside it as
# vulkan.conf.ota-new, or one from a test build) gets the image's line added; its other lines stay.
#
# Never fails the update. Changed files go to merged for a rollback.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
F=/etc/darkos/vulkan.conf
[ -f "$F" ] || exit 0
grep -q '^[[:space:]]*es_systems[[:space:]]*=' "$F" && exit 0
LINE=$(grep -h '^[[:space:]]*es_systems[[:space:]]*=' "$F.ota-new" 2>/dev/null | tail -1)
[ -n "$LINE" ] || LINE="es_systems = 3ds, n3ds, ps2, ppsspp, pspminis, Gamecube, psx, dreamcast, naomi, Sega Atomiswave, ports"
printf '\n%s\n' "$LINE" >> "$F" || exit 0
echo "$F" >> /var/lib/darkos-ota/merged
echo "  $F: es_systems added"
exit 0
