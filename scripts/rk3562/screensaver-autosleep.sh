#!/bin/bash
# screensaver-autosleep: put the device to sleep from ES's screensaver when it
# runs on battery. ES's sleep event (Emulationstation/scripts.rk3562/sleep/
# screensaver.sh) starts it when a screensaver comes on, and its wake event
# ends it. Once the screensaver has been on as long again as ES waited before
# starting it (ScreenSaverTime, so twice that time after the last input), all
# of it on battery, the device is suspended. On the charger the count starts
# over. A wake without input (the screensaver still on) counts from zero again.
run=/run/darkos-autosleep
step=10
es=$(pidof -s emulationstation) || exit 0
ms=$(sed -n 's/.*name="ScreenSaverTime" value="\([0-9]*\)".*/\1/p' /home/ark/.emulationstation/es_settings.cfg)
wait=$(( ${ms:-300000} / 1000 ))
[ "$wait" -gt 0 ] || exit 0
echo $$ | sudo tee $run > /dev/null
left=$wait
while sleep $step; do
  [ "$(cat $run 2> /dev/null)" = $$ ] && kill -0 $es 2> /dev/null || exit 0
  if [ "$(cat /sys/class/power_supply/battery/status 2> /dev/null)" != Discharging ]; then
    left=$wait
    continue
  fi
  left=$(( left - step ))
  [ $left -gt 0 ] && continue
  logger -t screensaver-autosleep "on battery for ${wait} s of screensaver: suspending"
  sudo systemctl suspend
  left=$wait
done
