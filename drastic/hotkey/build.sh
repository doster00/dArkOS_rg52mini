#!/bin/sh
# build.sh: build drastic-hotkey.so (run on aarch64, or in an aarch64 chroot) -
# gcc and SDL2's headers needed (the image's SDL2 has them in /usr/local).
set -e
cd "$(dirname "$0")"
${CC:-gcc} -O2 -s -shared -fPIC -Wall -D_REENTRANT -I/usr/local/include/SDL2 -I/usr/include/SDL2 \
  -o drastic-hotkey.so hotkey.c -ldl
echo "built: $(ls -l drastic-hotkey.so)"
