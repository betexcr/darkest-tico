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

## 2026-11-07 — P4-05, P2-06, P3-09, P4-07/09, P4-08 — Expedition overhaul + battle sprites
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** P4-05 review · P2-06 review · P3-09 review · P4-07 done (folded into P4-09) · P4-09 review · P4-08 in-progress (sprite batch running)
- **Changed:**
  - Export-safe texture loading + GDScript warning fixes (P4-05)
  - `scripts/domain/map_generator.gd` + `sotanos.json` generator block: random grid dungeons, boss (Mayordomo) in the farthest dead end. `tools/preview_map.py` mirrors it in Python for checks/previews.
  - `data/items.json` (11 Tico items), inventory/save v4 in `GameState`, Pulpería in the hub, `scripts/domain/item_effects.gd`
  - **New `scenes/expedition/expedition_screen.tscn`** replaces `expedition_map` + `combat_scene`. It holds the stage (party + enemies in place), the hero card bottom-left (follows the turn; click a hero to view), the map/inventory bottom-right (tabs, M/I keys, arrows/arrow keys/click to move), and event panels over the stage. Combat rules moved to `scripts/combat/combat_controller.gd` (logic unchanged).
  - `scripts/autoload/game_state.gd`: blank lines inside functions removed (parse tree verified identical)
  - Sprites: `tools/sd_sprites.py` now uses OpenPose skeletons (ControlNet) per state for humanoids; beasts use img2img only. Sprite style drops candlelight.
- **Verified:** `validate_data.py` 0 errors; every `.gd` parses with gdtoolkit (`gdparse`); generator rules checked over 3000 seeds in the Python mirror.
- **Not verified / risks:** **Nothing here was run in Godot** (this container can't download it). Expect small runtime errors on first run; the newest code is the expedition screen. New scripts have no `.uid` files yet; Godot creates them on open, so commit those. If every hero dies, the hub has no way to recruit (P3-02).
- **Decisions needed:** none
- **Next step:** Owner runs the game and sends any red errors from Debugger → Errors. The agent fixes them first. Then continue the sprite batch (`python tools/sd_sprites.py` resumes; see P4-08) and generate item icons (P4-10).

---

## 2026-11-07 — Owner in-game check (no task change)
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** unchanged. P4-03b/c stay `review` until the owner approves the art.
- **Verified by owner in Godot 4.7.2** (not 4.6 as the docs say; project still opens fine):
  - The hub loads, the dropdown shows only Sótanos (P2-07 works), and the new hub background shows
  - The expedition map shows the new background and icons
  - Combat shows the Espanto art and hero portraits (Tecnólogo) correctly
  - Debugger: 0 errors and 13 warnings. They are 4 harmless unused-parameter warnings plus 9 "Loaded resource as image file, this will not work on export".
- **Changed:** `docs/12-phase-plan.md`: new tasks P4-05 (export-safe texture loading + warning cleanup) and P4-06 (map icons too small at 40 px)
- **Decisions needed:** none
- **Next step:** **P4-05** is a quick win (~5 small edits) and prevents a broken export. Then **P1-02** (multi-enemy squads) in `scripts/combat/combat_scene.gd`.

---

## 2026-11-07 — P4-03c — Art fixes
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** P4-03c: review
- **Changed:**
  - `tools/sd_local.py`: `--try-seeds N --preview-dir DIR` writes candidates (seed, seed+1, …) outside `assets/`. There's an optional per-asset `post` (brightness/contrast).
  - `tools/art_manifest.json`: new subjects/seeds for the 6 fixed assets; map icons get `post` brightening
  - `assets/`: segua_boss, rata_de_troje, nuboso_spectre, duende_sotano, campesino, medica_josefina, and all 6 map icons regenerated (metadata updated)
- **Verified:** `python3 tools/validate_data.py` → 0 errors. I picked each image by eye from 3 candidates (6 for rats and campesino).
- **Not verified / risks:** Not checked in Godot. Picked images were copied from previews, so their metadata timestamps are preview times; the seeds match the manifest.
- **Decisions needed:** Owner to look at the art in-game and approve or list further fixes.
- **Next step:** Start **P1-02** (multi-enemy squads): open `scripts/combat/combat_scene.gd` and replace the single `_enemy` dict with an `_enemies` array.

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
