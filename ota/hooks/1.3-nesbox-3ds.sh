#!/bin/bash
# 1.3 brings the Nintendo 3DS (Azahar). nes-box, the default theme, has no 3ds
# folder, and the installed copy of the theme lives on the ROMs partition,
# which the package does not touch: put ours there if the theme is installed
# and has none. A folder the user made is left alone.
#
# Never fails the update. The new folder is not listed in merged: a rollback
# leaves it, and the old ES simply has no 3ds system to use it.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
SRC=/usr/share/darkos/themes/es-theme-nes-box/3ds
for T in /roms/themes/es-theme-nes-box /roms2/themes/es-theme-nes-box; do
  [ -d "$SRC" ] && [ -f "$T/theme.xml" ] && [ ! -e "$T/3ds" ] || continue
  cp -r "$SRC" "$T/3ds" && chown -R --reference="$T" "$T/3ds" 2>/dev/null
  echo "  nes-box: $T/3ds added"
done
# and the ROM folder a new image has (a dual-boot card also reads GammaOS's n3ds)
if [ -d /roms/nds ] && [ ! -e /roms/3ds ]; then
  mkdir /roms/3ds && chown --reference=/roms/nds /roms/3ds 2>/dev/null
  echo "  /roms/3ds added"
fi
exit 0
