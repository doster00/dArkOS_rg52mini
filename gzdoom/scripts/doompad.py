#!/usr/bin/env python3
# doompad.py <ini>... - the rk3562-joystick (RG52 Mini, RG43H) in GZDoom and LZDoom inis, in place.
#
# The rk3562-joystick reports, through SDL's joystick API: axes 0/1 the left stick, 2 L2,
# 3/4 the right stick, 5 R2; buttons 0 A (right), 1 B (bottom), 2 Y (left), 3 X (top),
# 4 L1, 5 R1, 8 Select, 9 Start, 10 Home, 11 L3, 12 R3, 13-16 the D-pad (up, down, left,
# right), 17 Back. The inis came from the rk3566 one, whose pad has the right stick on axes
# 2/3: here L2, at rest at one end of its range, turned the player all the time.
#
# [Joy:JS:0]: L2 and R2 drive nothing, the right stick turns (3) and looks (4) with the
# scale and dead zone the rk3566 file gave its right stick.
# Every [<game>.Bindings]: the main menu on Start (it was on D-pad up), the automap also on
# Select. [Doom.Bindings] also: B jumps, D-pad up/down change weapon (they were on Home,
# which ogage takes, and L3, which closes by itself on this console), D-pad right crouches;
# nothing on Home, L3 or the buttons 6/7 the pad does not have.
import re, sys

JOY = {"Axis2map": "-1", "Axis5map": "-1",
       "Axis3map": "0", "Axis4map": "1"}

def fix(text):
    out, sec, seen = [], None, {}
    lines = text.split("\n")
    # the right stick's dead zones and scales: from the old axes 2 (turn) and 3 (look)
    old = {}
    cur = None
    for l in lines:
        m = re.match(r"^\[(.*)\]$", l)
        if m:
            cur = m.group(1)
        elif cur == "Joy:JS:0" and "=" in l:
            k, v = l.split("=", 1)
            old[k] = v
    joy = dict(JOY)
    for src, dst in (("2", "3"), ("3", "4")):
        for what in ("deadzone", "scale"):
            if "Axis%s%s" % (src, what) in old:
                joy["Axis%s%s" % (dst, what)] = old["Axis%s%s" % (src, what)]
    drop_in_joy = {"Axis2deadzone", "Axis2scale"}
    def flush(section, body):
        if section == "Joy:JS:0":
            if old.get("Axis2map") != "0":
                return body   # not the rk3566 layout (already moved, or the user's own)
            keep = [l for l in body if "=" not in l or (l.split("=", 1)[0] not in joy and l.split("=", 1)[0] not in drop_in_joy)]
            while keep and keep[-1] == "":
                keep.pop()
            return keep + ["%s=%s" % kv for kv in sorted(joy.items())] + [""]
        if section and section.endswith(".Bindings"):
            b = {}
            order = []
            for l in body:
                if "=" in l:
                    k, v = l.split("=", 1)
                    b[k] = v
                    order.append(k)
            if b.get("Joy14") == "menu_main":
                del b["Joy14"]
                b["Joy10"] = "menu_main"
                b.setdefault("Joy9", "togglemap")
            if section == "Doom.Bindings":
                for k in ("Joy7", "Joy8", "Joy11", "Joy12", "Joy18"):
                    b.pop(k, None)
                b["Joy2"] = "+jump"
                b["Joy14"] = "weapnext"
                b["Joy15"] = "weapprev"
                b["Joy17"] = "+crouch"
            keys = sorted(b, key=lambda k: (not k.startswith("Joy"), int(k[3:]) if k[3:].isdigit() else 0, k))
            return ["%s=%s" % (k, b[k]) for k in keys] + [""]
        return body
    body = []
    for l in lines:
        m = re.match(r"^\[(.*)\]$", l)
        if m:
            out += flush(sec, body)
            out.append(l)
            sec, body = m.group(1), []
        else:
            body.append(l)
    out += flush(sec, body)
    return "\n".join(out)

for p in sys.argv[1:]:
    try:
        t = open(p, encoding="utf-8", errors="surrogateescape").read()
    except OSError:
        continue
    n = fix(t)
    if n != t:
        open(p, "w", encoding="utf-8", errors="surrogateescape").write(n)
        print("fixed", p)
