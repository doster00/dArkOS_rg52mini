#!/bin/bash
# darkos-poweroff <ES pid>: power off once ES has been told to, whatever ES
# does after. ES's shutdown event (Emulationstation/scripts.rk3562/shutdown/
# poweroff.sh) starts it on "yes" to "really shutdown?". ES asks for the
# power-off itself only once it is through with its exit, and a report
# (revision A, 1.2) has the screen go dark now and then, with ES back on the
# next press and the device still on: ES never got that far. This waits for
# ES to end, up to a minute while it saves its data, then asks for the
# power-off every second until it happens.
es=$1
for i in $(seq 1 60); do
  kill -0 "$es" 2> /dev/null || break
  sleep 1
done
n=0
while true; do
  n=$(( n + 1 ))
  logger -t darkos-poweroff "attempt $n"
  shutdown -h now
  sleep 1
done
