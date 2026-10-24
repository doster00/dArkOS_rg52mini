#!/bin/bash

directory="$(dirname "$1" | cut -d "/" -f2)"

for d in backup cheats savestates slot2; do
  if [[ ! -d "/${directory}/nds/$d" ]]; then
    mkdir /${directory}/nds/${d}
  fi
  if [[ -d "/opt/drastic/$d" && ! -L "/opt/drastic/$d" ]]; then
    cp -n /opt/drastic/${d}/* /${directory}/nds/${d}/
    rm -rf /opt/drastic/${d}/
  fi
  ln -sf /${directory}/nds/${d} /opt/drastic/
done

echo "VAR=drastic" > /home/ark/.config/KILLIT
sudo systemctl restart killer_daemon.service

cd /opt/drastic
# RG52 Mini: the menu on Home+X instead of L3 (drastic/hotkey)
if [[ -f /opt/drastic/drastic-hotkey.so ]]; then
  LD_PRELOAD=/opt/drastic/drastic-hotkey.so ./drastic "$1"
else
  ./drastic "$1"
fi

sudo systemctl stop killer_daemon.service

sudo systemctl restart ogage &
