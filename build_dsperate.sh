#!/bin/bash

# Build and install the DSperate standalone NDS emulator (upstream
# christianhaitian/dArkOS 0850604). The cache key carries DSperate's commit,
# pinned in rk3562_core_builds/scripts/dsperate.sh, and a hash of that recipe
# and its patches, so a change to either rebuilds it instead of restoring the
# old binary.
#
# The Vulkan presenter and GPU 3D raster (video.gpu3d) are built only when
# vulkan/vulkan.h is there at build time - libvulkan itself is dlopened on the
# device - and nothing else in the chroot pulls in libvulkan-dev. Without it
# DSperate logs "gpu3d: unavailable (built without Vulkan)" and draws all 3D on
# the CPU. The "_vk" in the key keeps a cached binary from before this out.
install_package 64 libvulkan-dev
DSPERATE_COMMIT=$(grep -oP '(?<=^commit=")[0-9a-f]+' ${CHIPSET}_core_builds/scripts/dsperate.sh 2>/dev/null)
DSPERATE_RECIPE_SHA=$(cat ${CHIPSET}_core_builds/scripts/dsperate.sh ${CHIPSET}_core_builds/patches/dsperate-patch* 2>/dev/null | sha1sum | cut -c1-12)
DSPERATE_KEY="${DSPERATE_COMMIT}_${DSPERATE_RECIPE_SHA}_vk"
if [ -f "Arkbuild_package_cache/${CHIPSET}/dsperate.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/dsperate.commit 2>/dev/null)" == "${DSPERATE_KEY}" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/dsperate.tar.gz
    if [ ! -f "Arkbuild/opt/DSperate/dsperate" ]; then
        echo "WARNING: DSperate cache tarball is incomplete, rebuilding from source..."
        sudo rm -f Arkbuild_package_cache/${CHIPSET}/dsperate.tar.gz
    fi
fi
if [ ! -f "Arkbuild/opt/DSperate/dsperate" ]; then
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh dsperate
	  "
	verify_action
	sudo mkdir -p Arkbuild/opt/DSperate/config
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/dsperate-64/dsperate Arkbuild/opt/DSperate/
	if [ -f "Arkbuild/opt/DSperate/dsperate" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/dsperate.tar.gz Arkbuild_package_cache/${CHIPSET}/dsperate.commit
	  sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/dsperate.tar.gz Arkbuild/opt/DSperate/
	  echo "${DSPERATE_KEY}" | sudo tee Arkbuild_package_cache/${CHIPSET}/dsperate.commit > /dev/null
	else
	  echo "WARNING: DSperate did not build; the nds system will offer it but it will not start"
	fi
fi
sudo mkdir -p Arkbuild/opt/DSperate/config
if [[ -e "DSperate/configs/dsperate.ini.$UNIT" ]]; then
  sudo cp -L DSperate/configs/dsperate.ini.${UNIT} Arkbuild/opt/DSperate/config/dsperate.ini
else
  sudo cp -L DSperate/configs/dsperate.ini.${CHIPSET} Arkbuild/opt/DSperate/config/dsperate.ini
fi
sudo cp -a DSperate/scripts/nds.sh Arkbuild/usr/local/bin/

call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/DSperate/dsperate 2>/dev/null
sudo chmod 777 Arkbuild/usr/local/bin/nds.sh
