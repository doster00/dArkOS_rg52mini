#!/bin/bash
# The "black" screensaver turns the backlight off, and the device looked asleep
# though it was not: a press of the power key lit the screen and put the
# device to sleep a moment later. Now the screensaver does what that press
# would: pause.sh, as root and outside ES, as ogage runs it (in the power-off
# mode it stops ES). The other screensavers stay as they are. ES sets the
# backlight in the background, hence the wait.
( for i in $(seq 1 10); do
    if [ "$(cat /sys/class/backlight/backlight/brightness)" = 0 ]; then
      sudo systemd-run --quiet --collect /usr/local/bin/pause.sh
      break
    fi
    sleep 0.1
  done ) > /dev/null 2>&1 &
