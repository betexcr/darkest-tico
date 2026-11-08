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

## 2026-11-08 (later) — P4-08, P1-13 — Right-arm attacks (mirrored stage), combat feedback
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** P4-08 in-progress (8 hero attack sprites done; enemies left); P1-13 review
- **Changed:**
  - Owner: the weapon must be in the RIGHT arm. SD 1.5 + OpenPose always raises the arm on the enemy side of the picture, which for a right-facing hero is the left arm (profile, two-handed, back-view, init-from-another-sprite and hand-repaint attempts all failed). Fix: **mirrored the battle stage** — party on the right facing left, enemies on the left (`scenes/expedition/expedition_screen.tscn`, `expedition_screen.gd`, `battle_unit.gd`). Attack skeleton faces left; weapon guide angle 135°, `hand: right`. Rule in AGENTS.md §4.
  - All 8 hero `attack.png` regenerated facing left (seeds in `redo_seeds`); small hand edits recorded in each sprite's metadata `post` (second weapons erased, médica syringe moved to the right hand, curandero smoke). Scripts in `tools/sprite_edits/`.
  - P1-13 combat feedback: floating damage/crit/heal/stress/miss numbers + hit flash; status icons (sangrado, veneno, aturdido, guardia) above fighters with turns + tooltip (`battle_unit.gd`). Art entries `status_*` in the manifest (`assets/status/<id>.png`, 64 px); a coloured letter badge shows until the PNG exists. Test `tests/test_feedback.gd`.
- **Verified:** `validate_data.py` 0 errors. Godot headless: smoke (0 failures), test_guard, test_status, test_hub, test_equipment, test_feedback (0 failures).
- **Not verified / risks:** Nobody has looked at the mirrored stage or the popups in a running game. Hero idle/cast/hurt sprites were made for the old layout (mostly front-facing, so they still work).
- **Decisions needed:** none
- **Next step:** P4-08 enemies one by one: rewrite each enemy `look` from `assets/enemies/<id>.png`, generate facing LEFT like heroes (the game mirrors enemies), `redo_reference: idle`, check for extra weapons. Then commit the `status_*` icons if the queued run produced them (`python tools/sd_local.py --only status_sangrado status_veneno status_aturdido status_guardia`).

## 2026-11-08 — P4-08 — Hero attack poses aimed at the enemy
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** P4-08 in-progress (8 heroes done incl. new attack poses; 15 enemies left)
- **Changed:**
  - Attack pose (owner request): turned toward the enemy (right), lunging, weapon held forward. The pose skeleton alone could not place the weapon (SD 1.5 draws blades hanging down), so attack is redrawn from scratch with a 2nd ControlNet (`lllyasviel/control_v11p_sd15_scribble`, `sprites.weapon_guide`) fed a drawn weapon shape per hero (`weapon_shape`: line / rope / cross / box / bowl).
  - New per-character knobs in `tools/art_manifest.json`: `redo_seeds`, `redo_poses`, `redo_looks`, `redo_ref_scale`, `negative_extra`, `weapon_shape`. Null keypoints allowed in skeletons.
  - `--redo-tries N --preview-dir D` writes PNG + metadata variants; pick one by copying both into `assets/sprites/<id>/attack.*` and setting `redo_seeds`.
  - Medica Josefina: black leggings (her negative no longer contains "stockings", which suppressed leg coverings).
- **Verified:** `validate_data.py` 0 errors. Each attack picked by eye from 2 variants.
- **Not verified / risks:** Fixed later the same day (owner: hats stretched, faces not looking right): attack redraws for campesino, montador, medica, exorcista use the character's own idle sprite as the IP-Adapter reference (`redo_reference: idle`) instead of the portrait close-up, plus 'head in profile facing right'. Campesino attack (seed 5101) had a stray second machete erased by hand (`post` in its metadata). Guachimán attack has a ponytail he lacks elsewhere.
- **Decisions needed:** Owner review of the 8 attack sprites (all now face right).
- **Next step:** P4-08 — start enemies one by one (see previous entry); for their attack poses set `redo_reference: idle` (portrait close-ups distort full-body redraws) and a `weapon_shape`.

## 2026-11-07 (night) — P4-08, P4-10 — Hero sprites that match the portraits; all item icons
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** P4-10 review (all 64 item icons); P4-08 in-progress (8 heroes done, 15 enemies left)
- **Changed:**
  - `tools/sd_sprites.py`: portrait → IP-Adapter reference (portrait cut out on grey, cached in `tools/.sprite_cache/<id>_ref.png`); attack cell redrawn full-size (`sheet.redo_states`); per-character `seed`, `redo_seeds`, `redo_poses`, `skeletons`; `--states attack --force` reuses the cached raw sheet (~3 min); dead sprites keep only the main figure; `--try-seeds N --ref-scales ... --preview-dir` for comparisons.
  - `tools/art_manifest.json`: hero `look`s rewritten from their portraits; sprite prompts/negative kept under CLIP's 77 tokens.
  - `assets/sprites/<hero>/` for all 8 hero classes. AGENTS.md §4 + doc 11: sprites must look like the portrait (owner rule).
- **Verified:** `validate_data.py` 0 errors / 0 warnings. Each hero's sprites reviewed by eye next to the portrait. Godot tests not re-run this session (no code changes in game scripts).
- **Not verified / risks:** Owner still reviewing heroes one by one. Re-rolls landed: montador (seed 5013 + lasso attack redo 5015; leftover: hat in hand on attack, hide behind hurt), medica_josefina (seed 5051, flat boots, knee skirt), exorcista attack (processional cross). Per-character `negative_extra` exists for outfit drift (keep total under 77 CLIP tokens).
- **Decisions needed:** Owner verdict per hero sprite set.
- **Next step:** P4-08 — after owner OK on heroes, run enemies one by one: rewrite each enemy `look` in `tools/art_manifest.json` from `assets/enemies/<id>.png`, then `python tools/sd_sprites.py --only <id> --force` (humanoids ~12 min; beasts rata_de_troje, murcielago_bodega, cadejo_negro use img2img), review next to the portrait, re-roll attack with `--states attack --force` if it has a third hand / no weapon.

## 2026-11-07 (later) — Combat depth, recruiting, equipment, Godot tests
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:**
  - done: P1-02, P1-10, P1-11, P1-12
  - review: P2-03, P3-01, P3-02, P3-09, P3-10, P3-11, P4-09
  - in-progress: P1-01, P1-04, P2-01, P4-08 (sprites), P4-10 (icons)
- **Changed (owner requests, in order):**
  - Per-hero item limit per room
  - Godot 4.6.2 now runs headless in the container, plus tests under `tests/`
  - Guard action; 4 skills per class with ally/party support
  - Enemy abilities (basic + 1–3 specials, Tico names) and ailments (sangrado/veneno/aturdido)
  - Curios with key items (`data/curios.json`)
  - Recruiting at the Terminal de Buses with a roster of 8 and a party of 4; 4 new hireable classes; weekly turnover with permadeath; EBAIS healing; save v5
  - Multi-enemy squads with click-to-target
  - Equipment (25 pieces, 1 weapon / 1 armor / 2 accessories, drag-and-drop) and 8 elements with enemy affinities
  - Content rules in AGENTS.md §4, enforced by `validate_data.py`
- **Verified:** `validate_data.py` 0 errors. Godot 4.6.2 headless: `tests/smoke_expedition.gd` (3 full expeditions with squads, guard, support skills, targeting; 0 failures, no script errors), `test_guard`, `test_status`, `test_hub` (19), `test_equipment` (17) all pass.
- **Not verified / risks:** Visual layout was not seen by a human (headless only), especially the new hub columns, the hero-panel equipment row and drag-and-drop feel. Fights are long (~100 hero turns per expedition in the smoke test), so balance is needed (P5-02).
- **Art in progress:** item icons (37), then the campesino sprite **sheet** (all 6 poses in one image so outfit and weapon match). Then run `python tools/sd_sprites.py` for the other 22 characters (~10 min each on CPU; resumable).
- **Decisions needed:** none open
- **Next step:** Review the campesino sheet. If consistent, run the full sprite batch in ≤2 h chunks. Owner: play in Godot and report layout issues.

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
