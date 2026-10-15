#!/bin/bash

# Build and install ECWolf standalone emulator
# The cache key is the head of the GitHub repository builds-alt.sh clones; the
# bitbucket mirror asked before stopped at 51994be, so the key never matched.
# A cached tarball without the binary is a failed build and is not reused.
ecwolf_head="$(git ls-remote https://github.com/ECWolfEngine/ECWolf.git HEAD | cut -f1)"
if [ -f "Arkbuild_package_cache/${CHIPSET}/ecwolfsa.tar.gz" ] && [ -n "$ecwolf_head" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/ecwolfsa.commit)" == "$ecwolf_head" ] && tar -tzf Arkbuild_package_cache/${CHIPSET}/ecwolfsa.tar.gz | grep -qx "Arkbuild/opt/ecwolf/ecwolf"; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/ecwolfsa.tar.gz
else
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh ecwolfsa
	  "
	sudo mkdir -p Arkbuild/opt/ecwolf
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/ecwolf-64/* Arkbuild/opt/ecwolf/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/ecwolfsa.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/ecwolfsa.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/ecwolfsa.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/ecwolfsa.commit
	fi
	if [ -f Arkbuild/opt/ecwolf/ecwolf ]; then
	  sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/ecwolfsa.tar.gz Arkbuild/opt/ecwolf/
	  sudo git --git-dir=Arkbuild/home/ark/${CHIPSET}_core_builds/ecwolf/.git --work-tree=Arkbuild/home/ark/${CHIPSET}_core_builds/ecwolf rev-parse HEAD > Arkbuild_package_cache/${CHIPSET}/ecwolfsa.commit
	fi
fi
sudo mkdir -p Arkbuild/home/ark/.config/ecwolf
sudo cp ecwolf/config/ecwolf.cfg.${UNIT} Arkbuild/home/ark/.config/ecwolf/ecwolf.cfg
sudo cp -a ecwolf/ecwolf* Arkbuild/usr/local/bin/

call_chroot "chown -R ark:ark /home/ark/.config/"
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/ecwolf/*
sudo chmod 777 Arkbuild/usr/local/bin/ecwolf*
