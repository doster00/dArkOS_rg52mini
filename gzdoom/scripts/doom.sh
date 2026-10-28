#!/bin/bash

# RG52 Mini, RG43H (rk3562-joystick): up to 1.3.1 the GZDoom and LZDoom inis had the rk3566
# pad's layout, on which L2 (an axis at one end when let go) turned the player all the time
# and D-pad up opened the menu. doompad.py moves an ini still on that layout to this pad's,
# once; a layout the user made is left as it is.
if [ -e /dev/input/by-path/platform-play_joystick-event-joystick ] && [ ! -e /home/ark/.config/.doompad-rk3562 ]; then
  python3 /usr/local/bin/doompad.py /home/ark/.config/gzdoom/gzdoom.ini /home/ark/.config/lzdoom/lzdoom.ini
  touch /home/ark/.config/.doompad-rk3562
fi

if [[ $1 == "standalone" ]]; then
    directory=$(dirname "$2" | cut -d "/" -f2)
    echo "VAR=lzdoom" > /home/ark/.config/KILLIT
    sudo systemctl restart killer_daemon.service
	if [ ".$(echo "$2"| cut -d. -f2)" == ".sh" ] || [ ".$(echo "$2"| cut -d. -f2)" == ".SH" ]; then
	dos2unix "${2}"
        "$2"
	elif [ ".$(echo "$2"| cut -d. -f2)" == ".doom" ] || [ ".$(echo "$2"| cut -d. -f2)" == ".DOOM" ]; then
	  IWAD=""; MODS=""; DEH=""; SAVE=""; CONF=""; PARAMS=""; DOOM_BASE_DIR="/$directory/doom/"
	  dos2unix "${2}"
	  while IFS== read -r key value; do
	    if [ "$key" == "IWAD" ]; then IWAD+=" ${DOOM_BASE_DIR}${value}"
	    elif [ "$key" == "MOD" ]; then MODS+=" ${DOOM_BASE_DIR}${value}"
	    elif [ "$key" == "CONF" ]; then CONF+=" ${DOOM_BASE_DIR}${value}"
	    elif [ "$key" == "SAVE" ]; then SAVE+=" ${DOOM_BASE_DIR}${value}"
	    elif [ "$key" == "DEH" ]; then DEH+=" ${DOOM_BASE_DIR}${value}"
	    fi
	  done < "${2}"
	  if [ "$IWAD" ]; then PARAMS+=" -iwad ${IWAD:1}"; fi
	  if [ "$MODS" ]; then PARAMS+=" -file ${MODS:1}"; fi
	  if [ "$SAVE" ]; then PARAMS+=" -savedir ${SAVE:1}"; fi
	  if [ "$CONF" ]; then PARAMS+=" -config ${CONF:1}"; fi
	  if [ "$DEH" ]; then PARAMS+=" -deh ${DEH:1}"; fi
	  /opt/lzdoom/lzdoom ${PARAMS:1}
	else
	/opt/lzdoom/lzdoom -iwad "$2"
	fi
    sudo systemctl stop killer_daemon.service
    sudo systemctl restart ogage &
elif [[ $1 == "standalone-gzdoom" ]]; then
        directory=$(dirname "$2" | cut -d "/" -f2)
        echo "VAR=gzdoom" > /home/ark/.config/KILLIT
        sudo systemctl restart killer_daemon.service
        if [ ".$(echo "$2"| cut -d. -f2)" == ".sh" ] || [ ".$(echo "$2"| cut -d. -f2)" == ".SH" ]; then
        dos2unix "${2}"
        "$2"
        elif [ ".$(echo "$2"| cut -d. -f2)" == ".doom" ] || [ ".$(echo "$2"| cut -d. -f2)" == ".DOOM" ]; then
          IWAD=""; MODS=""; DEH=""; SAVE=""; CONF=""; PARAMS=""; DOOM_BASE_DIR="/$directory/doom/"
          dos2unix "${2}"
          while IFS== read -r key value; do
            if [ "$key" == "IWAD" ]; then IWAD+=" ${DOOM_BASE_DIR}${value}"
            elif [ "$key" == "MOD" ]; then MODS+=" ${DOOM_BASE_DIR}${value}"
            elif [ "$key" == "CONF" ]; then CONF+=" ${DOOM_BASE_DIR}${value}"
            elif [ "$key" == "SAVE" ]; then SAVE+=" ${DOOM_BASE_DIR}${value}"
            elif [ "$key" == "DEH" ]; then DEH+=" ${DOOM_BASE_DIR}${value}"
            fi
          done < "${2}"
          if [ "$IWAD" ]; then PARAMS+=" -iwad ${IWAD:1}"; fi
          if [ "$MODS" ]; then PARAMS+=" -file ${MODS:1}"; fi
          if [ "$SAVE" ]; then PARAMS+=" -savedir ${SAVE:1}"; fi
          if [ "$CONF" ]; then PARAMS+=" -config ${CONF:1}"; fi
          if [ "$DEH" ]; then PARAMS+=" -deh ${DEH:1}"; fi
          /opt/gzdoom/gzdoom ${PARAMS:1} +gl_es 1 +vid_preferbackend 3 +cl_capfps 0
        else
        /opt/gzdoom/gzdoom -iwad "$2" +gl_es 1 +vid_preferbackend 3 +cl_capfps 0
        fi
        sudo systemctl stop killer_daemon.service
        sudo systemctl restart ogage &
else
  /usr/local/bin/"$1" -L /home/ark/.config/"$1"/cores/"$2"_libretro.so "$3"
fi

