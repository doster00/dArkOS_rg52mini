#!/bin/bash

# Build and install SCUMMVM standalone emulator
# The cache key: on rk3562 the version our recipe (the submodule) pins and a
# hash of that recipe and the patches it copies, as build_ppssppsa.sh does.
# It used to be the version in christianhaitian's master, read over the
# network, which is not what this build compiles: ScummVM 2026.3.0 was built
# and cached as v2026.4.0 the day his recipe moved and ours had not.
if [ "$CHIPSET" == "rk3562" ]; then
  SCUMMVM_KEY="$(grep -oP '(?<=TAG=").*?(?=")' rk3562_core_builds/scripts/scummvm.sh | head -1)-$(cat rk3562_core_builds/scripts/scummvm.sh rk3562_core_builds/patches/scummvm-patch* 2>/dev/null | sha1sum | cut -c1-12)"
else
  SCUMMVM_KEY="$(curl -s https://raw.githubusercontent.com/christianhaitian/${CORE_BUILDS_CHIPSET}_core_builds/refs/heads/master/scripts/scummvm.sh | grep -oP '(?<=TAG=").*?(?=")')"
fi
if [ -f "Arkbuild_package_cache/${CHIPSET}/scummvm.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/scummvm.commit)" == "${SCUMMVM_KEY}" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/scummvm.tar.gz
else
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh scummvm
	  "
	verify_action
	sudo mkdir -p Arkbuild/opt/scummvm
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/extra/ Arkbuild/opt/scummvm/
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/themes/ Arkbuild/opt/scummvm/
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/LICENSES/ Arkbuild/opt/scummvm/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/scummvm Arkbuild/opt/scummvm/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/AUTHORS Arkbuild/opt/scummvm/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/COPYING Arkbuild/opt/scummvm/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/COPYRIGHT Arkbuild/opt/scummvm/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/NEWS.md Arkbuild/opt/scummvm/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/README.md Arkbuild/opt/scummvm/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/scummvm.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/scummvm.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/scummvm.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/scummvm.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/scummvm.tar.gz Arkbuild/opt/scummvm/
	echo "${SCUMMVM_KEY}" > Arkbuild_package_cache/${CHIPSET}/scummvm.commit
fi

sudo mkdir -p Arkbuild/home/ark/.config/scummvm
sudo cp scummvm/configs/scummvm.ini.${UNIT} Arkbuild/home/ark/.config/scummvm/scummvm.ini
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/scummvm/scummvm
call_chroot "chown -R ark:ark /home/ark/.config/"
sudo cp scummvm/scripts/scummvm.sh Arkbuild/usr/local/bin/scummvm.sh
sudo chmod 777 Arkbuild/usr/local/bin/scummvm.sh
