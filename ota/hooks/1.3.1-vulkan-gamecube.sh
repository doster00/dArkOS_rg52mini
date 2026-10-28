#!/bin/bash
# 1.3.1: Gamecube offers the VULKAN DRIVER choice too (Dolphin starts on malisx2 since malisx2
# 80994d9 and dolphinsa-patch-014). A device whose /etc/darkos/vulkan.conf is the user's own copy
# (kept by the update, the image's beside it as vulkan.conf.ota-new) and has an es_systems line
# without Gamecube gets it added to that line; the rest of the file stays. An untouched file is
# the image's already, and a copy without the line gets the image's whole line from the 1.3 hook.
#
# Never fails the update. Changed files go to merged for a rollback.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
F=/etc/darkos/vulkan.conf
[ -f "$F" ] || exit 0
grep -q '^[[:space:]]*es_systems[[:space:]]*=' "$F" || exit 0
grep '^[[:space:]]*es_systems[[:space:]]*=' "$F" | tail -1 | tr ',=' '\n\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | \
  grep -qx 'Gamecube' && exit 0
sed -i '/^[[:space:]]*es_systems[[:space:]]*=/ s/[[:space:]]*$/, Gamecube/' "$F" || exit 0
echo "$F" >> /var/lib/darkos-ota/merged
echo "  $F: Gamecube added to es_systems"
exit 0
