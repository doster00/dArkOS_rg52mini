#!/bin/bash
# Re-route EmulationStation between the internal panel and HDMI on hotplug.
# hdmi-test.sh decides this only once at boot, so a cable plugged in later did
# nothing and unplugging left the console pointing at a dead HDMI output.
# Triggered by 99-hdmi-hotplug.rules on every DRM connector change.
exec 9>/run/hdmi-hotplug.lock
flock -w 30 9 || exit 0          # events are handled one at a time
sleep 2                          # let the bridge/EDID settle
st=$(cat /sys/class/drm/card0-HDMI-A-1/status 2>/dev/null)
want=0; [ "$st" = connected ] && want=1
cur=$(cat /var/run/drmConn 2>/dev/null || echo 0)
[ "$want" = "$cur" ] && exit 0
echo "$want" > /var/run/drmConn
logger -t hdmi-hotplug "HDMI $st: drmConn $cur -> $want"
# Only restart the frontend when it is what is on screen; during a game just
# remember the choice for the next frontend start.
if pgrep -f '^/usr/bin/emulationstation/emulationstation' > /dev/null; then
  systemctl restart emulationstation
fi
# Back on the internal screen: switching the panel off for HDMI also left the
# backlight at 0, so restore the last brightness (kept in /run/darkos-brightness).
if [ "$want" = 0 ]; then
  sleep 3
  bl=/sys/class/backlight/backlight
  if [ "$(cat $bl/brightness 2>/dev/null || echo 0)" -lt 2 ]; then
    saved=$(cat /run/darkos-brightness 2>/dev/null || echo 60)
    [ "$saved" -ge 2 ] 2>/dev/null || saved=60
    echo "$saved" > $bl/brightness
    logger -t hdmi-hotplug "backlight was 0, restored to $saved"
  fi
fi
