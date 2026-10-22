#!/bin/bash

# Build and install Retrorun and Retrorun32
if [ "$CHIPSET" == "rk3326" ]; then
  ext="-rk3326"
else
  ext=""
fi

# The recipe and its patches are part of the cache key (as in build_fake08.sh):
# our RG52 Mini rotation patch lives there, and a key of the upstream commit
# alone would keep restoring a binary built without it.
RR_RECIPE_SHA=$(cat ${CHIPSET}_core_builds/scripts/retrorun.sh ${CHIPSET}_core_builds/patches/retrorun-patch* 2>/dev/null | sha1sum | cut -c1-12)
RR_KEY="$(curl -s https://api.github.com/repos/navy1978/retrorun/commits/master | jq -r '.sha')-${RR_RECIPE_SHA}"

if [ -f "Arkbuild_package_cache/${CHIPSET}/retrorun.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/retrorun.commit)" == "$RR_KEY" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/retrorun.tar.gz
else
	call_chroot "cd /home/ark &&
	  if [ ! -d ${CHIPSET}_core_builds ]; then git clone https://github.com/christianhaitian/${CORE_BUILDS_CHIPSET}_core_builds.git ${CHIPSET}_core_builds; fi &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  ./builds-alt.sh retrorun
	  "
	verify_action
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/retrorun-64/retrorun${ext} Arkbuild/usr/local/bin/retrorun
	if [ -f "Arkbuild_package_cache/${CHIPSET}/retrorun.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/retrorun.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/retrorun.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/retrorun.commit
	fi
	if [ -f Arkbuild/usr/local/bin/retrorun ]; then
	  sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/retrorun.tar.gz Arkbuild/usr/local/bin/retrorun
	  echo "$(sudo git --git-dir=Arkbuild/home/ark/${CHIPSET}_core_builds/retrorun/.git --work-tree=Arkbuild/home/ark/${CHIPSET}_core_builds/retrorun rev-parse HEAD)-${RR_RECIPE_SHA}" | sudo tee Arkbuild_package_cache/${CHIPSET}/retrorun.commit >/dev/null
	fi
fi
if [[ "${BUILD_ARMHF}" == "y" ]]; then
  if [ -f "Arkbuild_package_cache/${CHIPSET}/retrorun32.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/retrorun32.commit)" == "$RR_KEY" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/retrorun32.tar.gz
  else
	  call_chroot32 "cd /home/ark &&
		if [ ! -d ${CHIPSET}_core_builds ]; then git clone https://github.com/christianhaitian/${CORE_BUILDS_CHIPSET}_core_builds.git ${CHIPSET}_core_builds; fi &&
		cd ${CHIPSET}_core_builds &&
		chmod 777 builds-alt.sh &&
		./builds-alt.sh retrorun
		"
	  verify_action
	  sudo cp -a Arkbuild32/home/ark/${CHIPSET}_core_builds/retrorun-32/retrorun32${ext} Arkbuild/usr/local/bin/retrorun32
	  if [ -f "Arkbuild_package_cache/${CHIPSET}/retrorun32.tar.gz" ]; then
	    sudo rm -f Arkbuild_package_cache/${CHIPSET}/retrorun32.tar.gz
	  fi
	  if [ -f "Arkbuild_package_cache/${CHIPSET}/retrorun32.commit" ]; then
	    sudo rm -f Arkbuild_package_cache/${CHIPSET}/retrorun32.commit
	  fi
	  if [ -f Arkbuild/usr/local/bin/retrorun32 ]; then
	    sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/retrorun32.tar.gz Arkbuild/usr/local/bin/retrorun32
	    echo "$(sudo git --git-dir=Arkbuild32/home/ark/${CHIPSET}_core_builds/retrorun/.git --work-tree=Arkbuild32/home/ark/${CHIPSET}_core_builds/retrorun rev-parse HEAD)-${RR_RECIPE_SHA}" | sudo tee Arkbuild_package_cache/${CHIPSET}/retrorun32.commit >/dev/null
	  fi
  fi
fi

sudo cp retrorun/scripts/*.sh Arkbuild/usr/local/bin/
sudo cp retrorun/configs/retrorun.cfg.${CHIPSET} Arkbuild/home/ark/.config/retrorun.cfg

sudo chmod 777 Arkbuild/usr/local/bin/retrorun*
sudo chmod 777 Arkbuild/usr/local/bin/atomiswave.sh
sudo chmod 777 Arkbuild/usr/local/bin/dreamcast.sh
sudo chmod 777 Arkbuild/usr/local/bin/naomi.sh
sudo chmod 777 Arkbuild/usr/local/bin/saturn.sh
