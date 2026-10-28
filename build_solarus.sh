#!/bin/bash

# Build and install solarus standalone emulator along with sdl2-compat
# Cache key as in build_scummvmsa.sh: our recipe's pin and a hash of it and its patches.
if [ "$CHIPSET" == "rk3562" ]; then
  SOLARUS_KEY="$(grep -oP '(?<=TAG=").*?(?=")' rk3562_core_builds/scripts/solarus.sh | head -1)-$(cat rk3562_core_builds/scripts/solarus.sh rk3562_core_builds/patches/solarus-patch* 2>/dev/null | sha1sum | cut -c1-12)"
else
  SOLARUS_KEY="$(curl -s https://raw.githubusercontent.com/christianhaitian/${CORE_BUILDS_CHIPSET}_core_builds/refs/heads/master/scripts/solarus.sh | grep -oP '(?<=TAG=").*?(?=")')"
fi
if [ -f "Arkbuild_package_cache/${CHIPSET}/solarus.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/solarus.commit)" == "${SOLARUS_KEY}" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/solarus.tar.gz
else
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh solarus
	  "
	verify_action
	sudo mkdir -p Arkbuild/opt/solarus
	sudo cp -R Arkbuild/home/ark/${CHIPSET}_core_builds/solarus64/* Arkbuild/opt/solarus/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/solarus.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/solarus.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/solarus.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/solarus.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/solarus.tar.gz Arkbuild/opt/solarus/
	echo "${SOLARUS_KEY}" > Arkbuild_package_cache/${CHIPSET}/solarus.commit
fi
sudo cp solarus/configs/${UNIT}/pads.ini Arkbuild/opt/solarus/
sudo cp solarus/scripts/solarus.sh Arkbuild/usr/local/bin/
sudo chmod 777 Arkbuild/usr/local/bin/solarus.sh
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/solarus/solarus-run
