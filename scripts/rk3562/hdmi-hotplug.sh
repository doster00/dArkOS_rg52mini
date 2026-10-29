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
# The Ports launchers run their game in a systemd unit of its own (NAME-port-UID),
# outside EmulationStation, so restarting it does not end that game. It would go
# on drawing to the output that just changed and keep the display lock, and the
# next launch would close at once. End those games together with the frontend.
units=$(systemctl list-units --type=service --state=running --plain --no-legend '*-port-*.service' 2>/dev/null | awk '{print $1}')
if [ -n "$units" ]; then
  logger -t hdmi-hotplug "ending games started from Ports: $(echo $units)"
  timeout 20 systemctl stop $units
fi
# The frontend stays alive while a game runs (the game is its child), so
# restarting it ends a game started from a system too.
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
