#!/bin/bash

directory=$(dirname "$1" | cut -d "/" -f2)

for d in GC StateSaves ScreenShots Wii; do
  if [[ -d "/home/ark/.local/share/dolphin-emu/${d}" && ! -L "/home/ark/.local/share/dolphin-emu/${d}" ]]; then
    rm -rf /home/ark/.local/share/dolphin-emu/${d}
  fi
  if [[ ! -d "/$directory/gc/$d" ]]; then
    mkdir /$directory/gc/${d}
  fi
  ln -sf /$directory/gc/${d} /home/ark/.local/share/dolphin-emu/
done

export DOLPHIN_EMU_USERPATH="${HOME}/.local/share/dolphin-emu/"

# Dolphin 2609a turned on AccurateFmadds (extra float operations in the JIT) and
# PrecisionFrameTiming (a millisecond of spinning in every throttle sleep); 1.3's Dolphin
# had neither. Both off here, as before: the ND Demo ran 1.5% faster without them
# (docs/TODO.md). Dolphin writes its ini back on exit, so an update leaves the user's;
# one without the keys gets them once, and the flag keeps a value set by hand afterwards.
ini="${DOLPHIN_EMU_USERPATH}Config/Dolphin.ini"
flag="${DOLPHIN_EMU_USERPATH}Config/.core-2609a-off"
if [ ! -e "$flag" ] && [ -f "$ini" ]; then
  for k in AccurateFmadds PrecisionFrameTiming; do
    if ! sed -n '/^\[Core\]$/,/^\[/p' "$ini" | grep -q "^$k"; then
      sed -i "/^\[Core\]$/a $k = False" "$ini"
    fi
  done
  touch "$flag"
fi

/opt/dolphin/dolphin-emu-nogui -p drm -a HLE -e "${1}"

