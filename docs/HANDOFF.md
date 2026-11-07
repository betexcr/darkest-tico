# Handoff Log

Newest entry first. Every agent session ends by adding an entry here (rules: [../AGENTS.md](../AGENTS.md) §3). Backlog and task IDs: [12-phase-plan.md](12-phase-plan.md).

## Template (copy this)

```markdown
## YYYY-MM-DD — <task ID(s)> — <one-line summary>
- **Agent / branch:** <tool + model if known> / `<branch>`
- **Status after session:** <ID: done | review | in-progress | blocked — why>
- **Changed:** <files or areas, one line each>
- **Verified:** <validate_data.py result; Godot smoke/tests result, or "not run — no Godot">
- **Not verified / risks:** <what could be broken>
- **Decisions needed:** <questions for the owner, or "none">
- **Next step:** <one concrete action: task ID + first file to open + what to do>
```

---

## 2026-11-07 — P2-07, P2-04 (roster), P4-03a/b — Bosque hidden, roster approved, slice art generated
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** P2-07: done · P2-04: roster checkbox done (data still todo) · P4-03a: done · P4-03b: review · P2-03: portrait checkbox done
- **Changed:**
  - `scripts/autoload/game_state.gd`, `scripts/hacienda/hacienda_hub.gd`: hub picker reads `GameState.PLAYABLE_REGIONS` (Sótanos only); saves pointing at Bosque fall back to Sótanos
  - `docs/05` §2.6: approved Sótanos roster with data ids
  - `tools/sd_local.py` + `tools/art_manifest.json`: batch art generation with diffusers, model `Lykon/dreamshaper-8` (CreativeML OpenRAIL-M, commercial use OK). Runs on CPU at about 95 s per 512² image.
  - `tools/sd_export.py`, `.cursor/rules/stable-diffusion-assets.mdc`, `docs/11`: one style source (the manifest); prompts no longer name an existing game
  - `assets/`: 32 generated images with `.metadata.json` (8 portraits, 15 enemies, 6 map icons, 3 backgrounds), replacing all placeholders
  - `tools/validate_data.py`: checks the art manifest
- **Verified:** `python3 tools/validate_data.py` → 0 errors, 0 warnings. I reviewed every image by eye through contact sheets.
- **Not verified / risks:** Godot was not run (the binary download was blocked in this container), so the Bosque-hiding GDScript change and the new images are untested in-engine. Risk is low: the change is small, and the images are plain PNGs at the old paths/sizes, except map icons, which are now 128 px instead of 64 (displayed at 40 px).
- **Decisions needed:** Owner to review art (P4-03b). The known misses are listed in P4-03c.
- **Next step:** Start **P1-02** (multi-enemy squads): open `scripts/combat/combat_scene.gd` and replace the single `_enemy` dict with an `_enemies` array. Owner should also open the game once on Windows to confirm the hub still loads (P2-07 change) and to look at the new art.
- **Agent setup for art in a fresh container:** `python3 -m venv <scratch>/sdenv`, then `pip install --index-url https://download.pytorch.org/whl/cpu torch`, then `pip install diffusers transformers accelerate safetensors pillow`, then `python tools/sd_local.py --only <id>`.

---

## 2026-11-06 — P0-01 follow-up — Owner decisions recorded
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** no task status changes
- **Changed:** `docs/12-phase-plan.md` (P2-03, P2-04, P2-05 notes)
- **Verified:** `python3 tools/validate_data.py` → 0 errors (docs-only change)
- **Not verified / risks:** none (no code changed)
- **Decisions made:**
  1. Slice classes 5–8 = Guachimán Jubilado, Médica Josefina, Curandero Nicoyano, Exorcista de Barrio. ✅
  2. El Mayordomo Hundido = Sótanos final boss, fought at objective node `n9`. ✅
- **Decisions needed:**
  1. Bosque region: keep in slice, hide, or debug-only? (P2-07, still open)
  2. Per-region enemy lists don't exist in the docs. Only families (`05` §2) and bosses (§3) do. P2-04 now starts by drafting the Sótanos roster for owner sign-off.
- **Next step:** Unchanged. Start **P1-02** (multi-enemy squads) in `scripts/combat/combat_scene.gd`, or **P1-01** first if Godot is available.

## 2026-11-06 — P0-01 — Handoff protocol + agent-sized phase plan
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** P0-01: done
- **Changed:**
  - `AGENTS.md` (+ `CLAUDE.md` import, `.cursor/rules/agent-handoff.mdc`): start/work/end-of-session rules
  - `docs/12-phase-plan.md`: status snapshot plus phases P0–P5 with task IDs, deps, specs, acceptance
  - `docs/HANDOFF.md`: this log
  - `tools/validate_data.py`: JSON cross-reference and reachability checks; warns on PNGs without SD metadata
  - `docs/README.md`, `README.md`: links
- **Verified:** `python3 tools/validate_data.py` → 0 errors, 19 warnings (all placeholder PNGs lack `.metadata.json`)
- **Not verified / risks:** No Godot in this container, so the game was not launched. No game code was changed.
- **Decisions needed:**
  1. Bosque region: keep in slice, hide, or debug-only? (P2-07)
  2. Classes 5–8 for the slice: the proposal in P2-03 is Guachimán, Médica Josefina, Curandero Nicoyano, Exorcista. OK?
  3. The Mayordomo Hundido is a regular fight at Sótanos `n7`, but `05` makes him the Sótanos apex boss. P2-05 assumes the doc wins.
- **Next step:** Start **P1-02** (multi-enemy squads). Open `scripts/combat/combat_scene.gd` and replace the single `_enemy` dict with an `_enemies` array. Do **P1-01** first instead if the session has Godot available, because tests make every later task safer.
