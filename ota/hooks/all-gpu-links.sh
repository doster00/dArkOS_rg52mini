#!/bin/bash
# In every package: put back the library links the build makes by hand.
#
# Without -X, ldconfig points each soname link at the newest file that carries
# the soname, and here that is Debian's: libvulkan.so.1 went from the BSP loader
# (libvulkan.so.1.3.274) to Debian's libvulkan.so.1.4.309, and
# libwayland-egl.so.1 from libMali.so to Debian's. The 1.1 client runs ldconfig
# that way just before the hooks; later clients and all-ldconfig.sh use -X.
# The lists are cleanup_filesystem.sh's. Links changed here are listed for a
# rollback, which takes them back from the snapshot.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

MALI_LINKS="libEGL.so libEGL.so.1 libEGL.so.1.1.0 libGLES_CM.so libGLES_CM.so.1
libGLESv1_CM.so libGLESv1_CM.so.1 libGLESv1_CM.so.1.1.0 libGLESv2.so
libGLESv2.so.2 libGLESv2.so.2.0.0 libGLESv2.so.2.1.0 libGLESv3.so libGLESv3.so.3
libgbm.so libgbm.so.1 libgbm.so.1.0.0 libmali.so libmali.so.1 libMaliOpenCL.so
libOpenCL.so libwayland-egl.so libwayland-egl.so.1 libwayland-egl.so.1.0.0"

relink() {  # dir link target
  [ -e "$1/$3" ] || return 0
  [ "$(readlink "$1/$2")" = "$3" ] && return 0
  ln -sfn "$3" "$1/$2" || return 0
  echo "$1/$2" >> /var/lib/darkos-ota/merged
  echo "relinked $1/$2 -> $3"
}

for d in /usr/lib/aarch64-linux-gnu /usr/lib/arm-linux-gnueabihf; do
  [ -e "$d/libMali.so" ] || continue
  for l in $MALI_LINKS; do relink "$d" "$l" libMali.so; done
done
relink /usr/lib/aarch64-linux-gnu libvulkan.so.1 libvulkan.so.1.3.274
exit 0
