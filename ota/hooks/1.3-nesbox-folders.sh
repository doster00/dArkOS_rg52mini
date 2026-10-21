#!/bin/bash
# 1.3 brings the Nintendo 3DS (Azahar) and a logo for PlayStation 2, which ES
# showed by name. nes-box, the default theme, has no 3ds or ps2 folder, and the
# installed copy of the theme lives on the ROMs partition, which the package
# does not touch: put ours there if the theme is installed and has none. A
# folder the user made is left alone.
#
# Never fails the update. The new folders are not listed in merged: a rollback
# leaves them; the old ES shows ps2's too, and has no 3ds system to use 3ds's.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
for F in 3ds ps2; do
  SRC=/usr/share/darkos/themes/es-theme-nes-box/$F
  for T in /roms/themes/es-theme-nes-box /roms2/themes/es-theme-nes-box; do
    [ -d "$SRC" ] && [ -f "$T/theme.xml" ] && [ ! -e "$T/$F" ] || continue
    cp -r "$SRC" "$T/$F" && chown -R --reference="$T" "$T/$F" 2>/dev/null
    echo "  nes-box: $T/$F added"
  done
done
# and the ROM folder a new image has (a dual-boot card also reads GammaOS's n3ds)
if [ -d /roms/nds ] && [ ! -e /roms/3ds ]; then
  mkdir /roms/3ds && chown --reference=/roms/nds /roms/3ds 2>/dev/null
  echo "  /roms/3ds added"
fi
exit 0
