#!/bin/bash
#
# Enable Bluetooth for RK3562 (RG52 Mini)
#
# The controller can come after this runs: revision B's AIC8800 registers hci0
# a few seconds into boot, and on revision A only a USB dongle has one. Wait a
# while for bluetoothd to see a controller, power it on if one came, and do not
# fail the unit when none does.

sudo systemctl start bluetooth
sudo systemctl start bluealsa 2>/dev/null
for i in $(seq 1 30); do
  bluetoothctl show >/dev/null 2>&1 && break
  sleep 0.5
done
bluetoothctl power on >/dev/null 2>&1
exit 0
