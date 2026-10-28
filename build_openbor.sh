#!/bin/bash

# Build and install OpenBOR standalone emulator
# Cache key as in build_scummvmsa.sh: our recipe's pin and a hash of it and its patches.
if [ "$CHIPSET" == "rk3562" ]; then
  OPENBOR_KEY="$(grep -oP '(?<=git checkout )[[:alnum:]]+' rk3562_core_builds/scripts/openbor.sh | head -1)-$(cat rk3562_core_builds/scripts/openbor.sh rk3562_core_builds/patches/openbor-patch* 2>/dev/null | sha1sum | cut -c1-12)"
else
  OPENBOR_KEY="$(curl -s https://raw.githubusercontent.com/christianhaitian/${CORE_BUILDS_CHIPSET}_core_builds/refs/heads/master/scripts/openbor.sh | grep -oP '(?<=git checkout )[[:alnum:]]+')"
fi
if [ -f "Arkbuild_package_cache/${CHIPSET}/openbor.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/openbor.commit)" == "${OPENBOR_KEY}" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/openbor.tar.gz
else
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh openbor
	  "
	verify_action
	sudo mkdir -p Arkbuild/opt/OpenBor
	sudo mkdir -p Arkbuild/opt/OpenBor/Paks
	sudo mkdir -p Arkbuild/opt/OpenBor/Saves
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/openbor-64/OpenBOR Arkbuild/opt/OpenBor/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/openbor.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/openbor.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/openbor.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/openbor.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/openbor.tar.gz Arkbuild/opt/OpenBor/ 
	echo "${OPENBOR_KEY}" > Arkbuild_package_cache/${CHIPSET}/openbor.commit
fi
sudo cp openbor/configs/master.cfg.${UNIT} Arkbuild/opt/OpenBor/Saves/master.cfg
sudo cp openbor/OpenBor.sh Arkbuild/opt/OpenBor/OpenBor.sh
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/OpenBor/OpenBor.sh
