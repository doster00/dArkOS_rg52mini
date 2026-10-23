# What is next

A working list, not a roadmap. Ordered by what a build would answer soonest.

## Shipped in v09162026

All of it is on the device and released, so it is history rather than a list to
work through: the boot logo from both halves, `Playback Path = SPK` by default,
zram on lzo-rle with the eMMC partition as a second tier, stripped modules,
Cortex-A53 flags for everything that rebuilt, Kodi, Yabasanshiro, freej2me-plus,
our own U-Boot, and the component audit that runs at the end of every build.

The kernel changes that landed after the build finished — the RK628 bridge
fix, the hang detectors, the bootloader log — were rebuilt and written into the
released image by hand rather than left waiting.

## Shipped in v09292026

Everything the previous list was waiting on, plus what was found while building
it. Confirmed on the device.

* **flycast and fake-08 are optimised now** — they had been built at `-O0` and
  `-g`. PPSSPP's `flags.make` was read out of the running build to prove the
  flags arrive, and the cache key change meant it rebuilt from source rather
  than restoring the artifact made under the old flags.
* **`perfmax` sets the GPU governor**, which it never did on this SoC — it was
  writing to the RK3566 node, so every game ran on `simple_ondemand`.
* **BlueZ accepts HID from unbonded devices**, which is most legacy Bluetooth
  gamepads. It was in the released image by hand; now it is in the build.
* **The Bluetooth driver no longer frees every failed packet twice.**
  `bt_sdio_recv()` in aic8800 called `kfree_skb()` after `hci_recv_frame()`
  had already freed it — 150 to 200 double frees per shutdown with Bluetooth
  on, a corrupted slab, and a panic somewhere unrelated a moment later. See
  KNOWN-ISSUES.
* **The two GPU drivers that cannot bind here are gone**, and so is the
  debugging the device never reads: `Image` is 6.0 MB smaller. See
  PERFORMANCE and HARDWARE.
* **OP-TEE is off on both sides** — driver and bootloader — which returns the
  2 MiB SHM window. See HARDWARE. (v10052026 went back to the stock BL32
  v1.07, whose region is 2 MiB larger.)
* **RetroArch gets its cores even when GitHub says 429.** 269 cores
  downloaded, 8 of them only after a retry; plain `wget -t` counts network
  failures and treats an HTTP error as a final answer, so those 8 used to go
  missing silently.
* **A workaround for the revision A black screen**, added to the assets on
  2026-10-03: `panel-kick` re-initialises the display before EmulationStation,
  letting the DSI host and its PHY runtime-suspend first. The mechanism was
  found on revision B; confirmed working on a revision A unit by its owner.
  KNOWN-ISSUES has the evidence.

## Check on the device what the upstream sync of 2026-10-05 brought

The sync with christianhaitian/dArkOS and rk3566_core_builds (see the commits
of that date) was done by reading, not by running. Each of these needs a look
on the device:

1. **DSperate** — checked on the device on 2026-10-07 (v10062026, revision B),
   with the Pokemon Diamond & Pearl and Dragon Quest Monsters Joker 2 demos and
   the BIOS and firmware dumps in /roms/bios:
   * **Rotation: fine.** It does not take the KMS page-flip path on this panel
     ("drm: display 0 has no 1280x720 mode (panel is 720x1280)"); it presents
     through an SDL window surface on KMSDRM, so our SDL rotation patch turns
     the picture. Both DS screens stacked, centred, upright.
   * **Input: fine.** nds.sh's RG52 mapping is picked up; DSperate notices that
     SDL's a/b and x/y are swapped against the kernel's button positions and
     corrects it itself. Start+Select quits.
   * **Sound** through ALSA at 48 kHz; one underrun at start.
   * **Speed is the CPU governor, not the build.** Pokemon DP demo, first
     field, walking; clocks sampled twice a second for 10 s:

     | | ondemand (CPU) / simple_ondemand (GPU) / dmc_ondemand | performance |
     |---|---|---|
     | fps | 41-47, audio underruns | 60, none |
     | CPU | 816-2016 MHz, under 1.5 GHz a third of the time | 2016 MHz |
     | GPU | 300 MHz | 900 MHz |
     | DMC | 928 MHz | 928 MHz |

     DSperate keeps about one core busy, which ondemand reads as light load.
     The 3D field of the Joker 2 demo behaves the same way: 48 fps under
     ondemand, 59-60 under performance. Nothing in the image changes this
     (decided 2026-10-07); KNOWN-ISSUES tells users to pick the performance
     governor for NDS in ES.
   * **Vulkan, in the image since 2026-10-07.** The first 10062026 build had
     DSperate without Vulkan ("gpu3d: unavailable (built without Vulkan)"):
     the presenter and GPU 3D raster need `vulkan/vulkan.h` at build time and
     the chroot had no libvulkan-dev. build_dsperate.sh now installs it (cache
     key suffix `_vk`), the v10062026 image carries that build, and
     dsperate.ini.rk3562 sets `gpu3d = true`. On the device it logs
     "gpu3d: on". In the two demos it made no measurable difference to the
     frame rate - the governor is what matters there - but it moves 3D off the
     CPU for heavier games. Existing cards keep their /roms/nds/dsperate/
     dsperate.ini; nds.sh copies the new default only where there is none.
   * Not yet checked: the stylus on the stick, savestates, a heavier 3D game.
2. **Dolphin hotkeys** — the one recompiled emulator (patch 012).
3. **PPSSPP-2021** now keeps its config and saves in /roms/psp/ppsspp-2021.
   Saves made with it before are still in /roms/psp/ppsspp and are not moved.
4. **Shutdown image** (bye.gif through ffplay in finish.sh / pause.sh): does
   it show the right way up through our SDL rotation?
5. **wifi_importer**: a wifikeyfile.txt in Tools is imported at boot.
6. Not taken, to be decided on the device: libOpenCL.so symlink (upstream
   says it breaks video previews), Dolphin Stretch option, batteryplus,
   headphone auto-switch (needs kernel work), bluealsa conf path.

## Found while testing 1.2 (2026-10-18)

* **ScummVM's MIDI device.** Its ini asks for `fluidsynth`, which this
  ScummVM build does not have, so MIDI games open on a "device not found"
  dialog (KNOWN-ISSUES, smaller things). Either build ScummVM with
  libfluidsynth and ship a SoundFont, or set `gm_device`/`mt32_device` to
  something it has.
* **Speaker volume.** The DAC stays at −20 dB, which is what keeps the
  low-battery reset away (KNOWN-ISSUES). If the speaker is to get louder,
  take the battery-dependent limit the GammaOS port is writing for the rk817
  codec rather than raising the DAC.
* **`create_image.sh` packs every `*.img` in the build directory** into 7z,
  so OTA base images kept next to the build (1.1, older test builds) cost a
  few minutes and 4 GB each per build. Keep them in another directory, or
  pack only the image just made.
* **`ota/make-ota.py -o DIR`** fails at the very end, after three minutes of
  comparing, when DIR does not exist. Create it first, or let the script.
* **`retroarch32` with `parallel_n64` ignored SIGTERM** in the test harness:
  systemd killed it after 90 s. The exit hotkey was not tried; worth a look.

## Nintendo 3DS: Azahar is in (2026-10-20)

`azahar_libretro` (2126.1.2 with GammaOS's azahar-nano) with clang and PGO,
RetroArch on vulkan for it, the large screen layout, the `n3ds` alias and our
nes-box folder (KNOWN-ISSUES). Left:

* **Our part of the profile comes from one game.** GammaOS's part covers six,
  but only where their code and ours compile alike. Train ours on two or three
  more (a 3D one with many effects, a 2D one) and merge them:
  `llvm-profdata merge -weighted-input=<w>,<file>`, with weights that give each
  part about the same total count (`llvm-profdata show --detailed-summary`).
  The recipe names the file.
* **A new profile needs the chroot's paths.** clang names file-local functions
  in a profile by the path of their source. Ours was trained from a tree on
  the host, and the image builds in `/home/ark/rk3562_core_builds/azahar`
  in the chroot: the recipe's run there (2026-10-21, 573 min under qemu,
  exit 0) made a core 600 KB larger than the measured one, without the
  profile of those functions (6% of its counts). The profile now carries
  the chroot's paths, and a host build from that path matches the measured
  core (`.text` within 64 bytes). For a new one: `llvm-profdata merge
  --text`, the training tree's path replaced, merged back; ARMSX2's has the
  same treatment.
* **How well a profile fits the code:** build with `-fprofile-use=<it>
  -Wno-everything -Wbackend-plugin -Wno-error=backend-plugin -mllvm
  -pgo-warn-missing-function`, with the externals' `-w` taken out of
  `externals/CMakeLists.txt` (it reaches everything built against boost).
  clang names each function whose code changed since training (hash mismatch,
  its data dropped); their share of the profile's counts (`llvm-profdata show
  --all-functions --counts`) is what is lost. GammaOS's profile lost 44%.
* **More games.** Only Super Mario 3D Land was played. Check a heavier one
  (Monster Hunter, Zelda) and what speed it reaches.
* **azahar-nano's switches:** only their defaults were measured. Since
  006-008 (2026-10-23) the core is set up as GammaOS's frontend sets it
  (KNOWN-ISSUES, "GammaOS's settings").
* **Presenting on a thread of its own.** With both eyes drawn Super Mario 3D
  Land runs at 42 here with the GPU 64% busy, at 50-58 on GammaOS with the
  same GPU work: the core waits about 15 ms a frame inside RetroArch's
  present (acquire of the next swapchain image), and the emulation does not
  go on meanwhile. GammaOS's azahar-nano presents on its own thread and shows
  the newest frame. Right eye off (the default) it is 60 either way; a game
  heavier on the GPU would show it again.
* **The libretro core's Vulkan device has few extensions.** RetroArch lets the
  core create the device (`CreateVulkanDevice` in `libretro_vk.cpp`), and it
  enables only swapchain, image format list, external host memory, tooling
  info and custom border colour. The renderer then finds no function pointers
  for extended dynamic state or timeline semaphores and goes without
  ("disabling" in the log), so each shader pair needs a pipeline per fixed
  state, where GammaOS on Mali makes cull, depth, stencil and blend dynamic:
  more pipelines to build and cache. It also logs "Enabling extension:
  VK_EXT_index_type_uint8" and uses 8-bit indices on a device that never
  enabled it; Arm's driver takes them.
* **A newer azahar-nano** means a new `azahar-patch-000`: the diff of their
  tree against the 2126.1.2 tag with its submodules, made as its header says,
  then 002-005 checked on top.
* **At 600 MHz**, a CPU cap used only for measuring, every build (2126.2 too)
  stops drawing about a minute into Super Mario 3D Land. Not seen at 816 MHz
  and up.

## Build: what still runs under qemu (2026-10-21)

ARMSX2 and Azahar compile with the amd64 build of the chroot's clang now
(BUILDING.md, "Compilers that run natively in the chroot"); Azahar's core went
from 573 minutes to 11 with the same code. The bootstrap and the dependency
stage, nearly four hours, come from a copy when nothing they are made of has
changed (BUILDING.md, "The chroot from the cache"). Left under qemu, largest
first, with the times of the 2026-10-19 build:

* **cleanup_filesystem.sh**, 2 h 6 min. Most of it goes to the loops over
  `needed_packages*.txt` that put back what the removal of the dev packages
  took: a dpkg -s and an `apt-mark manual` for each line, each a start of apt
  under qemu. One `dpkg-query` and one `apt-mark` for each list would leave the
  installs alone.
* **The 32-bit chroot**, 1 h 13 min: `setup_arkbuild32` debootstraps it and
  runs `build_deps.sh 32` and SDL2 in it on every build. It is only for
  building; a copy kept as the 64-bit one is would do.
* **Recipes that build with gcc.** Debian's gcc-14-aarch64-linux-gnu is the
  same compiler built as a cross compiler; whether its output matches the
  native gcc's has to be checked as Azahar's was, component by component.
* **cmake and ninja themselves**: Azahar's configure took 5 minutes under qemu.
  Kodi's 71 addons spent most of a 43-hour build there (KNOWN-ISSUES); it is
  cached, so this matters only when it has to be built again.

## PS2: the GPU gets the heat; what else was tried (2026-10-22)

Measured as in the next section (fps between fixed frames, builds in turn, after a
reboot), on the charger at 99%, the SoC at 67-81 C: Jak and Daxter's intro (frames
300-1850) and God of War's demo resumed from the owner's savestate on the ship
(Continue pressed at 15 s, frames 600-2000).

**Where the time goes** (`perf`, the recipe's build with a JIT perf map):
- Jak's intro waits on the EE thread: 92% of a core, half of it JIT; `spu2Mix` is
  15.6% of the thread, all IOP and SPU2 work about a third. GS is next (58-92%).
  Both run 0.44-0.47 instructions a cycle with 4-5 million L2 refills a second:
  they wait on memory.
- God of War waits on the GPU: 80-93% busy, while the thermal governor
  (`power_allocator`, its trip at 75 C) holds it at 300-900 MHz, mostly 400-700,
  and the CPU stays near 2 GHz.

**Kept: `gpu-cpucap`** (`scripts/`, started by perfmax for every game under the
performance and overclock governors, stopped by perfnorm). The CPU and the GPU
share one thermal budget. With the CPU capped at 1608 MHz, God of War's GPU
stayed at 900 MHz and the SoC at 74 C: 28.36 fps against 25.33 (+12%); the same
cap cost Jak's intro 11% (31.06 against 34.89), where the GPU is 30% busy at 900
MHz. So the cap follows the GPU: every 2 s the CPU's limit goes a step down while
the GPU is 80% busy or more and the thermal governor holds it (its devfreq cooling
device in a state above 0), and a step up while the GPU is under 60% busy or the
SoC is 5 C under the first trip. A CPU taken too low starves the GPU, whose load
then falls and stops the steps, so how far it goes is found on the device and in
the room, down to 1200 MHz at the most; the CPU's top (2208 MHz under overclock)
is put back when the game ends, before perfoc takes boost away. The top comes
from `cpuinfo_max_freq`: `scaling_max_freq` reads the thermal governor's limit
as well (policy->max on 5.10), so a game started on a hot device would have
taken the held frequency for the top and kept it after the game.
- GammaOS ported it (Android, same kernel) and measured Minecraft on a hot
  console (78-83 C), four ABBA pairs of 3-minute windows: under its "max" mode
  32.6 fps against 29.8 (+9%, every pair), the GPU at 835 MHz on average
  against 472; under schedutil 33.8 against 33.6, no difference (that scene
  waits on its main CPU thread). It runs there by default in Normal, Max and
  Overclock, and replaced the fixed 1416 MHz "3D Games" mode.
- Charging, its first version (a 1608 MHz floor, the PS2 launcher only), two
  rounds: God of War 28.02 and 28.19 against 27.03 and 24.96; Jak 34.69 and 34.60
  against 34.02 and 34.67, its limit untouched.
- On a full battery (no charging current, no throttling but in God of War's
  heaviest moments), two rounds each:

| Scene | performance | overclock | performance + cap | overclock + cap |
|---|---|---|---|---|
| God of War, frames 600-2000 | 28.91, 27.58 | 29.51, 29.28 | 28.68, 28.23 | 29.27, 28.92 |
| Jak's intro, frames 300-1850 | 34.38, 34.99 | 35.80, 35.66 | 34.23, 34.63 | 35.19, 35.98 |
| Doom 3 (the port), arrival scene | 11.38, 11.43 | 12.28, 12.26 | 11.43, 11.40 | 12.26, 12.23 |

  The cap took God of War's CPU to 1800-1608 MHz under performance and left the
  others alone: no change either way when cool. Overclock gives 3-4% in the PS2
  games and 8% in Doom 3, which waits on the GPU (1000 MHz there); under its trips
  (83/93 C) the GPU was not held, and the cap stayed at 2208.
- Doom 3 is measured on its first level (`+map game/mars_city1`), whose arrival
  scene runs on the game's clock: fps over 90 s from 5 s after the level's load.
  Its timedemo cannot be used: dhewm3 stops `demo1` with "Bad render demo token".
- The devfreq `max_freq` is the governor's limit while it throttles, so the cap
  asks the cooling device instead: one read of `max_freq` at a hot start would
  take the held frequency for the GPU's top.

**Kept: the masked GS memory clears prefetch a kilobyte ahead**
(`pcsx2-0003`). In God of War the function fell from 3.9% to 2.8% of the
samples; clearing a 640x448 frame out of the caches on the device: 468 us
against 617 (-24%), 2 and 4 KB ahead the same, `PRFM PSTL1STRM` -11%, storing
the three low bytes of each 24-bit pixel without loading (ST3 lane stores)
+37%. The memory written is the same; the frame rates do not show it (God of
War waits on the GPU), but nothing gets slower.

**Tried, not kept** (the change against the same build without it):

| Change | Jak's intro | God of War |
|---|---|---|
| ARMSX2's IOP thread, forced on four cores | +0.8% | about -4% |
| the same, a 2 us idle watch, the largest lag | +1.3% | about -4% |
| the same, asleep until the EE is half the lag ahead | +0.7% | about -5% |
| GS multi-threading (`GSBackThreadMode = 1`) | -1.3% | -1% |
| transparent huge pages (a 5.10.226-thp kernel, `always`, shmem too) | +1.3% | -1.4% |

- The IOP thread watches the EE's watermark for 500 us before it sleeps, and the
  EE publishes every few: 64% of a core, taken from GS, MTVU and Mali's thread,
  and from the GPU's share of the heat. In God of War, which streams from the
  disc through the IOP, the EE also waits on it.
- Huge pages were in use (250 MB anonymous, GS memory's 4 MB of shmem): TLB
  misses are not what costs. The image's kernel config is unchanged.
- `spu2Mix` is flat: all 48 voices every sample.
- DDR runs at its top, 928 MHz, during games already (perfmax).
- ARMSX2's **AutoTune** (on by default, off for these measurements) has the IOP
  thread and GS multi-threading among its levers, and keeps one only where it
  measured a gain.

Left:
* **`gpu-cpucap` was measured on the RG52 Mini alone**, and in PS2 games and
  Doom 3. Dolphin's ND Demo waits on the CPU (the GPU 45% busy at 900 MHz), so
  the cap does nothing there.
* **`pcsx2-0003` changed `ClearGSLocalMemory`**, so the profile no longer fits
  it and clang builds it without; retraining would put that back.
* **`spu2Mix` runs every voice every sample**, stopped ones too (their addresses
  still move and can raise IRQs). A faster path for stopped voices has to keep
  that timing exact.

## PS2: ARMSX2 with a profile and ThinLTO (2026-10-21)

ARMSX2 replaced the old PCSX2 fork (KNOWN-ISSUES). `build_pcsx2sa.sh` builds
it with clang 19, a profile trained here (Jak and Daxter's intro, its menus,
the BIOS screens, and since 2026-10-21 the owner's play, below) and
`LTO_PCSX2_CORE`, ARMSX2's switch for ThinLTO of the
core. Measured as in the next section: fps over frames 300-1850 of the PAL
intro, the SDL frontend on Vulkan, volume 0, ES stopped, and ARMSX2's AutoTune
off (it changes settings while the game runs). Each series rebooted first and
ran its builds in turn, three rounds; the base is ARMSX2 with the old recipe's
flags (`-march=armv8-a -moutline-atomics -O3`) and no profile.

| Build: the base flags and | Series 1 | 2 | 3 | 4 |
|---|---|---|---|---|
| nothing (base) | 31.59 | 31.29 | 31.54 | 31.49 |
| the profile | 33.23 | | | |
| the profile, `-mcpu=cortex-a53` | 33.98 | 33.75 | 33.70 | 33.30 |
| **the profile, ThinLTO (the recipe)** | | **34.28** | **34.06** | **34.09** |
| the profile, ThinLTO, `-mcpu` | 33.95 | | | |
| ThinLTO | | 31.96 | | |
| ThinLTO, `-mcpu` | 31.90 | | | |
| the IOP thread forced on | | 30.58 | | |
| the profile, `-mcpu`, `-mno-outline-atomics` | | | 33.70 | |
| the same, `-fomit-frame-pointer` | | | 33.76 | |
| the profile, ThinLTO, `-mno-outline-atomics -fomit-frame-pointer` | | | | 34.05 |
| the same, `-mcpu` | | | | 33.98 |
| the profile, `-mcpu`, SPU2 `LightweightMode` | | | 34.13 | |

The recipe's build is 8.6% faster than the base (34.1 against 31.4); the
profile alone gives 7%, ThinLTO without it 1.5-2%. Runs of one build spread
by 1-2%.
- **`-mcpu=cortex-a53`** gains nothing with the profile and LTO; without a
  profile it lost 2.4%. `-mno-outline-atomics` (the A53 has no LSE, so every
  atomic goes through a helper that checks for it) and
  `-fomit-frame-pointer` changed nothing measurable either.
- **The IOP thread** (forced on in a test build; ARMSX2 turns it on only with
  six cores or more) costs 2% on four: it takes a core from the EE, GS and
  MTVU threads.
- **`LightweightMode`** (`[SPU2/Output]`, skips the reverb) gained 1.3% over
  the same build in the same series, within the spread, and changes the
  sound. Not set.
- **Where the time goes** (`perf`, 30 s of the intro, the profile build): the
  EE thread 40% of the busy samples, GS 28%, MTVU 12%, Mali's driver thread
  9%. About half the EE thread is ARMSX2's own code, and 39% of that is audio
  (`spu2Mix` 25%, reverb 6%, TimeStretch 4%). In GS: vertex kicks 13%,
  `GSState::Transfer` 13%, `GSRendererHW::Draw` 10%, and about 12% in the
  software rasteriser, which the GameIndex's `cpuSpriteRenderBW: 4` for Jak
  asks for (a correctness fix, kept).
- **Hot device.** It was on the charger: the SoC at 80-82 C during runs, the
  GPU held at its lowest step by the thermal governor and the CPU at times at
  1608 MHz. The absolute numbers belong to that; the builds ran in turn, so
  the differences hold.
- **Off the training.** A savestate in Jak and Daxter's opening cutscene
  (after New Game, in the game engine; `armsx2-sdl --state-from-file`
  resumes it), frames 100-800, three rounds: base 21.29, the profile and
  `-mcpu` 23.84 (+12.0%), the recipe's build 24.48 (+15.0%); over frames
  100-1500, which the first base run after the reboot fell short of, +11%
  and +14%. The profile helps more here than on the intro it was trained
  on. The cutscene is heavier than the intro (21-24 fps).
- **Presses from a script have to be written again while held.** The
  joystick driver polls B, X, Y and the d-pad and reports their real state
  every 20 ms, so a press written into its evdev node (as rg52remote does)
  is released again within 6-20 ms; A and Start it leaves alone. ARMSX2 saw
  some of those short presses and Jak none, so at first the d-pad, Select+X
  and Select+R1 seemed dead. Written again every 3 ms while held, they work:
  the pause menu (`pcsx2-0001`) opens on ARMSX2 started from ES, stays, and
  Resume goes back to the game.
- **The owner's play in the profile** (2026-10-21). An instrumented build
  (`-fprofile-generate`, the same tree at `/home/ark/armsx2`) was
  bind-mounted over `/opt/pcsx2/bin/armsx2-sdl` behind a script that runs it
  under another name: killer_daemon's hotkey sends `pkill` and at once
  `kill -9` to what `pidof` still finds by that name, and a profile is
  written only on a clean exit, so the script passes the SIGTERM on and
  waits. The owner played Jak and Daxter, God of War's demo, Burnout 3's
  demo and the Sopranos disc (its BIOS screen, a minute and a half). Merged
  with `-weighted-input` so that the old profile, Jak, God of War and
  Burnout have about the same total count each (17, 10, 26, 34; Sopranos 10,
  its own size). The core is 340 KB larger with it. Three rounds of each in
  turn after a reboot, old profile against new: Jak's intro (300-1850)
  34.57 and 34.31, Jak's opening cutscene (100-1500) 24.86 and 24.79, God of
  War on the ship from the owner's savestate (600-2000) 26.25 and 26.36: all
  within the spread. What other games run hot, the profile from Jak's intro
  covered already: the recompilers, GS, SPU2 and the VUs are ARMSX2's own
  code, and a game's own code runs as JIT output, which clang never sees.
  The new one is kept: it is trained on the owner's games and costs nothing
  measurable. The God of War savestate was made in the game's pause menu
  (50 fps, PAL's limit); the harness presses Cross 15 s after the launch.

Left:
* **The chroot's build was not measured.** The recipe ran in the arm64
  chroot on 2026-10-21 with the amd64 clang (`xtool.sh`), in 7 minutes.
  With the first profile its binary (clang 19.1.7) was 3.7 KB larger than
  the host cross-build of the same tree, profile and flags (19.1.1) that
  the numbers above are for.
* **Burnout 3's demo disc** opens from its `.bin` (the owner played it,
  2026-10-21), but from its `.cue`, which ES lists too, ARMSX2 exits at
  once (earlier: "Opening CDVD... VMManager::Initialize failed"). Not
  looked into.
* **No `patches.zip`.** ARMSX2 logs "Failed to open patches.zip. Built-in game
  patches are not available": PCSX2's per-game patches (pcsx2_patches) are a
  separate download, not in the source, and the old fork's build lacked them
  too. GameIndex.yaml's fixes do apply.

## Heavy emulators: compiler flags measured, none kept (1.3, 2026-10-20)

Measured on the 1.3 test build (OTA from 1.1), volume at 0, no input, ES
stopped. Frames are counted by the kernel (ftrace `drm_vblank_event_delivered`,
one per flip of GL, RetroArch KMS or Mali's Vulkan display alike); it matched
Dolphin's own counter.

| Game | Emulator | FPS | Busiest thread |
|---|---|---|---|
| PS2 Jak and Daxter (PAL), intro | PCSX2 | 42-48, 17-18 in its heaviest part | EE 95% |
| GC ND Demo | Dolphin | 40-41 | CPU 86%, video 76% |
| PSP FF Anniversary | PPSSPP | 60 | 46% |
| DC Crazy Taxi | flycast | 60 | 67% |
| Atomiswave kov7sprt, attract | flycast | 60 (30 on its title) | 79% |
| N64 AeroGauge | RetroArch32 parallel_n64 | 59 | 55% |

Only PS2 and GameCube run below full speed. `perf` (linux-perf from Debian
installed on the test device, not in the image) splits them:
- **PCSX2:** the EE thread is about half its own compiled code and half JIT.
  The compiled half is flat: the top function, `spu2Mix`, has 4.6%.
- **Dolphin:** the CPU thread, which holds the frame rate, is about 90% JIT.

**PCSX2 builds**, against the image's (gcc 14, `-O3 -march=armv8-a
-moutline-atomics`), in fps over frames 300-1850 of the intro:

| Build | Difference from the image |
|---|---|
| clang 18, same flags | -3% |
| clang + ThinLTO | -2% |
| clang + ThinLTO + `-mcpu=cortex-a53` | -1% |
| clang + full LTO + `-mcpu=cortex-a53` | 0% |
| clang + `-mcpu=cortex-a53` | -4% |
| clang `-O2` | -5% |
| gcc 14 + `-mcpu=cortex-a53` | -3% |
| gcc 14 full LTO | starts and exits at once (below) |

Spread between runs of one build is about 1.5%.
- **gcc LTO** links only with `common/FastJmp.cpp` built without LTO, because
  GCC LTO drops the symbols of its top-level asm. The binary then exits at start
  without a line of log. Not pursued, since clang's LTO gained nothing.
- **How it was measured.** Fps averaged over a wall-clock window cannot compare
  builds on a scripted intro: the faster one reaches a heavier part sooner, and
  a run at 1.6 GHz scored the same as at 2.0. Fps between fixed frame numbers
  of the deterministic intro does see the clock: -17% for -20% of it.
- **Thermal.** Runs go back to back only after the SoC cools below 62 C. The
  thermal governor holds 75 C, and a warm device lost 3% within an hour.

**Dolphin** is built with LTO already (`ENABLE_LTO=ON` in its recipe). The same
build with `-mcpu=cortex-a53` added ran the ND Demo at 41.0 fps against the
image's 41.5 (two interleaved runs each, spread about 1%): no gain either.

**Decision: no flag changes in the build scripts.** On the in-order A53 these
emulators wait on memory and JIT code, and the compiler does not reach either.
PGO stays the one untried option for them. It needs a training run in real
gameplay with the owner, and the flat profile leaves it little to work on.
Azahar (3DS) got it: a profile trained here took azahar-nano from 24.7 fps to
30 (above; the GPU's limit then, half speed, until GammaOS's settings). So did PS2, with ARMSX2 in place of the old fork:
the profile and ThinLTO gave it 8.6% on the intro (above).

## Battery in sleep (2026-10-19)

Sleep is deep now, the black screensaver ends in sleep on battery, two hours
asleep on battery end in a power-off, and the cable no longer wakes the device
for good (KNOWN-ISSUES). Left:

* **~42 mA in deep sleep**, about 4.5 days from full; mostly the board
  itself. GammaOS (Android 14) on the same unit, measured the same way on
  2026-10-19: 37-38 mA in deep sleep, Wi-Fi on or off within 1 mA, and its DT
  has the same regulator states in suspend as ours (on: vcc_ddr, vcc_3v3,
  vcca1v8_pmu, vdda0v9_pmu, vcc3v3_pmu; `rockchip-suspend` disabled in both).
  The 4-5 mA left between the two (about 12 %) is small; if it is worth
  chasing, compare what the drivers leave on: the pwm-fan's `fan-vcc` GPIO
  rail (no state-mem), the stick-RGB LED MCU, Bluetooth (off in the Android
  run), the USB-C controller (husb311).

## Revision A black screen: fixed — decide whether panel-kick can go

What breaks the panel is known (KNOWN-ISSUES): switched off and on again too
quickly, with no delays in its exit sequence, it stays black. Fixed in the
kernel by the stock exit-sequence delays (`23506d78f`) and a 500 ms minimum
DSI off time (`7483a4f83`, from the Android port). panel-kick, which cured
revision A by keeping the display off for about 0.24 s, stays until that is
confirmed. In order:

The fix was confirmed on a revision A unit (v10032026-test, 2026-10-04) and
is in the v09292026 assets. What is left is whether panel-kick is still needed:

1. Test on revision A with `/boot/panel-kick-off`:
   if the picture comes up by itself, panel-kick can go. `link off … waiting`
   in `dmesg` tells whether a fast cycle happened.
2. If it still goes black with `panel-kick-off`, the cycle is not the cause.
   The other candidates: a failed warm takeover of the U-Boot link on the
   first enable, where nothing was switched off before and the off-time wait
   cannot act; or rk915 power-cycling the Wi-Fi rail around the time the
   display first comes up. A `dmesg` from the unit decides between them.
3. Does v09162026 also go black on revision A? Still unasked, and it says
   whether something between the releases introduced it.

## HDMI: find the real connector name, then make detection follow the cable

HDMI does nothing on the device. KNOWN-ISSUES has the evidence that the kernel
side matches the Android image where HDMI works, so this is dArkOS-side work.
In order, and the first step is one command:

1. **Ask the card what its connectors are called.** On the device:

       ls /sys/class/drm/
       for c in /sys/class/drm/card0-*/status; do echo "$c $(cat $c)"; done

   HDMI arrives through `route-rgb` and the RK628, so expect something other
   than `HDMI-A-1`. Whatever the name is, it has to replace the hardcoded one
   in `scripts/rk3562/hdmi-test.sh` and in `KCMD_VIDEO` in
   `finishing_touches-rk3562.sh`, which currently says
   `video=HDMI-A-1:1280x720@60`.

2. **Read the connector index rather than assuming it.** The script writes
   `drmConn=1` for HDMI and `0` for the panel. The index EmulationStation and
   RetroArch expect is a position on the card, so derive it from the same
   enumeration as step 1 instead of hardcoding.

3. **Make it run on hotplug, not only at boot.** It is on `@reboot` in crontab
   today. There is already a udev rule firing on DRM events —
   `audio/99-hdmi-audio.rules`, `SUBSYSTEM=="drm"` — which calls
   `audio-switch.sh`. Call the display side from the same place so plugging a
   cable does something.

4. **Drop the `2>/dev/null` while debugging.** It is what turned "that path
   does not exist" into "no display connected", which is why this looked like a
   hardware problem for a while.

Worth knowing before touching the kernel: `rockchip_rgb` binds without the RGB
output if the bridge has not answered by the time initcalls finish, so if the
connector is genuinely absent from `/sys/class/drm`, check `dmesg` for the rgb
and rk628 probe order before concluding anything about the hardware.

## Open questions on the device

* **Is the speaker click gone?** `spk-mute-delay-ms = <100>` is in the device
  tree and the GPIO reads `out lo` in silence, which is necessary but does not
  prove the click went away. Needs an ear.
* **Does a USB mouse do anything?** It enumerates and binds `hid-generic`, and
  an input node appears, but no cursor is visible. EmulationStation may simply
  not use one — that would be expected, not a fault.
* **`OF: graph: no port node found`** in the husb311 connector. Role switching
  works anyway. `backup/dtb/live.dtb` from the vendor's EmuELEC has the
  complete port/endpoint graph if this is ever worth tightening.

## Decisions nobody has made yet

* **Charging parameters.** The device tree carries the numbers from the
  Android port (4300/300/4654/78/2800); the vendor's own `live.dtb` says
  4280/150/4642/69/3400. The difference that matters is `power_off_thresd`,
  2800 against 3400 mV — the vendor stops much earlier. Deep discharge is
  harder on a cell than a shorter runtime is on a user, so the vendor value is
  probably right, but it is a battery decision and should be made on purpose.
* **Thermal headroom.** Raising `trip-point-1` or `sustainable-power` would buy
  measurable performance and has been deliberately refused; PERFORMANCE.md
  explains why and what to do instead. Open only in the sense that a heatsink
  would change the answer.
* **`CONFIG_ZRAM_WRITEBACK`.** Compiled in, unused. It is the other way to
  spend the eMMC partition — see PERFORMANCE.md.

## Repairs, each its own small job

None open. The three bit-rotted patches are fixed — KNOWN-ISSUES.md says how.

The seven PortMaster compatibility libraries that used to 404 are fixed:
upstream found them on snapshot.debian.org and this fork took the change. All
twenty-one URLs answer now.

Done since this list was written: Yabasanshiro, whose upstream repository is
gone, builds from a pinned commit of a surviving fork; freej2me-plus needed a
java level a current JDK still accepts and a jar name that had been renamed
under it; Kodi's two patch conflicts are resolved and built; Hypseus Singe and
GameTank build since the upstream merge of 2026-10-05 brought their rewritten
patches; and ECWolf builds again (2026-10-15).

## RetroArch fixes after v1.22.2 that need porting by hand

Releases 1.1 and 1.2 carry upstream's fixes that apply as they are
(`retroarch-patch-0021`, `-0022`; 0022 with the zip fix of 1.2). These are in v1.22.2 too, but master
rewrote the code around them, so each needs a small port. Recheck whether a
tag newer than v1.22.2 has appeared first: moving to it would replace all of
this.

* **HTTP client against a hostile server** (66155ff344, eb86df008d). With
  both Content-Length and chunked, the chunk parser reads wild. A huge chunk
  length or a negative Content-Length gets through, and `realloc` results go
  unchecked. The updater talks plain http, so anyone on the network can be
  the server. Port: `response->len = 0` on entering `P_BODY_CHUNKLEN`,
  Content-Length as `size_t` capped at 256 MiB, a capped chunk length, and
  checked reallocs.
* **Cloud sync path traversal** (4ee62a575f, its `cloud_sync` part). A
  hostile server writes outside the sync directory. Matters only if cloud
  sync is turned on.
* **Network commands** (fa49a43dc2). `READ_CORE_RAM` with a large count
  wraps the allocation size, and one UDP packet to port 55355 overflows the
  heap. Off unless `network_cmd_enable`, which Quick Mode turns on; since 0023 the socket listens on 127.0.0.1 only, so it is local. Port:
  cap the byte count at 16 KiB.
* **Saves and config survive a power cut** (250e2d1b48, bb583943fd,
  b867454de3 with d20c1a344e, edb8facc19, 163ef5e698). Write a temporary
  file and rename it, not in place.
* **ALSA can wait forever** (48394abbb2, 6abd13a0d1). Use a finite timeout
  for `snd_pcm_wait`.
* Smaller, clean or nearly so:
  * 9a19e7a94d: netplay client number from the host, one hunk by hand;
  * c7a261ce54: ozone selection past a shrunk playlist;
  * 3eedad0aa5: autosave thread after core deinit;
  * db91cdbf89: gl2.c GLES 3 context for cores;
  * e092c37228, d5e598aedc, f85119508e;
  * 44a041cf96: decompress use-after-free, by hand.

## Worth sending upstream

Five build-system defects were fixed in this fork. Three of them have nothing
to do with this hardware and would help anyone building dArkOS, so they belong
in a pull request to bmdhacks rather than only here:

| | |
|---|---|
| `utils.sh` | `install_package`'s `updateapt` flag is global, so the 32-bit chroot never gets contrib/non-free and never runs `apt update` |
| `setup_partition-rk3562.sh` | the result of `mount` was not checked — a failed mount let the build write past the image for hours |
| `build_retroarch.sh` | `while true` with no attempt counter, which turns one broken patch into a build that spins overnight |
| `utils.sh` | `protect_package` reports `"$${protectedlib} has been marked..."` — `$$` is the shell PID, so every line reads `531{protectedlib}` and never names the package |

The other two — the absolute toolchain path and the 32-bit chroot cloning
upstream's core builds instead of the local fork — only bite in this fork's
layout.

### gl4es: render targets left with a mipmap filter

The report is drafted in `gl4es-fix/UPSTREAM.md`, for an issue at
ptitSeb/gl4es. It is not posted yet: the owner decides when. It covers two
things:
- render-target textures keep `GL_NEAREST_MIPMAP_LINEAR` on the GLES side;
- `SAMPLER[n]` sized by nested macros comes out too small.

Before posting:
- check another gl4es port with the 1.1 image, so that the report can say
  whether more than Don't Starve is affected;
- if possible, build gl4es with one of the two suspected spots changed, and
  name the cause instead of a suspicion.

Once gl4es is fixed upstream and ports carry the new build, `gl4es-fix/` and
its line in `portmaster-e2big.sh` can go.

## The dependency stage costs two hours of emulation, not of work

Measured while resuming the 2026-09-29 build, where every package was already
installed and the stage still took the same order of time: about 34 seconds per
entry in `needed_packages.txt`, against 41 seconds when they were being
installed for real. Almost none of that is installing anything.

Each entry of that list runs two separate commands inside the arm64 chroot, and
every one of them is a full process start under qemu:

* `install_package` -> `chroot Arkbuild dpkg -s <pkg>:arm64`, purely a question
* `protect_package` -> `chroot Arkbuild apt-mark manual <pkg>`

`needed_dev_packages.txt` runs at half that, near 17 seconds, because its
`protect_package` call is commented out — which is the measurement that says
where the time goes.

Two ways out, both straightforward:

* Batch. `apt-mark manual` and `dpkg -s` both take any number of package names,
  so the whole list is one chroot invocation instead of 101 or 202.
* Ask on the host. Whether a package is installed is a question about
  `Arkbuild/var/lib/dpkg/status`, readable from outside without emulating
  anything.

Batching is the smaller change and gets nearly all of it, and it is upstream's
code rather than ours.

The saving is twice what the paragraph above assumed, because the lists are
walked a second time. After `cleanup_filesystem.sh` purges the build
dependencies it reinstalls what the finished system needs by reading the same
files again: `needed_packages32.txt` (27), `needed_packages.txt` (101) and
`bluetooth_needed_packages.txt` (17) — 145 entries, each with the same
`dpkg -s` plus `apt-mark manual` pair inside the chroot. Measured on the
2026-10-01 build, that one step ran from 00:12 to roughly 02:00 with nothing
to install: every package was already present. `kodi_needed_dev_packages.txt`
is skipped there, but only by accident of a chipset test that reads `*3566*`
and so never matches this board.

So the whole build pays the per-package emulation cost twice, in `build_deps.sh`
and again in `cleanup_filesystem.sh`. Batching both would return roughly two
and a half hours per build.
