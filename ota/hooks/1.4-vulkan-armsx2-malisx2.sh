#!/bin/bash
# 1.4: ARMSX2 takes malisx2 by default ("armsx2-sdl = malisx2" in /etc/darkos/vulkan.conf).
# A device whose vulkan.conf is the user's own copy (kept by the update, the image's beside it
# as vulkan.conf.ota-new) and names no driver for armsx2-sdl gets the line after its default
# line; a user who chose a driver for it keeps that. An untouched file is the image's already.
#
# Never fails the update. Changed files go to merged for a rollback.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
F=/etc/darkos/vulkan.conf
[ -f "$F" ] || exit 0
grep -q '^[[:space:]]*armsx2-sdl[[:space:]]*=' "$F" && exit 0
if grep -q '^[[:space:]]*default[[:space:]]*=' "$F"; then
  sed -i '0,/^[[:space:]]*default[[:space:]]*=.*$/s//&\narmsx2-sdl = malisx2/' "$F" || exit 0
else
  echo 'armsx2-sdl = malisx2' >> "$F" || exit 0
fi
echo "$F" >> /var/lib/darkos-ota/merged
echo "  $F: armsx2-sdl = malisx2 added"
exit 0
