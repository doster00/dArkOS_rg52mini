#!/bin/bash
# ES fires this on "yes" to "really shutdown?", before it starts to quit.
# darkos-poweroff sees the power-off through should ES not get to it (see
# there); in a unit of its own, as a restart of ES stops what is left in the
# cgroup of emulationstation.service. One is enough: a second start of the
# unit fails.
sudo systemd-run --no-block --collect --unit=darkos-poweroff /usr/local/bin/darkos-poweroff "$(pidof -s emulationstation)" > /dev/null 2>&1
