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
es=$(pgrep -f '^/usr/bin/emulationstation/emulationstation' | head -1)
# EmulationStation stays alive while a game runs (it starts the game as a child
# and waits for it), and restarting the service would kill the game. So with a
# game running leave drmConn alone, wait for the game to end, then run again:
# the cable state is checked afresh and the switch happens then.
if [ -n "$es" ] && pgrep -P "$es" > /dev/null; then
  logger -t hdmi-hotplug "HDMI $st during a game: EmulationStation not restarted, will switch when the game ends"
  flock -u 9
  while pgrep -P "$es" > /dev/null; do sleep 3; done
  sleep 3
  exec /usr/local/bin/hdmi-hotplug.sh
fi
echo "$want" > /var/run/drmConn
logger -t hdmi-hotplug "HDMI $st: drmConn $cur -> $want"
[ -n "$es" ] && systemctl restart emulationstation
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
