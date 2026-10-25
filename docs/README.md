# RG52 Mini port notes

Working notes for this fork of [bmdhacks/dArkOS_rg52mini](https://github.com/bmdhacks/dArkOS_rg52mini),
which is itself a fork of [christianhaitian/dArkOS](https://github.com/christianhaitian/dArkOS).

They exist so the next person — or the next AI session — starts from what is
already known instead of rediscovering it. Where something was measured on
hardware it says so; where it is inference it says that too.

| | |
|---|---|
| [BUILDING.md](BUILDING.md) | environment, the WSL story, how to run a build |
| [HARDWARE.md](HARDWARE.md) | the kernel patches and what they fixed |
| [KNOWN-ISSUES.md](KNOWN-ISSUES.md) | what is missing from the image and why |
| [OTA.md](OTA.md) | updates over the air from 1.1 on, and how a release is made |
| [PERFORMANCE.md](PERFORMANCE.md) | what actually makes emulators faster here |
| [TODO.md](TODO.md) | what is next, and what is waiting on the next build |

## The device

    SoC       Rockchip RK3562, 4x Cortex-A53 @ 2.0 GHz, ARMv8.0-A
    GPU       Mali-G52 (Bifrost), vendor blob g29p1
    RAM       2 GB
    Panel     DSI 720x1280 portrait, console rotated (fbcon=rotate:1)
    Wi-Fi/BT  AIC8800D80, one combo part over SDIO (mmc2)
    PMIC      RK817 — regulators, codec, charger, fuel gauge
    Type-C    HUSB311 (Hynetek) on i2c@ffa10000, address 0x4e
    eMMC      3.7 GB: uboot, trust, emuelec, swap(256M), STORAGE, eeroms
    Boot      from SD: GPT, p3 FAT32 with extlinux, Image, DTB, uInitrd

The chip is marked D40 but answers as D80 over SDIO (vid `0xC8A1`,
did `0x0082`), and only the D80 code path works.

## Repositories

This fork pins its own submodules, so a fresh clone reproduces a build without
any manual steps:

    mamaich/dArkOS_rg52mini
      kernel_rk3562      -> mamaich/kernel_rk3562        hardware patches
      rk3562_core_builds -> mamaich/rk3566_core_builds   Cortex-A53 build flags
      bootloader         -> bmdhacks/aislpc-bootloader-tool

Clone with `--recursive`. All three are https; an earlier `git@github.com:`
in `.gitmodules` meant submodules only resolved for people with an SSH key.

## State of the port

The current release is 1.2 (build 10182026, 2026-10-18); from 1.1 on, a card
updates over the air (OTA.md). 2026-09-16 was the first release of this fork.
What was checked on hardware in those first weeks:

| | |
|---|---|
| Wi-Fi | works |
| Bluetooth | works — `hci0 Type: Primary Bus: SDIO`, scanning finds devices |
| USB host | works — a USB mouse enumerates, HID binds, input node appears |
| Speaker | works, and `Playback Path` is `SPK` out of the box |
| Kodi | builds and runs, 21.3-Omega with 67 addons |
| Swap | zram 1.5 GB at priority 100, eMMC partition at 10, both active |
| Kernel modules | 6.3 MB, stripped of debug info (was 100 MB) |
| Bootloader | ours, with power-off, splash, charge animation and a console |
| Bluetooth gamepads | work — the HID gate had to be opened, see HARDWARE.md |
| Kernel | `Image` 32.9 MB; no OP-TEE, no dead GPU drivers, no unread debugging |

Bluetooth and USB host are the two things the upstream port cannot do. Both
come from the device tree and driver changes described in
[HARDWARE.md](HARDWARE.md).

New in 1.3, each with its section in [KNOWN-ISSUES.md](KNOWN-ISSUES.md):

| | |
|---|---|
| Nintendo 3DS | Azahar in RetroArch, with GammaOS's azahar-nano changes and a profile (PGO); Super Mario 3D Land at 60 fps |
| PS2 | ARMSX2 in place of bmdhacks' PCSX2 fork, with a profile and ThinLTO; Jak and Daxter draws right |
| Vulkan | Arm's driver or malisx2, chosen per program (`/etc/darkos/vulkan.conf`) or per system in ES; libmali is the default |
| Sleep | deep sleep instead of s2idle (~42 mA against ~185), power-off after two hours asleep on battery |

Built but never launched: freej2me-plus. It had been silently missing from
earlier images and now exists — whether it runs is another question.
Yabasanshiro was in the same state until 2026-10-24, when the one game tried
crashed within seconds, in a dynarec template for an instruction as common as
MOV.B; patches 12 and 13 of its recipe make it run (KNOWN-ISSUES.md).

Not verified: whether the speaker click on playback start and stop is gone.
The GPIO behaves correctly in silence, which is necessary and not sufficient;
only an ear settles it.
