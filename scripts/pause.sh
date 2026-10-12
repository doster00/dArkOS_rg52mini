#!/bin/bash
# While a suspend is under way (the RK3562 sleep hook keeps "<phase> <ms>" in
# /run/darkos-sleep.phase), the power key means something else:
# - on the way down, from a second after the press that started it, it asks
#   the system to come back (the hook then sets the RTC alarm); within that
#   second it is the same press, so a bounce does not wake the device;
# - asleep, or in the first three seconds after waking, it is the press that
#   woke the system, not a new request.
# Otherwise it does what it always did. A phase older than two minutes, from
# a hook that never finished, is ignored.
phase=/run/darkos-sleep.phase
if [ -r $phase ] && read -r p t < $phase; then
  age=$(( $(date +%s%3N) - ${t:-0} ))
  if [ $age -lt 120000 ]; then
    case $p in
      pre)    [ $age -ge 1000 ] && sudo touch /run/darkos-sleep.wake; exit 0 ;;
      asleep) exit 0 ;;
      post)   [ $age -lt 3000 ] && exit 0 ;;
    esac
  fi
fi
if [ ! -e "/home/ark/.config/.SWAPPOWERANDSUSPEND" ]; then
  sudo systemctl suspend
else
  printf "\033c" >> /dev/tty1
  sudo systemctl stop emulationstation
  printf "\033c" >> /dev/tty1
  if [ -e "/roms/shutdownimages/bye.gif" ]; then
    ffplay -x 1280 -y 720 -loglevel quiet /roms/shutdownimages/bye.gif &
    (sleep 2s; kill -9 $(pidof ffplay))
  fi
  printf "\n\n\n\n\n\n\n      PEACE!" >> /dev/tty1
  sudo systemctl poweroff
fi
