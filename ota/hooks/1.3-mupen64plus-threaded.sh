#!/bin/bash
# 1.3 runs GLideN64 in mupen64plus_next on its own thread
# (mupen64plus-ThreadedRenderer): 54 -> 57 fps in AeroGauge, 52-53 -> 56-57 in
# Zelda's title sequence. The image's retroarch-core-options.cfg has the key;
# a device whose file the user has changed keeps that file, so add the key
# there unless the user has set it either way. The .bak is what Options ->
# Advanced -> Reset Retroarch Core Settings restores.
#
# Never fails the update. Changed files go to merged for a rollback.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
for F in /home/ark/.config/retroarch/retroarch-core-options.cfg \
         /home/ark/.config/retroarch/retroarch-core-options.cfg.bak; do
  [ -f "$F" ] || continue
  grep -q '^mupen64plus-ThreadedRenderer ' "$F" && continue
  echo 'mupen64plus-ThreadedRenderer = "True"' >> "$F" || continue
  echo "$F" >> /var/lib/darkos-ota/merged
  echo "  $F: mupen64plus-ThreadedRenderer added"
done
exit 0
