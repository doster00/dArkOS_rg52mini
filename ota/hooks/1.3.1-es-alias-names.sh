#!/bin/bash
# 1.3.1: an alias system whose full name is its main system's gets its folder after it, "PICO-8
# (pico8)", as scripts/rk3562/es-aliases.py now names them: EMULATOR SETTINGS listed both under
# one name. A device whose es_systems.cfg is the user's own copy (kept by the update, the image's
# beside it as es_systems.cfg.ota-new) gets the same names in it; the rest of the file stays. An
# untouched file is the image's already.
#
# Never fails the update. Changed files go to merged for a rollback.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
F=/etc/emulationstation/es_systems.cfg
[ -f "$F" ] || exit 0
python3 - "$F" <<'PY' || exit 0
import re, sys
import xml.etree.ElementTree as ET
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
blocks = list(re.finditer(r"<system>.*?</system>", s, re.S))
def tag(b, t):
    m = re.search(r"<%s>(.*?)</%s>" % (t, t), b, re.S)
    return m.group(1).strip() if m else None
full = {tag(m.group(0), "name"): tag(m.group(0), "fullname") for m in blocks}
out, pos, n = [], 0, 0
for m in blocks:
    b = m.group(0)
    name, group, fn = tag(b, "name"), tag(b, "group"), tag(b, "fullname")
    if group and fn and name != group and fn == full.get(group):
        alias = name[:-len("_esde")] if name.endswith("_esde") else name
        b = re.sub(r"<fullname>.*?</fullname>", lambda _: "<fullname>%s (%s)</fullname>" % (fn, alias),
                   b, count=1, flags=re.S)
        n += 1
    out += [s[pos:m.start()], b]
    pos = m.end()
out.append(s[pos:])
if not n:
    sys.exit(1)
r = "".join(out)
ET.fromstring(r.encode("utf-8"))
open(p, "w", encoding="utf-8").write(r)
PY
echo "$F" >> /var/lib/darkos-ota/merged
echo "  $F: alias names"
exit 0
