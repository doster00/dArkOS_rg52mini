#!/usr/bin/env python3
"""Alias systems for ROM folders that other front ends name differently.

On a dual-boot card /roms is GammaOS's ROMs folder, laid out by its setup for
ES-DE: tg16, megacd, fbneo, pico8 ... where our EmulationStation reads
turbografx, segacd, arcade, pico-8/carts. Games put there are invisible here.

For each folder in ALIASES this adds a copy of the system that reads the
folder dArkOS uses (same command, emulators, extensions, platform, theme) with
the alias's path, and puts both in a group named after that system:
  <group>arcade</group>
Our EmulationStation (Emulationstation/patches-rk3562) shows such a group only
when two or more of its systems have games, under the main system's name and
in its place, each system a folder inside; otherwise each one is an ordinary
system, so a card without the alias folders looks as before.

Usage: es-aliases.py es_systems.cfg   (edits the file in place; running it
again changes nothing). Run by build_emulationstation-rk3562.sh.
"""
import re
import sys
import xml.etree.ElementTree as ET

# alias folder -> (path dArkOS reads, full name shown for the alias)
ALIASES = [
    ("fbneo",       "/roms/arcade",        "FinalBurn Neo"),
    ("fba",         "/roms/arcade",        "FinalBurn Alpha"),
    ("cps",         "/roms/arcade",        "Capcom Play System"),
    ("pico8",       "/roms/pico-8/carts",  "PICO-8"),
    ("megacd",      "/roms/segacd",        "Mega-CD"),
    ("megacdjp",    "/roms/segacd",        "Mega-CD (Japan)"),
    ("megadrivejp", "/roms/megadrive",     "Mega Drive (Japan)"),
    ("sega32xjp",   "/roms/sega32x",       "Super 32X (Japan)"),
    ("sega32xna",   "/roms/sega32x",       "Genesis 32X"),
    ("saturnjp",    "/roms/saturn",        "Saturn (Japan)"),
    ("snesna",      "/roms/snes",          "SNES (North America)"),
    ("tg16",        "/roms/turbografx",    "TurboGrafx-16"),
    ("tg-cd",       "/roms/turbografxcd",  "TurboGrafx-CD"),
    ("neogeocdjp",  "/roms/neogeocd",      "Neo Geo CD (Japan)"),
    ("atarixe",     "/roms/atarixegs",     "Atari XE"),
    ("colecovision", "/roms/coleco",       "ColecoVision"),
    ("pokemini",    "/roms/pokemonmini",   "Pokemon Mini"),
    ("plus4",       "/roms/c16",           "Commodore Plus/4"),
    ("amiga600",    "/roms/amiga",         "Amiga 600"),
    ("amiga1200",   "/roms/amiga",         "Amiga 1200"),
    ("msx1",        "/roms/msx",           "MSX1"),
    ("macintosh",   "/roms/vmac",          "Macintosh"),
    ("coco",        "/roms/coco3",         "Tandy Color Computer"),
    ("tanodragon",  "/roms/dragon32",      "Tano Dragon"),
    ("moto",        "/roms/thomson",       "Thomson MO/TO"),
    ("to8",         "/roms/thomson",       "Thomson TO8"),
    ("pc",          "/roms/dos",           "IBM PC"),
    ("laserdisc",   "/roms/daphne",        "LaserDisc"),
]

BLOCK = re.compile(r"[ \t]*<system>.*?</system>[ \t]*\n", re.S)


def tag(block, name):
    m = re.search(r"<%s>(.*?)</%s>" % (name, name), block, re.S)
    return m.group(1).strip() if m else None


def norm(path):
    return (path or "").strip().rstrip("/")


def set_tag(block, name, value):
    return re.sub(r"<%s>.*?</%s>" % (name, name),
                  lambda m: "<%s>%s</%s>" % (name, value, name), block, count=1, flags=re.S)


def add_group(block, group):
    if tag(block, "group") is not None:
        return set_tag(block, "group", group)
    indent = re.search(r"\n([ \t]*)<name>", block).group(1)
    return re.sub(r"\n([ \t]*)</system>", "\n%s<group>%s</group>\n\\1</system>" % (indent, group),
                  block, count=1)


def xml_text(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def main(cfg):
    text = open(cfg, encoding="utf-8").read()
    blocks = [(m.start(), m.end()) for m in BLOCK.finditer(text)]
    by_path, names = {}, set()
    for i, (a, b) in enumerate(blocks):
        blk = text[a:b]
        names.add(tag(blk, "name"))
        by_path.setdefault(norm(tag(blk, "path")), i)

    # new text of each main block, and the alias blocks that follow it
    new_main, extra = {}, {}
    added = []
    for alias, main_path, fullname in ALIASES:
        path = "/roms/" + alias
        if path in by_path or main_path not in by_path:
            continue          # already there (second run), or no such system here
        i = by_path[main_path]
        main_blk = new_main.get(i, text[blocks[i][0]:blocks[i][1]])
        group = tag(main_blk, "name")
        new_main[i] = add_group(main_blk, group)
        name = alias if alias not in names else alias + "_esde"
        names.add(name)
        blk = set_tag(new_main[i], "name", name)
        blk = set_tag(blk, "fullname", xml_text(fullname))
        blk = set_tag(blk, "path", path + "/")
        extra.setdefault(i, []).append(blk)
        added.append("%s -> %s" % (path, group))

    out, pos = [], 0
    for i, (a, b) in enumerate(blocks):
        out.append(text[pos:a])
        out.append(new_main.get(i, text[a:b]))
        out.extend(extra.get(i, []))
        pos = b
    out.append(text[pos:])
    result = "".join(out)
    ET.fromstring(result.encode("utf-8"))   # still well-formed, or stop here
    if result != text:
        open(cfg, "w", encoding="utf-8").write(result)
    print("es-aliases: %d alias systems added to %s" % (len(added), cfg))
    for a in added:
        print("  " + a)


if __name__ == "__main__":
    main(sys.argv[1])
