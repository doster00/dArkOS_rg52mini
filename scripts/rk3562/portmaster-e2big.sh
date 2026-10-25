#!/bin/bash
# PortMaster does not know the RG52 Mini's joystick (play_joystick), so its
# get_controls() puts the whole gamecontrollerdb.txt - about 470 KB - into
# sdl_controllerconfig, and every port exports that as SDL_GAMECONTROLLERCONFIG.
# One environment string may not exceed MAX_ARG_STRLEN (128 KB), so after the
# export every exec fails with "Argument list too long" and no port starts.
#
# PortMaster already guards against this on EmuELEC (mod_EmuELEC.txt); this
# appends the same guard to mod_dArkOS.txt, which every port sources after
# control.txt. SDL still gets the mappings, including the one mapper.py adds
# for this joystick, through SDL_GAMECONTROLLERCONFIG_FILE.
#
# It also points gl4es at the render-target fix (LIBGL_GLES), and lets the Vulkan driver chosen in
# ES (DARKOS_VULKAN) through to a port run with $ESUDO, see below.
#
# PortMaster overwrites its files when it updates itself, so this runs at boot
# and from portmaster-e2big.path whenever mod_dArkOS.txt changes.

MARK="# dArkOS RG52 Mini: E2BIG guard"
MARK_GL4ES="# dArkOS RG52 Mini: gl4es render-target fix"
MARK_VULKAN="# dArkOS RG52 Mini: Vulkan driver through sudo"

for dir in /opt/system/Tools/PortMaster /roms/ports/PortMaster /roms2/ports/PortMaster /roms/tools/PortMaster; do
  f="$dir/mod_dArkOS.txt"
  [ -f "$f" ] || continue
  if ! grep -qF "$MARK_GL4ES" "$f" && [ -f /usr/lib/aarch64-linux-gnu/gl4es-fix/libGLESv2.so.2 ]; then
    cat >> "$f" <<'GL4ES'

# dArkOS RG52 Mini: gl4es render-target fix (added by /usr/local/bin/portmaster-e2big.sh)
# gl4es leaves the textures a game renders into with the GLES default min filter
# GL_NEAREST_MIPMAP_LINEAR; without mipmaps libmali reads them as black (Don't
# Starve: a black world). This library forwards every GLES call to libmali and
# gives such textures GL_LINEAR. Only gl4es reads LIBGL_GLES; a port that sets
# its own keeps it.
if [ -z "$LIBGL_GLES" ] && [ -f /usr/lib/aarch64-linux-gnu/gl4es-fix/libGLESv2.so.2 ]; then
    export LIBGL_GLES=/usr/lib/aarch64-linux-gnu/gl4es-fix/libGLESv2.so.2
fi
GL4ES
    logger -t portmaster-e2big "gl4es fix added to $f"
  fi
  if ! grep -qF "$MARK_VULKAN" "$f"; then
    cat >> "$f" <<'VULKAN'

# dArkOS RG52 Mini: Vulkan driver through sudo (added by /usr/local/bin/portmaster-e2big.sh)
# ES's EMULATOR SETTINGS > VULKAN DRIVER for the ports reaches them as DARKOS_VULKAN, which
# libvulkan_darkos.so reads; $ESUDO (sudo --preserve-env=<list>) would drop it for a port that
# runs its game through sudo.
if [ -n "$DARKOS_VULKAN" ] && [[ "$ESUDO" == sudo* ]] && [[ "$ESUDO" != *DARKOS_VULKAN* ]]; then
    if [[ "$ESUDO" == *--preserve-env=* ]]; then
        ESUDO="${ESUDO/--preserve-env=/--preserve-env=DARKOS_VULKAN,}"
    else
        ESUDO="$ESUDO --preserve-env=DARKOS_VULKAN"
    fi
    export ESUDO
fi
VULKAN
    logger -t portmaster-e2big "Vulkan driver pass-through added to $f"
  fi
  grep -qF "$MARK" "$f" && continue
  cat >> "$f" <<'GUARD'

# dArkOS RG52 Mini: E2BIG guard (added by /usr/local/bin/portmaster-e2big.sh)
# get_controls reads the full gamecontrollerdb.txt into sdl_controllerconfig when
# no device GUID is known. Ports export it as SDL_GAMECONTROLLERCONFIG, which
# exceeds MAX_ARG_STRLEN (131072 bytes) and makes every execve() fail with E2BIG.
# SDL still gets the mappings via SDL_GAMECONTROLLERCONFIG_FILE.
if declare -f get_controls >/dev/null 2>&1; then
    eval "_pm_get_controls_orig() $(declare -f get_controls | tail -n +2)"

    get_controls() {
        _pm_get_controls_orig "$@"
        [ "${#sdl_controllerconfig}" -gt 100000 ] && sdl_controllerconfig=""
    }
fi
GUARD
  logger -t portmaster-e2big "guard added to $f"
done
exit 0
