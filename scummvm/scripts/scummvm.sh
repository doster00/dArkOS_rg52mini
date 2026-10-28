#!/bin/bash

#
# This fix should allow ScummVM games to launch from a root .scummvm file and not from a subfolder
#
# This now makes the requirement that the .scummvm file has the same name as the folder the game is stored in
# and this will work without the subfolders.  This also works if the .scummvm file is within the folder
#
# Thanks to EnsignRutherford for this fix. (https://github.com/christianhaitian/arkos/issues/858)
#
fbname=$(basename "$2" .scummvm)
fbdir=$(dirname "$2")
if [ -d "$fbdir/$fbname" ]; then
   game=$(dirname "$2")/"$fbname"/"$(basename "$2")"
   set -- "$1" "$game" "$3"
fi

directory="$(dirname "$2" | cut -d "/" -f2)"

# MIDI goes through FluidSynth (gm_device and mt32_device), whose soundfont the config names.
# Up to 1.3.1 that was RetroArch's scummvm extra/Roland_SC-55.sf2, which this image does not
# have (and ScummVM was built without FluidSynth): a config naming a soundfont that is not
# there gets the General MIDI one Debian's fluidsynth brings.
cfg=/home/ark/.config/scummvm/scummvm.ini
sf=$(sed -n 's/^soundfont=//p' "$cfg" 2>/dev/null | head -1)
if [ -n "$sf" ] && [ ! -f "$sf" ] && [ -f /usr/share/sounds/sf2/FluidR3_GM.sf2 ]; then
  sed -i 's#^soundfont=.*#soundfont=/usr/share/sounds/sf2/FluidR3_GM.sf2#' "$cfg"
fi

if [[ $2 == *"Scan_for_new_games.scummvm"* ]]
then
  printf "\033c" >> /dev/tty1
  cd /${directory}/scummvm
  ./Scan_for_new_games.scummvm standalone "$2"
  printf "\n\nFinished scanning the scummvm folder for games." >> /dev/tty1
  printf "\nPlease do an update games lists or restart emulationstaton" >> /dev/tty1
  printf "\nto find the new shortcuts created if any.\n" >> /dev/tty1
  sleep 5
  printf "\033c" >> /dev/tty1
elif [[ $1 == "standalone" ]] && [[ ${2,,} != *"menu.scummvm"* ]]
then
  cd /opt/scummvm
  echo "VAR=scummvm" > /home/ark/.config/KILLIT
  sudo systemctl restart killer_daemon.service
  DIR="$( cd "$( dirname "${2}" )" >/dev/null 2>&1 && pwd )/"
  ./scummvm --auto-detect --path="$DIR"
  sudo systemctl stop killer_daemon.service
  sudo systemctl restart ogage &
elif [[ $1 == "standalone" ]] && [[ ${2,,} == *"menu.scummvm"* ]]
then
  cd /opt/scummvm
  echo "VAR=scummvm" > /home/ark/.config/KILLIT
  sudo systemctl restart killer_daemon.service
  ./scummvm
  sudo systemctl stop killer_daemon.service
  sudo systemctl restart ogage &
else
  if  [[ ${3,,} == *"menu.scummvm"* ]]
  then
      /usr/local/bin/"$1" -L /home/ark/.config/"$1"/cores/"$2"_libretro.so
  else
      /usr/local/bin/"$1" -L /home/ark/.config/"$1"/cores/"$2"_libretro.so "$3"
  fi
fi


