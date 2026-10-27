#!/usr/bin/env python3
"""What is new upstream of everything the RG52 Mini image builds or downloads.

    tools/upstream/check.py [--force] [--only NAME ...]

Run it before a full image build, at most once a day: within 20 hours of the
last run it only points at that run's report, unless --force. The versions we
use are read from the recipes themselves (components.json says where), GitHub
is asked through gh, and what was seen is kept in ~/.cache/darkos-upstream/, so
a branch the build follows shows what came since the last check. The report is
printed and saved there too.

Modes in components.json:
  tag     we pin a release tag; newer tags matching tag_regex are news
  commit  we pin a commit; commits on the branch after it, and a release tag
          (tag_regex) that contains it and more
  follow  the build takes a branch's head; commits since our last build (the
          cache key's commit, when there is one) or since the last check
  fork    our fork against its upstream: upstream commits we do not have
  page    a version scraped from a download page (version_regex)
  gitlab  a GitLab project's releases
  path    commits on a branch under a path, after our pinned commit
  frozen  kept old on purpose; listed, not checked
"""
import argparse
import concurrent.futures
import datetime
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
STATE_DIR = os.path.expanduser("~/.cache/darkos-upstream")
STATE = os.path.join(STATE_DIR, "state.json")
MIN_HOURS = 20
SHOW = 6            # commit titles shown per component


def gh(path, jq=None):
    cmd = ["gh", "api", path] + (["--jq", jq] if jq else [])
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if r.returncode != 0:
        err = (r.stderr or r.stdout).strip().splitlines()
        raise RuntimeError("gh api %s: %s" % (path, err[-1] if err else "failed"))
    return r.stdout


def gh_json(path):
    return json.loads(gh(path))


def natkey(s):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", s) if t]


def vkey(s):
    """Version digits only: release-2.1.4, v2.1.4 and 2.1.4 compare equal."""
    m = re.search(r"\d+(?:[._]\d+)*", s)
    return [int(x) for x in re.split(r"[._]", m.group(0))] if m else []


def read_pin(spec):
    path = os.path.join(ROOT, spec["file"])
    with open(path, "rb") as f:
        text = f.read().decode("latin-1")
    m = re.search(spec["regex"], text, re.M)
    if not m:
        raise RuntimeError("no pin in %s (/%s/)" % (spec["file"], spec["regex"]))
    return spec.get("format", "{}").format(m.group(1))


def tags(repo, regex):
    r = subprocess.run(["git", "ls-remote", "--tags", "--refs",
                        "https://github.com/%s.git" % repo],
                       capture_output=True, text=True, timeout=180)
    if r.returncode != 0:
        raise RuntimeError("git ls-remote %s failed" % repo)
    rx = re.compile(regex)
    names = [l.split("refs/tags/", 1)[1] for l in r.stdout.splitlines() if "refs/tags/" in l]
    return sorted((n for n in names if rx.search(n)), key=natkey)


def commit_date(repo, ref):
    return gh("repos/%s/commits/%s" % (repo, urllib.parse.quote(ref, safe="")),
              ".commit.committer.date").strip()[:10]


def default_branch(repo):
    return gh("repos/%s" % repo, ".default_branch").strip()


def branch_head(repo, branch):
    d = gh_json("repos/%s/branches/%s" % (repo, urllib.parse.quote(branch, safe="")))
    return d["commit"]["sha"], d["commit"]["commit"]["committer"]["date"][:10]


def compare(repo, base, head):
    """(ahead, behind, [(sha, date, title)...] newest last) of head against base."""
    d = gh_json("repos/%s/compare/%s...%s" % (repo, urllib.parse.quote(base, safe=""),
                                               urllib.parse.quote(head, safe=":")))
    commits = [(c["sha"][:9], c["commit"]["committer"]["date"][:10],
                c["commit"]["message"].split("\n", 1)[0][:100]) for c in d.get("commits", [])]
    return d["ahead_by"], d["behind_by"], commits


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "darkos-upstream-check"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode("utf-8", "replace")


def titles(commits):
    return ["%s %s %s" % c for c in commits[-SHOW:][::-1]]


def check(c, state):
    """One component: (group, headline, [detail lines], state to keep)."""
    mode, name = c["mode"], c["name"]
    seen = state.get(name, {})
    if mode == "frozen":
        return "frozen", c.get("note", ""), [], seen

    if mode == "fork":
        ahead, behind, commits = compare(c["repo"], c["branch"], c["upstream"])
        if ahead == 0:
            return "same", "nothing upstream that we lack", [], seen
        return "fork", "%d upstream commit(s) we do not have" % ahead, titles(commits), seen

    if mode == "tag":
        ours = read_pin(c["pin"])
        ts = tags(c["repo"], c["tag_regex"])
        newer = [t for t in ts if natkey(t) > natkey(ours)]
        if not newer:
            return "same", "%s is the newest release" % ours, [], {"latest": ours}
        latest = newer[-1]
        head = "%s -> %s (%s)" % (ours, latest, commit_date(c["repo"], latest))
        more = ["newer: " + ", ".join(newer[-8:])] if len(newer) > 1 else []
        new_since = "" if seen.get("latest") == latest else " [new since last check]"
        return "release", head + new_since, more, {"latest": latest}

    if mode == "commit":
        ours = read_pin(c["pin"])
        branch = c.get("branch") or default_branch(c["repo"])
        ahead, behind, commits = compare(c["repo"], ours, branch)
        lines, group, headline = [], "same", "at the head of %s" % branch
        if ahead:
            group = "commits"
            headline = "%d commit(s) on %s after %s (%s)" % (ahead, branch, ours[:9],
                                                            commit_date(c["repo"], ours))
            lines = titles(commits)
        latest_tag = None
        if c.get("tag_regex"):
            ts = tags(c["repo"], c["tag_regex"])
            if ts:
                latest_tag = ts[-1]
                ta, tb, _ = compare(c["repo"], ours, latest_tag)
                if ta and not tb:
                    group = "release"
                    headline = "release %s (%s) is %d commit(s) after our %s; %s" % (
                        latest_tag, commit_date(c["repo"], latest_tag), ta, ours[:9], headline)
                elif ta and tb:
                    lines.append("release %s is not a descendant of our pin" % latest_tag)
        new_since = ""
        if group != "same" and seen.get("head") != (commits[-1][0] if commits else ours):
            new_since = " [new since last check]"
        return group, headline + new_since, lines, {"head": commits[-1][0] if commits else ours,
                                                    "latest": latest_tag}

    if mode == "follow":
        branch = c.get("branch") or default_branch(c["repo"])
        sha, date = branch_head(c["repo"], branch)
        base, base_from = None, None
        if c.get("cache"):
            try:
                base, base_from = read_pin(c["cache"]), "our last build"
            except (OSError, RuntimeError):
                pass
        if not base and seen.get("head"):
            base, base_from = seen["head"], "the last check"
        keep = {"head": sha}
        extra = []
        if c.get("tag_regex"):
            ts = tags(c["repo"], c["tag_regex"])
            if ts:
                extra.append("latest release %s (%s)" % (ts[-1], commit_date(c["repo"], ts[-1])))
        if not base:
            return "first", "%s head %s (%s), first seen" % (branch, sha[:9], date), extra, keep
        if sha.startswith(base) or base.startswith(sha):
            return "same", "%s unchanged since %s (%s)" % (branch, base_from, date), extra, keep
        ahead, behind, commits = compare(c["repo"], base, sha)
        if not ahead:
            return "same", "%s unchanged since %s" % (branch, base_from), extra, keep
        return "moved", "%d commit(s) on %s since %s, head %s" % (ahead, branch, base_from, date), \
            titles(commits) + extra, keep

    if mode in ("page", "gitlab"):
        ours = read_pin(c["pin"])
        if mode == "page":
            found = re.findall(c["version_regex"], fetch(c["url"]))
        else:
            project = urllib.parse.quote(c["project"], safe="")
            rel = json.loads(fetch("https://gitlab.com/api/v4/projects/%s/releases?per_page=20" % project))
            found = [r["tag_name"] for r in rel]
        if not found:
            raise RuntimeError("no version found")
        latest = max(found, key=vkey)
        if vkey(latest) > vkey(ours):
            return "release", "%s -> %s" % (ours, latest), [], {"latest": latest}
        return "same", "%s is the newest" % ours, [], {"latest": latest}

    if mode == "path":
        ours = read_pin(c["pin"])
        since = gh("repos/%s/commits/%s" % (c["repo"], ours), ".commit.committer.date").strip()
        q = "repos/%s/commits?sha=%s&path=%s&since=%s&per_page=100" % (
            c["repo"], urllib.parse.quote(c["branch"], safe=""),
            urllib.parse.quote(c["path"], safe=""), urllib.parse.quote(since, safe=""))
        rx = re.compile(c.get("msg_regex", "."))
        commits = [(x["sha"][:11], x["commit"]["committer"]["date"][:10],
                    x["commit"]["message"].split("\n", 1)[0][:100])
                   for x in gh_json(q) if not x["sha"].startswith(ours)
                   and rx.search(x["commit"]["message"])]
        commits.reverse()
        if not commits:
            return "same", "nothing under %s after %s" % (c["path"], ours[:11]), [], seen
        return "commits", "%d commit(s) under %s after our %s" % (len(commits), c["path"], ours[:11]), \
            titles(commits), {"head": commits[-1][0]}

    raise RuntimeError("unknown mode %s" % mode)


GROUPS = [
    ("release", "A newer release than ours"),
    ("commits", "New commits after our pin, no newer release"),
    ("fork", "Our forks: upstream commits we do not have"),
    ("moved", "Branches the build follows: changed since our last build or the last check"),
    ("first", "Followed branches seen for the first time"),
    ("error", "Could not check"),
    ("frozen", "Kept old on purpose (not checked)"),
    ("same", "Nothing new"),
]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--force", action="store_true", help="run even if the last check is recent")
    ap.add_argument("--only", nargs="+", help="names (substrings) of the components to check")
    a = ap.parse_args()

    os.makedirs(STATE_DIR, exist_ok=True)
    state = {}
    if os.path.exists(STATE):
        with open(STATE) as f:
            state = json.load(f)
    now = datetime.datetime.now()
    last = state.get("_last_run")
    if last and not a.force and not a.only:
        age = (now - datetime.datetime.fromisoformat(last)).total_seconds() / 3600
        if age < MIN_HOURS:
            print("Last check %s, %.1f h ago (less than %d h): see %s, or use --force."
                  % (last[:16], age, MIN_HOURS, state.get("_last_report", "?")))
            return 0

    with open(os.path.join(HERE, "components.json")) as f:
        comps = json.load(f)["components"]
    if a.only:
        comps = [c for c in comps if any(o.lower() in c["name"].lower() for o in a.only)]

    results = {}

    def one(c):
        try:
            return c["name"], check(c, state.get(c["name"], {}))
        except Exception as e:      # one broken row must not hide the others
            return c["name"], ("error", str(e), [], state.get(c["name"], {}))

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
        for name, res in ex.map(one, comps):
            results[name] = res

    out = ["Upstream check, %s (dArkOS tree %s)" % (now.strftime("%Y-%m-%d %H:%M"), ROOT), ""]
    for g, title in GROUPS:
        rows = [(n, r) for n, r in results.items() if r[0] == g]
        if not rows:
            continue
        out.append("== %s (%d)" % (title, len(rows)))
        for n, (grp, headline, lines, keep) in rows:
            note = next((c.get("note") for c in comps if c["name"] == n), None)
            if g == "same":
                out.append("  %s: %s" % (n, headline))
                continue
            out.append("  %s: %s" % (n, headline))
            for l in lines:
                out.append("      " + l)
            if note and g != "frozen":
                out.append("      (%s)" % note)
        out.append("")
    report = "\n".join(out)
    print(report)

    for n, (grp, headline, lines, keep) in results.items():
        if grp != "error":
            state[n] = keep
    if not a.only:
        state["_last_run"] = now.isoformat(timespec="seconds")
        path = os.path.join(STATE_DIR, "report-%s.txt" % now.strftime("%Y%m%d-%H%M"))
        with open(path, "w") as f:
            f.write(report + "\n")
        state["_last_report"] = path
    with open(STATE, "w") as f:
        json.dump(state, f, indent=1, sort_keys=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
