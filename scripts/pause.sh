#!/bin/bash
# While a suspend is under way (the RK3562 sleep hook keeps "<phase> <ms>" in
# /run/darkos-sleep.phase), the power key means something else:
# - on the way down, from a second after the press that started it, it asks
#   the system to come back (the hook then sets the RTC alarm); within that
#   second it is the same press, so a bounce does not wake the device;
# - asleep, or in the first second after waking, it is the press that woke the
#   system (it arrives within a few hundred ms), not a new request;
# - later while waking it is a new press, but logind refuses a suspend until
#   the wake is through (about 3.5 s), so it is done then, not lost.
# Otherwise it does what it always did. The phase counts only while
# systemd-sleep runs, so one left by a hook that never finished is ignored.
# Not by its age: the clock runs on while asleep, and after a sleep of more
# than two minutes the press that woke the system was taken for a new one and
# put it back to sleep.
phase=/run/darkos-sleep.phase
again=/run/darkos-sleep.again
if [ -r $phase ] && read -r p t < $phase && pgrep -x systemd-sleep > /dev/null; then
  age=$(( $(date +%s%3N) - ${t:-0} ))
  case $p in
    pre)    [ $age -ge 1000 ] && sudo touch /run/darkos-sleep.wake; exit 0 ;;
    asleep) exit 0 ;;
    post)
      [ $age -lt 1000 ] && exit 0
      if [ ! -e $again ]; then
        sudo touch $again
        ( while pgrep -x systemd-sleep > /dev/null && [ $(( $(date +%s%3N) - t )) -lt 30000 ]; do sleep 0.2; done
          sudo rm -f $again
          "$0" ) > /dev/null 2>&1 &
      fi
      exit 0 ;;
  esac
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
