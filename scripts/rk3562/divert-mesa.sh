#!/bin/bash
# divert-mesa.sh <triplet>   (aarch64-linux-gnu or arm-linux-gnueabihf)
#
# The build points Debian's GL/EGL/GBM names at the Mali blob (and, on aarch64,
# libvulkan.so.1 at the BSP loader), over files that Debian packages own. Left
# like that, an apt upgrade of libgbm1, libegl1 and the like on the device puts
# Mesa's file back over the link, and ldconfig - which every library install
# runs, without -X - points libvulkan.so.1 and libwayland-egl.so.1 at Debian's
# libraries, the newest files with those sonames.
#
# So divert them to /usr/lib/mali-diverted/<triplet>, outside ld.so.conf, as
# Debian's NVIDIA packages divert Mesa: package files go there instead, and
# ldconfig never sees them. A path that already holds the build's link (a
# device made before this) is only registered; anything else is moved there.
# Safe to run again.
set -u
T=$1
case $T in
  aarch64-linux-gnu) A=arm64 ;;
  arm-linux-gnueabihf) A=armhf ;;
  *) echo "divert-mesa.sh: unknown triplet $T" >&2; exit 1 ;;
esac
D=/usr/lib/$T
V=/usr/lib/mali-diverted/$T
LINKS="libEGL.so libEGL.so.1 libEGL.so.1.1.0 libGLES_CM.so libGLES_CM.so.1
libGLESv1_CM.so libGLESv1_CM.so.1 libGLESv1_CM.so.1.1.0 libGLESv2.so
libGLESv2.so.2 libGLESv2.so.2.0.0 libGLESv2.so.2.1.0 libGLESv3.so libGLESv3.so.3
libgbm.so libgbm.so.1 libgbm.so.1.0.0 libmali.so libmali.so.1 libMaliOpenCL.so
libOpenCL.so libwayland-egl.so libwayland-egl.so.1 libwayland-egl.so.1.0.0"
PKGS="libwayland-egl1"
if [ "$T" = aarch64-linux-gnu ]; then
  LINKS="$LINKS libvulkan.so.1"
  PKGS="$PKGS libvulkan1"
fi

paths() {
  for L in $LINKS; do echo "$D/$L"; done
  # the real files behind those packages' soname links
  for p in $PKGS; do
    dpkg -L "$p:$A" 2>/dev/null | grep -E "^$D/lib[^/]*\.so\.[0-9.]+$"
  done
}

mkdir -p "$V"
for P in $(paths | sort -u); do
  dpkg -S "$P" >/dev/null 2>&1 || continue
  case "$(readlink "$P")" in
    libMali.so|libvulkan.so.1.3.274) how=--no-rename ;;
    *) how=--rename ;;
  esac
  dpkg-divert --quiet $how --divert "$V/$(basename "$P")" --add "$P"
done
exit 0
