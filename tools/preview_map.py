#!/usr/bin/env python3
"""
Python mirror of scripts/domain/map_generator.gd for checking the algorithm without Godot.

  python3 tools/preview_map.py                 # print 3 sample Sótanos maps
  python3 tools/preview_map.py --seed 42       # one specific seed
  python3 tools/preview_map.py --check 2000    # sanity-check many seeds

Keep this in sync with map_generator.gd when the algorithm changes. The RNG differs from
Godot's, so the same seed gives a different map here; the rules are what is being tested.
"""

from __future__ import annotations

import argparse
import json
import random
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIRS = [(1, 0), (-1, 0), (0, 1), (0, -1)]
SYMBOL = {"safe": "S", "boss": "B", "camp": "F", "elite": "E", "combat": "c", "trap": "t", "curio": "?", "empty": "."}


def bfs(adj, start):
    dist = [-1] * len(adj)
    dist[start] = 0
    q = deque([start])
    while q:
        cur = q.popleft()
        for n in adj[cur]:
            if dist[n] < 0:
                dist[n] = dist[cur] + 1
                q.append(n)
    return dist


def generate(gen: dict, seed: int):
    out = None
    for attempt in range(30):
        out = generate_once(gen, seed + attempt)
        if out[4][out[3]] >= gen.get("min_boss_distance", 5):
            return out
    return out


def generate_once(gen: dict, seed: int):
    rng = random.Random(seed)
    lo, hi = gen.get("rooms", [10, 13])
    target = rng.randint(lo, hi)
    cells = [(0, 0)]
    index = {(0, 0): 0}
    adj = [[]]
    guard = 0
    while len(cells) < target and guard < 5000:
        guard += 1
        if rng.random() < 0.6:
            frm = len(cells) - 1
        else:
            opts = [k for k in range(len(cells)) if len(adj[k]) < 3] or list(range(len(cells)))
            frm = rng.choice(opts)
        free = [d for d in DIRS if (cells[frm][0] + d[0], cells[frm][1] + d[1]) not in index]
        if not free:
            continue
        d = rng.choice(free)
        c = (cells[frm][0] + d[0], cells[frm][1] + d[1])
        idx = len(cells)
        cells.append(c)
        index[c] = idx
        adj.append([])
        adj[frm].append(idx)
        adj[idx].append(frm)
    dist = bfs(adj, 0)
    boss = -1
    for k in range(1, len(cells)):
        if len(adj[k]) == 1 and (boss < 0 or dist[k] > dist[boss]):
            boss = k
    if boss < 0:
        boss = len(cells) - 1
    boss_dist = dist[boss]
    links, tries = gen.get("extra_links", 1), 0
    while links > 0 and tries < 200:
        tries += 1
        a = rng.randint(1, len(cells) - 1)
        if a == boss:
            continue
        d = rng.choice(DIRS)
        o = index.get((cells[a][0] + d[0], cells[a][1] + d[1]), -1)
        if o > 0 and o != boss and o not in adj[a]:
            adj[a].append(o)
            adj[o].append(a)
            if bfs(adj, 0)[boss] < boss_dist:
                adj[a].remove(o)
                adj[o].remove(a)
            else:
                links -= 1
    dist = bfs(adj, 0)
    max_d = dist[boss]
    half = int(max_d / 2.0)
    types = [""] * len(cells)
    types[0], types[boss] = "safe", "boss"
    pool = [k for k in range(len(cells)) if types[k] == ""]
    for _ in range(gen.get("camps", 1)):
        cand = [k for k in pool if types[k] == ""]
        if cand:
            best = min(cand, key=lambda k: abs(dist[k] - half))
            types[best] = "camp"
    far = [k for k in pool if types[k] == "" and dist[k] * 2 >= max_d]
    for _ in range(gen.get("elites", 1)):
        if not far:
            break
        types[far.pop(rng.randrange(len(far)))] = "elite"
    weights = gen.get("weights", {})
    names, ws = list(weights), list(weights.values())
    for k in pool:
        if types[k] == "":
            types[k] = rng.choices(names, ws)[0]
    n_combat = types.count("combat") + types.count("elite")
    for k in pool:
        if n_combat >= gen.get("min_combat", 2):
            break
        if types[k] in ("empty", "curio", "trap"):
            types[k] = "combat"
            n_combat += 1
    return cells, adj, types, boss, dist


def render(cells, adj, types):
    xs = [c[0] for c in cells]
    ys = [c[1] for c in cells]
    mx, my = min(xs), min(ys)
    w, h = (max(xs) - mx) * 2 + 1, (max(ys) - my) * 2 + 1
    grid = [[" "] * w for _ in range(h)]
    for k, (x, y) in enumerate(cells):
        gx, gy = (x - mx) * 2, (y - my) * 2
        grid[gy][gx] = SYMBOL[types[k]]
        for n in adj[k]:
            nx, ny = (cells[n][0] - mx) * 2, (cells[n][1] - my) * 2
            grid[(gy + ny) // 2][(gx + nx) // 2] = "-" if gy == ny else "|"
    return "\n".join("".join(r) for r in grid)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--region", default="sotanos")
    ap.add_argument("--seed", type=int)
    ap.add_argument("--check", type=int, default=0)
    args = ap.parse_args()
    gen = json.loads((ROOT / "data/regions" / f"{args.region}.json").read_text(encoding="utf-8"))["generator"]
    if args.check:
        problems = 0
        for s in range(args.check):
            cells, adj, types, boss, dist = generate(gen, s)
            ok = all(d >= 0 for d in dist) and len(adj[boss]) == 1 and types[0] == "safe"
            ok = ok and types.count("boss") == 1 and types.count("combat") + types.count("elite") >= gen.get("min_combat", 2)
            ok = ok and dist[boss] >= gen.get("min_boss_distance", 5)
            if not ok:
                problems += 1
        sizes = [len(generate(gen, s)[0]) for s in range(200)]
        depth = [generate(gen, s)[4][generate(gen, s)[3]] for s in range(200)]
        print(f"{args.check} seeds: {problems} problem(s); rooms {min(sizes)}-{max(sizes)}; "
              f"rooms to boss {min(depth)}-{max(depth)} (avg {sum(depth) / len(depth):.1f})")
        return
    seeds = [args.seed] if args.seed is not None else [1, 2, 3]
    print("S entrance  B boss  F camp  E elite  c combat  t trap  ? curio  . empty\n")
    for s in seeds:
        cells, adj, types, boss, dist = generate(gen, s)
        print(f"seed {s}: {len(cells)} rooms, boss {dist[boss]} rooms away")
        print(render(cells, adj, types) + "\n")


if __name__ == "__main__":
    main()
