# Phase Plan (agent-executable)

This is the working backlog. [06-production-roadmap.md](06-production-roadmap.md) is the strategic roadmap, written for a 9–20 person studio. This file breaks it into tasks that **one agent can finish in one session**. Protocol for claiming and handing off: [../AGENTS.md](../AGENTS.md).

**Current phase: P1. Close preproduction gaps.**

Task format: `ID · Size (S ≈ <1 session, M ≈ 1 session, L ≈ 2+ sessions; split L before starting)`. Every task lists **Spec** (docs to read), **Files** (likely touched), and **Done when** (acceptance checkboxes).

---

## Status snapshot (2026-11-06)

What exists in the single commit `6e515c6` (2026-04-10):

| Area | State |
|---|---|
| Design docs 01–09, 11 | Complete GDD v1 (≈1,300 lines) |
| Hub | Colones/week, roster view, 3 actions: rations, lantern fuel, Iglesia "misa rápida". Region picker. |
| Expedition | Hand-authored node graphs for 2 regions (Sótanos 10 nodes, Bosque 8). Light/food, low-light stress, trap/curio/camp/objective with 2 hard-coded choices each, flee. |
| Combat | 4 heroes vs **1** enemy, initiative per round, hit/crit/damage, Al Borde + death save, stress 0–200 with Quebranto (3 afflictions) / Virtud (2). **No ranks, no status effects, no multi-enemy squads.** |
| Content | 4 heroes, 5 skills, 6 enemies (incl. Segua boss), 20 placeholder PNGs (none have SD metadata). |
| Save | `user://save.json` v3: colones, week, party. Mid-mission not saved. |
| Tooling | `tools/sd_export.py`, placeholder generators, `tools/validate_data.py` (new). |
| Tests / telemetry / audio | None. |

Against the roadmap: **Phase 1 (preproduction)** has its docs done but its exit criteria are not met. Ranks are not prototyped, there's no combat sim sheet, and the paper playtest has not run. **Phase 2 (vertical slice)** is about 35% done: the loop runs end to end, but it has 4 of 8 classes, 3 of 9 buildings, and roughly 8 of 30–40 events.

---

## P0 — Handoff infrastructure ✅

### P0-01 · S · Agent rules, handoff log, phase plan
- Status: `done`
- Files: `AGENTS.md`, `CLAUDE.md`, `.cursor/rules/agent-handoff.mdc`, `docs/HANDOFF.md`, `docs/12-phase-plan.md`, `tools/validate_data.py`
- Done when:
  - [x] Any agent can find what to do next from `docs/HANDOFF.md` alone
  - [x] Data validator runs without Godot

---

## P1 — Close preproduction gaps (combat core)

Goal: meet roadmap Phase 1 exit criteria. The combat prototype must validate the rank system, the stress breakpoints, and short-mission pacing.

### P1-01 · M · Headless test harness
- Status: `todo` · Depends: —
- Spec: `01` §2–3
- Files: `tests/run_tests.gd` (new, `extends SceneTree`), `tests/test_*.gd`, `AGENTS.md` (add command)
- Done when:
  - [ ] `godot --headless --path . -s tests/run_tests.gd` runs all tests and exits non-zero on failure
  - [ ] Tests cover `CombatResolver` (hit clamp, crit cap, death save) and `StressSystem` (resolve at 100, Colapso at 200, Virtud reset)
  - [ ] Command added to AGENTS.md §3 verify step

### P1-02 · M · Multi-enemy squads (1–4 enemies)
- Status: `todo` · Depends: —
- Spec: `01` §2.1–2.2
- Files: `scripts/combat/combat_scene.gd`, `scenes/combat/combat_scene.tscn`, `scripts/autoload/game_state.gd` (`build_combat_context_for_node`), `data/regions/*.json`, `tools/validate_data.py`
- Done when:
  - [ ] Region nodes accept `enemy_ids: [..]` (keep `enemy_id` as a 1-element fallback)
  - [ ] Combat shows N enemies, each with HP and initiative; heroes pick a target
  - [ ] Victory = all enemies dead; validator checks `enemy_ids`

### P1-03 · L→ split · Battlefield ranks 1–4
- Status: `todo` · Depends: P1-02
- Spec: `01` §2.1, `03` "Position Notation"
- Files: `data/skills.json` (`use_ranks`, `target_ranks`), `data/heroes.json` (default rank), `scripts/domain/rank_rules.gd` (new, pure), `scripts/combat/combat_scene.gd`
- Done when:
  - [ ] Each side has ranks 1–4; skills disabled when user/target rank invalid
  - [ ] Dead units collapse ranks forward
  - [ ] Hub or pre-mission screen lets the player order the party
  - [ ] Unit tests for rank_rules (if P1-01 done)

### P1-04 · M · Status effect engine
- Status: `todo` · Depends: P1-02
- Spec: `01` §2.5
- Files: `scripts/domain/status_effects.gd` (new), `data/skills.json` (`applies: [{status, chance, duration, value}]`), `scripts/combat/combat_scene.gd`
- Done when:
  - [ ] Supports bleed, stun, mark, guard at minimum; durations tick per round
  - [ ] Initiative includes `statusModifiers`; tie-breakers per `01` §2.2 (speed → resolve → random)
  - [ ] Status shown on unit UI

### P1-05 · S · Spec-accurate Al Borde and crit stress
- Status: `todo` · Depends: —
- Spec: `01` §2.3–2.4, §3.4
- Files: `scripts/domain/combat_resolver.gd`, `scripts/combat/combat_scene.gd`
- Done when:
  - [ ] Death save chance drops for each prior Al Borde check in the same mission and for high stress
  - [ ] Crits apply "stress shock" to the target side
  - [ ] Damage formula includes `atkMods` / defense multipliers (0 by default)

### P1-06 · S · Balance constants to data
- Status: `todo` · Depends: P1-05
- Spec: `04`, roadmap §8 item 1
- Files: `data/balance.json` (new), `scripts/domain/*.gd`, `scripts/autoload/game_state.gd`
- Done when:
  - [ ] Hit band, crit cap/multiplier, death save base/decay, stress thresholds, shop prices are read from `data/balance.json`
  - [ ] No magic balance numbers left in `scripts/domain/`

### P1-07 · M · Combat Monte Carlo sim
- Status: `todo` · Depends: P1-06
- Spec: `04`, `06` Phase 1 "combat simulation sheet"
- Files: `tools/sim_combat.py` (new; reads `data/*.json`, mirrors resolver math)
- Done when:
  - [ ] Prints win rate, average turns, and stress delta per party-vs-node over N=10k runs
  - [ ] Results for Sótanos written to `docs/10-implementation-notes.md`

### P1-08 · S · Technical architecture doc
- Status: `todo` · Depends: P1-02, P1-04
- Spec: `06` Phase 1 deliverables
- Files: `docs/13-architecture.md` (new), `docs/README.md`
- Done when:
  - [ ] Documents save schema + versioning, encounter flow (hub → map → combat → map), status engine, data file schemas

### P1-09 · S · Paper/headless playtest + Phase 1 sign-off
- Status: `todo` · Depends: P1-03, P1-04, P1-07
- Spec: `09`, `06` Phase 1 exit criteria
- Files: `docs/09-paper-prototype-playtest.md` (notes section)
- Done when:
  - [ ] One recorded playtest (human or sim-based) with notes
  - [ ] Owner marks Phase 1 exit criteria met → set **Current phase** to P2 (status `review` until owner confirms)

---

## P2 — Vertical slice content (Sótanos complete)

Goal: roadmap Phase 2 scope. 1 region, 8 classes, 1 apex boss + 1 mini-boss, 30–40 events.

### P2-01 · M · Data-driven events (traps/curios/camp)
- Status: `todo` · Depends: P1-06
- Spec: `07`, `01` §4
- Files: `data/events.json` (new), `scripts/domain/event_resolver.gd` (new), `scripts/expedition/expedition_map.gd`
- Done when:
  - [ ] Trap/curio/camp choices and outcomes come from JSON (no hard-coded `_trap_fast`/`_curio_touch` etc.)
  - [ ] Nodes reference `event_id` or an event pool; validator checks references
  - [ ] Existing behavior preserved as the first entries

### P2-02 · M · 30–40 Sótanos event variants
- Status: `todo` · Depends: P2-01
- Spec: `07`, `05` §1.1, `08` (tone)
- Files: `data/events.json`
- Done when:
  - [ ] ≥30 events tagged for `sotanos`, Spanish text, tone-reviewed against `08`

### P2-03 · M · Classes 5–8
- Status: `todo` · Depends: P1-03, P1-04
- Spec: `03`. **Owner confirmed 2026-11-06:** classes 3 Guachimán Jubilado, 5 Médica Josefina, 6 Curandero Nicoyano, 9 Exorcista de Barrio.
- Files: `data/heroes.json`, `data/skills.json`, `assets/portraits/`
- Done when:
  - [ ] 8 heroes, each with 4 skills and rank constraints
  - [x] Portraits generated with SD metadata (`assets/portraits/{guachiman,medica_josefina,curandero,exorcista}.png`; hero ids should match these names)

### P2-04 · M · Sótanos enemy roster to ~12 units
- Status: `todo` · Depends: P1-03, P1-04
- Spec: `05` §1.1, §2
- Files: `data/enemies.json`, `data/regions/sotanos.json`, `assets/enemies/`
- Done when:
  - [x] Roster spec approved by owner 2026-11-06: `05` §2.6 (11 regulars incl. summon, Cadejo mini-boss, Mayordomo boss). Art for all of them already exists in `assets/enemies/`
  - [ ] ≥12 Sótanos enemies with skills, ranks, statuses; 3+ mixed squads used in the map

### P2-05 · M · Bosses: Mayordomo Hundido (apex) + 1 mini-boss
- Status: `todo` · Depends: P2-04
- Spec: `05` §3.1–3.2 (Mayordomo: summon servants, darkness pulses, anti-guard)
- Files: `data/enemies.json`, `scripts/domain/boss_scripts.gd` (new) or data-driven phases, `data/regions/sotanos.json`
- Done when:
  - [ ] **Owner confirmed 2026-11-06:** Mayordomo is the Sótanos final boss. He becomes the objective fight at `n9` (he's currently a plain combat node at `n7`; give `n7` a regular squad) with his 3 mechanics
  - [ ] One roaming mini-boss with a spawn rule (suggested: Cadejo Negro, listed in `05` §3.2; today it is a plain elite in Bosque `b4`)

### P2-06 · M · Map generator (seeded) for Sótanos
- Status: `todo` · Depends: P2-01
- Spec: `01` §4.2–4.3, `07`
- Files: `scripts/domain/map_generator.gd` (new), `data/regions/sotanos.json` (generation params), `scripts/expedition/expedition_map.gd`
- Done when:
  - [ ] Short/medium missions generate valid graphs from a seed (start → objective always reachable)
  - [ ] Scouting/fog per `01` §4.3; hand-authored maps still loadable

### P2-07 · S · Bosque: decide slice status
- Status: `done`
- Notes: **Owner decision 2026-11-06: Bosque moves to the Alpha phase.** Hidden from the hub picker via `GameState.PLAYABLE_REGIONS`; data and art kept. Old saves pointing at Bosque fall back to Sótanos. Re-enable in Alpha by adding it back to `PLAYABLE_REGIONS`.
- Done when:
  - [x] Decision recorded in HANDOFF; picker updated accordingly

---

## P3 — Hacienda baseline (campaign loop)

### P3-01 · M · Weekly tick + roster lifecycle
- Status: `todo` · Depends: —
- Spec: `02` §1, §12
- Files: `scripts/autoload/game_state.gd`, `scripts/hacienda/hacienda_hub.gd`
- Done when:
  - [ ] Single `advance_week()` does the recruit refresh, market rotation, and recovery resolution (today `week += 1` is scattered in 2 places)
  - [ ] Roster > 4 heroes; choose 4 for a mission; dead heroes leave the roster

### P3-02 · M · Terminal de Buses (recruitment)
- Status: `todo` · Depends: P3-01, P2-03
- Spec: `02` §3
- Done when: [ ] Weekly recruit pool, hire cost, roster cap

### P3-03 · M · Iglesia Vieja + Cantina (stress duality)
- Status: `todo` · Depends: P3-01
- Spec: `02` §7
- Done when: [ ] Both buildings with activities, slots, and side effects; heroes are busy for the week

### P3-04 · M · Casa Comunal (skills) + hero XP/resolve level
- Status: `todo` · Depends: P3-01
- Spec: `02` §4, `04`
- Done when: [ ] Heroes gain resolve XP per mission; skill ranks purchasable

### P3-05 · M · Taller (equipment) + Feria Nocturna (trinkets)
- Status: `todo` · Depends: P3-04
- Spec: `02` §5, §8
- Done when: [ ] Weapon/armor tiers; trinket slots with market rotation

### P3-06 · M · Clínica de Espantos + quirks
- Status: `todo` · Depends: P3-01
- Spec: `02` §6, `01` §3
- Done when: [ ] Positive/negative quirks gained on missions; treatment in Clínica

### P3-07 · S · Guardabosques (camp skills)
- Status: `todo` · Depends: P2-01
- Spec: `02` §9, `01` §4.4
- Done when: [ ] Camp node uses per-hero camp skills instead of the fixed "feast/skip"

### P3-08 · M · Save v4 + migration tests
- Status: `todo` · Depends: P3-01
- Spec: `06` risk register (save corruption)
- Files: `scripts/autoload/game_state.gd`, `scripts/autoload/save_service.gd`, `tests/`
- Done when:
  - [ ] Versioned migrations v3→v4; atomic write (temp file + rename); backup of the previous save
  - [ ] Test loads a v3 fixture

---

## P4 — Slice UX, art, audio

### P4-01 · M · Prep and extraction screens
- Spec: `06` Phase 2 deliverables ("prep, mission select, map traversal, combat, extraction")
- Status: `todo` · Depends: P1-03, P3-01

### P4-02 · M · Tooltips (skills, statuses, stress)
- Status: `todo` · Depends: P1-04

### P4-03 · M · Slice art pass (split)
- **P4-03a · S · Local generator that runs anywhere** — Status: `done`. `tools/sd_local.py` + `tools/art_manifest.json` (diffusers, DreamShaper 8, CPU ok). Style unified across the manifest, `sd_export.py`, the SD rule, and doc 11.
- **P4-03b · M · Generate slice art** — Status: `review` (owner to look at the images). 32 images: 8 portraits, 15 enemies (approved roster + Bosque), 6 map icons, 3 backgrounds, each with `.metadata.json`.
- **P4-03c · S · Art fixes after owner review** — Status: `review` (owner to check in-game). Redone 2026-11-07: Segua (horse-skull head), rats (feral, fill frame), Bosque spectre, duende (less cartoonish), campesino (machete), médica (white coat); map icons brightened (`post` in manifest). Further fixes: change subject/seed in the manifest; use `--try-seeds 3 --preview-dir <scratch>` to compare candidates.
- **P4-03d · M · Transparent enemy/hero cutouts** — Status: `todo` · Depends: P1-02. Needed once several enemies share the combat screen (rule: transparent background when applicable).
- **P4-03e · S · Hub building art** — Status: `todo` · Depends: P3-01. Only if the hub becomes visual.

### P4-05 · S · Export-safe texture loading
- Status: `todo` · Depends: —
- Found by owner 2026-11-07 (Godot debugger warnings). Hub, map and combat load PNGs with `Image.new().load("res://…")`. That works in the editor but **images will be missing in an exported build**.
- Files: `scripts/hacienda/hacienda_hub.gd:64`, `scripts/expedition/expedition_map.gd:44,132`, `scripts/combat/combat_scene.gd:66,80`
- Done when:
  - [ ] All five use `ResourceLoader.exists(path)` + `load(path) as Texture2D` (keep the procedural fallback when missing)
  - [ ] The 4 "parameter is never used" / shadowing GDScript warnings fixed (`combat_resolver.gd` `resolve_level`, `expedition_map.gd` `tr` and `cn`, `combat_scene.gd` `first`)
  - [ ] Debugger shows no warnings after a hub → map → combat run

### P4-06 · S · Readable map node icons
- Status: `todo` · Depends: —
- Icons render at 40×40 next to route buttons (`expedition_map.gd:136`) and are hard to read in the owner's screenshots. Try 64×64, or a type label color per node type.

### P4-04 · M · Audio mood + narrator lines
- Status: `todo` · Depends: — · Spec: `08`

---

## P5 — Slice validation (roadmap Phase 2 exit)

### P5-01 · M · Local telemetry log
- Status: `todo` · Depends: P3-01
- Done when: [ ] `user://telemetry.jsonl` records mission result, stress spikes, colones in/out per week

### P5-02 · M · Balance pass to 55–70% mission success
- Status: `todo` · Depends: P1-07, P2-*, P5-01

### P5-03 · S · 3-loop new-player playtest + slice sign-off
- Status: `todo` · Depends: all P2–P5
- Done when: [ ] Roadmap Phase 2 exit criteria checked by owner → Current phase = Alpha (break down roadmap Phase 3 into P6+ tasks then)

---

## Later (not broken down yet)

Roadmap Phase 3 (Alpha: 4–5 regions, 16 classes, 120+ events, difficulty tiers), Phase 4 (Beta/polish), Phase 5 (Launch). Break these into tasks only once P5-03 is done. Don't plan that far ahead in detail.
