#!/bin/bash
#
# The chroot as bootstrap_rootfs and build_deps leave it, kept in
# Arkbuild_package_cache (docs/BUILDING.md).
#
# Under qemu those two stages take about four hours, nearly all of it apt and
# dpkg, and on most builds they would do what they did the time before. Each
# stage is kept with a key: a hash of what it is made of (its scripts and
# package lists, the functions and settings they use, the BSP files they
# install, and the point release of Debian, which is when the suite's packages
# change). A build whose key matches unpacks the stage instead of running it.
# A stage is kept from a build in which apt did not fail, once that build has
# got to its end.
#
# - bootstrap: the whole chroot after bootstrap_rootfs-${CHIPSET}.sh.
# - deps: what build_deps.sh changed in it, as the files it wrote and the files
#   it removed, on top of that same bootstrap copy. The kernel step runs between
#   the two and is not kept: /boot, /usr/lib/modules and initramfs-tools' record
#   of the initrds are left out of the deps copy, so a new kernel needs neither
#   stage again, and its initrd is still made from the system as bootstrap
#   leaves it (deps installs packages that add initramfs hooks).
#
# Both are read and written through a bind mount of Arkbuild that has none of
# the mounts inside it (the host's /dev, /proc and /sys, the ccache): what is
# kept is the image's filesystem and nothing of the host's, and nothing removed
# from the copy can be a file of the host's.

ROOTFS_CACHE="${PWD}/Arkbuild_package_cache/${CHIPSET}"
ROOTFS_TAR_FLAGS=(--numeric-owner --xattrs '--xattrs-include=*' --acls)
# What the deps copy leaves out: the kernel step's, what is copied in anew on
# every build, and the packages apt downloaded (cleanup_filesystem.sh deletes them)
ROOTFS_DELTA_SKIP=(./boot ./usr/lib/modules ./var/lib/initramfs-tools
  "./home/ark/${CHIPSET}_core_builds" ./home/ark/Arkbuild_ccache
  './var/cache/apt/archives/*.deb')
# The bootstrap copy this Arkbuild came from: the deps copy holds only on it
ROOTFS_BASE=""
ROOTFS_DELTA=""
# Set by what fails in a stage that may not fail the next time (apt)
ROOTFS_STAGE_FAILED=""

# The key of a stage on stdout. Fails if Debian cannot be asked for its point
# release, or, for deps, if Arkbuild came from no bootstrap copy.
function rootfs_cache_key() {
  local release
  release=$(curl -s https://deb.debian.org/debian/dists/${DEBIAN_CODE_NAME}/Release | grep "^Version:" | cut -d' ' -f2)
  if [ -z "$release" ]; then
    return 1
  fi
  if [ "$1" == "deps" ] && [ -z "$ROOTFS_BASE" ]; then
    return 1
  fi
  {
    echo "$1 ${release} ${DEBIAN_CODE_NAME} ${CHIPSET} ${UNIT} ${BUILD_ARMHF} ${ENABLE_CACHE}"
    if [ "$1" == "bootstrap" ]; then
      echo "${ROOT_FILESYSTEM_FORMAT} ${ROOT_FILESYSTEM_MOUNT_OPTIONS}"
      cat bootstrap_rootfs-${CHIPSET}.sh
      declare -f setup_ark_user mount_arkbuild
    else
      echo "${ROOTFS_BASE} ${whichmali} ${whichmali_bsp} ${CORE_BUILDS_CHIPSET}"
      cat build_deps.sh needed_packages.txt needed_dev_packages.txt
      declare -f install_package protect_package
      find BSP/mali.tar.gz BSP/librga BSP/librga32 BSP/vulkan -type f | sort | xargs sha256sum
    fi
  } | sha256sum | cut -d' ' -f1
}

# Arkbuild's own filesystem in ROOTFS_VIEW, and out of it again
function rootfs_view() {
  ROOTFS_VIEW=$(mktemp -d)
  sudo mount --bind Arkbuild "$ROOTFS_VIEW"
}

function rootfs_unview() {
  sudo umount "$ROOTFS_VIEW"
  rmdir "$ROOTFS_VIEW"
}

# Every path in Arkbuild's own filesystem but those the deps copy leaves out,
# with its inode and ctime, NUL-terminated and sorted: anything written,
# replaced, chmod-ed or linked to changes one of the two.
function rootfs_manifest() {
  local skip=() p
  for p in "${ROOTFS_DELTA_SKIP[@]}"; do
    skip+=(-path "$p" -o)
  done
  (cd "$ROOTFS_VIEW" && sudo find . -xdev \( "${skip[@]}" -false \) -prune -o -printf '%p\t%i %C@\0') \
    | LC_ALL=C sort -z
}

# Unpacks the stage's copy if its key matches; returns 1 when there is none.
# A copy that fails to unpack is deleted, and stops the build.
function restore_rootfs_cache() {
  local stage=$1 key rc
  key=$(rootfs_cache_key $stage) || return 1
  if [ ! -f "${ROOTFS_CACHE}/rootfs-${stage}.tar.zst" ] || \
     [ "$(cat ${ROOTFS_CACHE}/rootfs-${stage}.key 2>/dev/null)" != "$key" ]; then
    echo "rootfs cache: no copy of the ${stage} stage for this build; running it"
    return 1
  fi
  echo "rootfs cache: unpacking the ${stage} stage"
  rootfs_view
  if [ "$stage" == "deps" ]; then
    (cd "$ROOTFS_VIEW" && sudo xargs -0 -r rm -rf -- < "${ROOTFS_CACHE}/rootfs-deps.removed")
  fi
  sudo tar -C "$ROOTFS_VIEW" -I zstd -xpf "${ROOTFS_CACHE}/rootfs-${stage}.tar.zst" "${ROOTFS_TAR_FLAGS[@]}"
  rc=$?
  rootfs_unview
  if [ $rc != 0 ]; then
    echo "rootfs cache: the ${stage} copy did not unpack; it is deleted, and the next build makes it again"
    sudo rm -f ${ROOTFS_CACHE}/rootfs-${stage}.*
    exit 1
  fi
  if [ "$stage" == "bootstrap" ]; then
    ROOTFS_BASE=$(cat ${ROOTFS_CACHE}/rootfs-bootstrap.sha256)
  fi
}

# Before build_deps.sh: what Arkbuild holds, to tell afterwards what it changed
function rootfs_delta_begin() {
  ROOTFS_STAGE_FAILED=""
  ROOTFS_DELTA=$(mktemp -d)
  rootfs_view
  (set -o pipefail; rootfs_manifest > "${ROOTFS_DELTA}/before") || ROOTFS_STAGE_FAILED=y
  rootfs_unview
}

# What the deps copy is made of, in ROOTFS_DELTA: "written", the paths new
# since rootfs_delta_begin or with another inode or ctime, and the directories
# they are in, whose times unpacking would change; "removed", the paths gone.
function rootfs_delta_lists() {
  (
    set -o pipefail
    cd "$ROOTFS_DELTA" &&
      rootfs_manifest > after &&
      cut -z -f1 before | LC_ALL=C sort -z > before.paths &&
      cut -z -f1 after | LC_ALL=C sort -z > after.paths &&
      LC_ALL=C comm -z -13 before after | cut -z -f1 > changed &&
      LC_ALL=C comm -z -23 before.paths after.paths > removed &&
      cat changed removed | xargs -0 -r dirname -z | LC_ALL=C sort -z -u | \
        LC_ALL=C comm -z -12 - after.paths > parents &&
      LC_ALL=C sort -z -u changed parents > written
  )
}

# Keeps the stage, for builds to unpack once this one has got to its end
# (commit_rootfs_cache): a stage can go wrong without stopping the build, and
# the image would have it wrong in every build after. Not a stage in which apt
# failed (ROOTFS_STAGE_FAILED), either. Failing to keep it fails nothing else.
function save_rootfs_cache() {
  local stage=$1 key rc
  # The old copy is not what Arkbuild came from any more
  sudo rm -f ${ROOTFS_CACHE}/rootfs-${stage}.*
  if [ "$stage" == "deps" ] && [ -z "$ROOTFS_DELTA" ]; then
    return 0
  fi
  if [ -n "$ROOTFS_STAGE_FAILED" ]; then
    echo "rootfs cache: the ${stage} stage is not kept: something in it failed (above), and the next build runs it again"
  elif ! key=$(rootfs_cache_key $stage); then
    echo "rootfs cache: the ${stage} stage is not kept: no point release from Debian, or no bootstrap copy under it"
  else
    echo "rootfs cache: keeping the ${stage} stage"
    rootfs_view
    if [ "$stage" == "bootstrap" ]; then
      sudo tar -C "$ROOTFS_VIEW" -I "zstd -T0" -cpf "${ROOTFS_CACHE}/rootfs-bootstrap.tar.zst" \
        "${ROOTFS_TAR_FLAGS[@]}" --sparse --one-file-system .
      rc=$?
    else
      rootfs_delta_lists && \
        sudo tar -C "$ROOTFS_VIEW" -I "zstd -T0" -cpf "${ROOTFS_CACHE}/rootfs-deps.tar.zst" \
          "${ROOTFS_TAR_FLAGS[@]}" --sparse --null --no-recursion -T "${ROOTFS_DELTA}/written" && \
        sudo cp "${ROOTFS_DELTA}/removed" "${ROOTFS_CACHE}/rootfs-deps.removed"
      rc=$?
    fi
    rootfs_unview
    if [ $rc == 0 ]; then
      sha256sum "${ROOTFS_CACHE}/rootfs-${stage}.tar.zst" | cut -d' ' -f1 | sudo tee "${ROOTFS_CACHE}/rootfs-${stage}.sha256" >/dev/null
      echo "$key" | sudo tee "${ROOTFS_CACHE}/rootfs-${stage}.pending" >/dev/null
      if [ "$stage" == "bootstrap" ]; then
        ROOTFS_BASE=$(cat ${ROOTFS_CACHE}/rootfs-bootstrap.sha256)
      fi
    else
      echo "rootfs cache: could not write the ${stage} copy; not kept"
      sudo rm -f ${ROOTFS_CACHE}/rootfs-${stage}.*
    fi
  fi
  ROOTFS_STAGE_FAILED=""
  if [ -n "$ROOTFS_DELTA" ]; then
    sudo rm -rf "$ROOTFS_DELTA"
    ROOTFS_DELTA=""
  fi
}

# At the end of the build: the stages it kept can be unpacked from now on
function commit_rootfs_cache() {
  local f
  for f in ${ROOTFS_CACHE}/rootfs-*.pending; do
    if [ -f "$f" ]; then
      sudo mv "$f" "${f%.pending}.key"
    fi
  done
}
