#!/bin/bash

# Build and install trigaxes-off (trigaxes-off/): an LD_PRELOAD library that
# hides the pad's analog trigger axes (ABS_Z/ABS_RZ) from a process. The GTA
# San Andreas port reads them as the right stick, so the camera turned after
# L2 or R2 was touched; runport.sh preloads it for it. See docs/KNOWN-ISSUES.md.
sudo rm -rf Arkbuild/tmp/trigaxes-off
sudo cp -r trigaxes-off Arkbuild/tmp/
call_chroot "cd /tmp/trigaxes-off && gcc -O2 -Wall -shared -fPIC -o libtrigaxes-off.so trigaxes-off.c -ldl"
if [ -f Arkbuild/tmp/trigaxes-off/libtrigaxes-off.so ]; then
  sudo install -D -m 644 Arkbuild/tmp/trigaxes-off/libtrigaxes-off.so \
    Arkbuild/usr/lib/aarch64-linux-gnu/trigaxes-off/libtrigaxes-off.so
else
  echo "WARNING: trigaxes-off did not build; in the GTA ports L2/R2 will turn the camera."
fi
sudo rm -rf Arkbuild/tmp/trigaxes-off
