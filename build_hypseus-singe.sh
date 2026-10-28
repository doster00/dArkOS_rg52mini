#!/bin/bash

# Build and install Hypseus-singe standalone emulator
# Cache key: the head of the sdl2 branch and a hash of our recipe and the
# patches it copies, as in build_fake08.sh. The branch stopped at v2.12.1,
# "the last sdl2 version", so with its head alone a change of ours never
# rebuilt.
HYPSEUS_KEY="$(curl -s https://api.github.com/repos/DirtBagXon/hypseus-singe/commits/sdl2 | jq -r '.sha')-$(cat ${CHIPSET}_core_builds/scripts/hypseus-singe.sh ${CHIPSET}_core_builds/patches/hypseussinge-patch* 2>/dev/null | sha1sum | cut -c1-12)"
if [ -f "Arkbuild_package_cache/${CHIPSET}/hypseus-singe.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/hypseus-singe.commit)" == "${HYPSEUS_KEY}" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/hypseus-singe.tar.gz
else
	call_chroot "source /root/.bashrc && cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh hypseus-singe
	  "
	verify_action
	sudo mkdir -p Arkbuild/opt/hypseus-singe
	sudo mkdir -p Arkbuild/opt/hypseus-singe/framefile
	sudo mkdir -p Arkbuild/opt/hypseus-singe/logs
	sudo mkdir -p Arkbuild/opt/hypseus-singe/ram
	sudo mkdir -p Arkbuild/opt/hypseus-singe/screenshots
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/hypseus-singe/fonts/ Arkbuild/opt/hypseus-singe/
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/hypseus-singe/midi/ Arkbuild/opt/hypseus-singe/
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/hypseus-singe/pics/ Arkbuild/opt/hypseus-singe/
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/hypseus-singe/sound/ Arkbuild/opt/hypseus-singe/
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/hypseus-singe/LICENSE Arkbuild/opt/hypseus-singe/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/hypseus-singe/build/hypseus Arkbuild/opt/hypseus-singe/hypseus-singe
	if [ -f "Arkbuild_package_cache/${CHIPSET}/hypseus-singe.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/hypseus-singe.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/hypseus-singe.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/hypseus-singe.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/hypseus-singe.tar.gz Arkbuild/opt/hypseus-singe/ 
	echo "${HYPSEUS_KEY}" > Arkbuild_package_cache/${CHIPSET}/hypseus-singe.commit
fi
sudo cp hypseus-singe/configs/hypinput_gamepad.ini.${UNIT} Arkbuild/opt/hypseus-singe/hypinput_gamepad.ini
sudo cp hypseus-singe/configs/gamecontrollerdb.txt Arkbuild/opt/hypseus-singe/gamecontrollerdb.txt
call_chroot "chown -R ark:ark /opt/"
sudo cp hypseus-singe/scripts/singe.sh Arkbuild/usr/local/bin/singe.sh
sudo cp hypseus-singe/scripts/daphne.sh Arkbuild/usr/local/bin/daphne.sh
sudo chmod 777 Arkbuild/opt/hypseus-singe/hypseus-singe
sudo chmod 777 Arkbuild/usr/local/bin/singe.sh
sudo chmod 777 Arkbuild/usr/local/bin/daphne.sh
