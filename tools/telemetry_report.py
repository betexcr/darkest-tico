#!/usr/bin/env python3
"""
Summarise a telemetry log (P5-01) for balance work (P5-02).

    python3 tools/telemetry_report.py [path/to/telemetry.jsonl]

The game writes `user://telemetry.jsonl` (one JSON object per line, field "kind"):
  - session      game started (save version, week)
  - mission_end  result (objective | defeat | flee), difficulty, rooms, fights, loot, party
  - stress_spike a hero reached the resolve check (quebranto / virtud) or collapsed
  - week         end of a week: colones now, colones in / out during the week, roster
Without a path it looks in Godot's user folder for this project (Linux, macOS, Windows).
`tools/playtest_campaign.gd -- --telemetry <path>` writes the same log from bot campaigns.
"""
import json
import os
import sys
from collections import Counter, defaultdict
from pathlib import Path

PROJECT_NAME = "Darkest Tico"


def default_path() -> Path:
    name = PROJECT_NAME
    for line in (Path(__file__).resolve().parent.parent / "project.godot").read_text(encoding="utf-8").splitlines():
        if line.startswith("config/name="):
            name = line.split("=", 1)[1].strip().strip('"')
    if sys.platform.startswith("win"):
        base = Path(os.environ.get("APPDATA", "")) / "Godot" / "app_userdata"
    elif sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support" / "Godot" / "app_userdata"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "godot" / "app_userdata"
    return base / name / "telemetry.jsonl"


def load(path: Path) -> list:
    rows = []
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            print(f"(skipping unreadable line {n})")
    return rows


def pct(a: int, b: int) -> str:
    return f"{100.0 * a / b:.0f}%" if b else "—"


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else default_path()
    if not path.exists():
        print(f"No telemetry at {path}")
        return 1
    rows = load(path)
    by_kind = defaultdict(list)
    for r in rows:
        by_kind[r.get("kind", "?")].append(r)
    print(f"# Telemetry — {path}\n")
    print(f"{len(rows)} events: " + ", ".join(f"{k} {len(v)}" for k, v in sorted(by_kind.items())) + "\n")

    missions = by_kind["mission_end"]
    if missions:
        print("## Missions\n")
        print("| Difficulty | Missions | Objective | Defeat | Fled | Success |")
        print("|---|---:|---:|---:|---:|---:|")
        diffs = defaultdict(Counter)
        for m in missions:
            diffs[m.get("difficulty", "?")][m.get("result", "?")] += 1
        total = Counter()
        for d, c in sorted(diffs.items()):
            n = sum(c.values())
            total.update(c)
            print(f"| {d} | {n} | {c['objective']} | {c['defeat']} | {c['flee']} | {pct(c['objective'], n)} |")
        n = sum(total.values())
        print(f"| **all** | {n} | {total['objective']} | {total['defeat']} | {total['flee']} | **{pct(total['objective'], n)}** |")
        deaths = sum(sum(1 for h in m.get("party", []) if h.get("dead")) for m in missions)
        print(f"\nHeroes lost: {deaths} ({deaths / len(missions):.2f} per mission). Doc 04 target: 55–70% success.\n")

    spikes = by_kind["stress_spike"]
    if spikes:
        print("## Stress spikes\n")
        c = Counter(s.get("result", "?") for s in spikes)
        print(", ".join(f"{k}: {v}" for k, v in c.most_common()))
        print(f"In an expedition: {sum(1 for s in spikes if s.get('in_mission'))} of {len(spikes)}.\n")

    weeks = by_kind["week"]
    if weeks:
        print("## Weeks\n")
        print("| Week | Colones | In | Out | Net | Roster | Fallen |")
        print("|---:|---:|---:|---:|---:|---:|---:|")
        for w in weeks:
            i, o = int(w.get("colones_in", 0)), int(w.get("colones_out", 0))
            print(f"| {w.get('week')} | {w.get('colones')} | {i} | {o} | {i - o:+d} | {w.get('roster')} | {w.get('fallen', 0)} |")
    return 0


if __name__ == "__main__":
    sys.exit(main())
