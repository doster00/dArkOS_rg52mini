#!/bin/bash

# Build and install Mednafen
# Cache key as in build_scummvmsa.sh: our recipe's pin and a hash of it and its patches.
if [ "$CHIPSET" == "rk3562" ]; then
  MEDNAFEN_KEY="$(grep -oP '(?<=tarname=").*?(?=")' rk3562_core_builds/scripts/mednafen.sh | head -1)-$(cat rk3562_core_builds/scripts/mednafen.sh rk3562_core_builds/patches/mednafen-patch* 2>/dev/null | sha1sum | cut -c1-12)"
else
  MEDNAFEN_KEY="$(curl -s https://raw.githubusercontent.com/christianhaitian/${CORE_BUILDS_CHIPSET}_core_builds/refs/heads/master/scripts/mednafen.sh | grep -oP '(?<=tarname=").*?(?=")')"
fi
if [ -f "Arkbuild_package_cache/${CHIPSET}/mednafen.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/mednafen.commit)" == "${MEDNAFEN_KEY}" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/mednafen.tar.gz
else
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  ./builds-alt.sh mednafen
	  "
	verify_action
	sudo mkdir -p Arkbuild/opt/mednafen
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/mednafen64/mednafen Arkbuild/opt/mednafen/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/mednafen.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/mednafen.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/mednafen.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/mednafen.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/mednafen.tar.gz Arkbuild/opt/mednafen/
	echo "${MEDNAFEN_KEY}" > Arkbuild_package_cache/${CHIPSET}/mednafen.commit
fi
sudo mkdir -p Arkbuild/home/ark/.mednafen
sudo cp mednafen/configs/mednafen.cfg.${UNIT} Arkbuild/home/ark/.mednafen/mednafen.cfg
sudo cp mednafen/mednafen Arkbuild/usr/local/bin/

call_chroot "chown -R ark:ark /home/ark/.mednafen/"
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/mednafen/mednafen
sudo chmod 777 Arkbuild/usr/local/bin/mednafen

