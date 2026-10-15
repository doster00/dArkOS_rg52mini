#!/bin/bash
# In every package: rebuild the dynamic linker's cache. Packages do not carry
# /etc/ld.so.cache - it is made from the libraries, and on a device where it
# differs from its build's (anything installed with apt) the client would keep
# the old one as a file the user changed - so the libraries a package adds are
# in the cache only after this. Clients from 1.1 on run ldconfig themselves;
# this hook is for those of its test builds.
#
# Those pass on the PATH of whoever ran them, and sudo keeps ark's, which has
# no sbin (sudoers.d/ark-no-secure-path).
#
# -X: the cache only. The links are as the package left them, the build's;
# ldconfig would point libvulkan.so.1 and libwayland-egl.so.1 at Debian's
# libraries instead (see all-gpu-links.sh).
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ldconfig -X
