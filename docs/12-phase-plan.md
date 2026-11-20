# Phase Plan (agent-executable)

This is the working backlog. [06-production-roadmap.md](06-production-roadmap.md) is the strategic roadmap, written for a 9–20 person studio. This file breaks it into tasks that **one agent can finish in one session**. Protocol for claiming and handing off: [../AGENTS.md](../AGENTS.md).

**Current phase: P2. Vertical slice content (Sótanos complete).** (Phase 1 signed off by the owner 2026-11-17.)

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

### P0-02 · S · Move the project to Godot 4.7 (owner's install is 4.7.2)
- Status: `done` (Claude Code, `main`, 2026-11-11)
- Files: `project.godot`, `.cursor/rules/godot-runtime.mdc`, `AGENTS.md`, `README.md`, `launch-editor.bat`
- Done when:
  - [x] `config/features` says 4.7; runtime rule, README and launcher point at `C:\Godot\Godot_v4.7.2-stable_win64.exe`
  - [x] All 9 test scripts pass on 4.7.2 headless
  - [x] `TooltipStyler` still restyles real tooltips on 4.7.2 (`tools/screens/tooltip_screenshot.gd`)

---

## P1 — Close preproduction gaps (combat core)

Goal: meet roadmap Phase 1 exit criteria. The combat prototype must validate the rank system, the stress breakpoints, and short-mission pacing.

### P1-10 · S · Guard action (owner request 2026-11-07)
- Status: `done`
- Every hero turn offers **Guardia**: half physical damage (rounded up, min 1) until that hero's next turn; shown as "En guardia". All current enemy attacks are physical. `combat_controller.gd` (`guard()`, `_apply_damage_to_hero(..., physical)`), test `tests/test_guard.gd`.

### P1-11 · S · Four skills per class, with ally/party support (owner request 2026-11-07)
- Status: `done`
- +2 skills per existing class (doc 03 names). Skill `target`: enemy | self | ally | party. **Rule: every class has at least one ally or party skill** (checked by `tools/validate_data.py`). Ally target = hero clicked on the stage during the turn (default the acting hero). Stun/guard/block effects from doc 03 wait for P1-04.

### P1-12 · M · Enemy abilities + ailments (owner request 2026-11-07)
- Status: `done`
- Every enemy: 1 basic attack + 1–3 specials with Tico names (42 abilities across 15 enemies, `data/enemies.json`), chosen by weight. Magical attacks ignore Guard; the Mayordomo's *Golpe al escudo* ignores Guard too. Ailments `sangrado`, `veneno`, `aturdido` (`scripts/domain/status_effects.gd`) tick at the start of the unit's turn and clear after the fight; the venda cures bleeding, the ruda cures poison. Some specials drain light or steal colones. Rules in AGENTS.md §4 + doc 05 §2.7, enforced by the validator. Tests: `tests/test_status.gd`.

### P1-13 · S · Combat feedback (owner request 2026-11-08)
- Status: `review` (needs a human look in the running game)
- Floating numbers over the fighter that was hit: red `-N` damage, yellow `¡-N!` crits, green `+N` heals, purple `±N estrés`, grey `Falla` / `Esquiva`; a white-then-red hit flash with a shake. Ailments (sangrado, veneno, aturdido) and Guard are icons above the fighter with turns left and a tooltip (`res://assets/status/<id>.png`, coloured letter badge until the art exists). Code: `scripts/combat/battle_unit.gd` (`float_text`, `_refresh_status_icons`), hooks in `combat_controller.gd`. Test: `tests/test_feedback.gd`.
- Battle stage mirrored the same day: party on the right facing left, enemies on the left (AGENTS.md §4).

### P1-01 · M · Headless test harness
- Status: `in-progress` · Depends: — · Started: `tests/smoke_expedition.gd` (full expedition runs) and `tests/test_guard.gd` exist; still missing a single runner + resolver/stress unit tests.
- Spec: `01` §2–3
- Files: `tests/run_tests.gd` (new, `extends SceneTree`), `tests/test_*.gd`, `AGENTS.md` (add command)
- Done when:
  - [ ] `godot --headless --path . -s tests/run_tests.gd` runs all tests and exits non-zero on failure
  - [ ] Tests cover `CombatResolver` (hit clamp, crit cap, death save) and `StressSystem` (resolve at 100, Colapso at 200, Virtud reset)
  - [ ] Command added to AGENTS.md §3 verify step

### P1-02 · M · Multi-enemy squads (1–4 enemies)
- Status: `done` (2026-11-07) · Generator gives rooms `enemy_ids` squads (`squad_size` [1,3]; elite + escorts; boss + `boss_escort` 2 Sirvientes ahogados). Squad HP scaled by `SQUAD_HP_SCALE`. Every enemy takes turns; click an enemy to target it (default front). Smoke test fights squads of 3.
- Spec: `01` §2.1–2.2
- Files: `scripts/combat/combat_scene.gd`, `scenes/combat/combat_scene.tscn`, `scripts/autoload/game_state.gd` (`build_combat_context_for_node`), `data/regions/*.json`, `tools/validate_data.py`
- Done when:
  - [x] Region nodes accept `enemy_ids: [..]` (keep `enemy_id` as a 1-element fallback)
  - [x] Combat shows N enemies, each with HP and initiative; heroes pick a target
  - [x] Victory = all enemies dead
  - [ ] Validator checks hand-authored `enemy_ids` (generated squads use the pools, which are checked)

### P1-03 · L→ split · Battlefield ranks 1–4
- Split 2026-11-11 (owner: formation + a Move action first, push/pull later) into P1-03a and P1-03b.

### P1-03a · M · Formation: positions 1–4, rank-limited skills, collapse, "Moverse"
- Status: `review` (Claude Code, `main`, 2026-11-11; owner to play a few fights and check balance) · Depends: P1-02
- Spec: `01` §2.1, `03` "Position Notation", `05` §2.6 (enemy ranks)
- Files: `data/skills.json` (`use_ranks`, `target_ranks`), `data/heroes.json` (`ranks`), `data/enemies.json` (`ranks`, skill `target_ranks`), `scripts/domain/formation.gd` (new, pure), `scripts/combat/combat_controller.gd`, `scripts/expedition/expedition_screen.gd`, `scripts/ui/skill_button.gd`, `scripts/ui/skill_icon.gd`, `scripts/autoload/game_state.gd` (squad order), `scripts/hacienda/hacienda_hub.gd` (position hints), `tools/validate_data.py`, `tests/test_formation.gd`, `tests/smoke_expedition.gd`
- Done when:
  - [x] Each side has positions 1–4; skills disabled when the user's or target's position is invalid; enemy AI follows the same limits
  - [x] Dead units collapse forward (data and stage)
  - [x] "Moverse": swap with an adjacent hero, spends the turn; enemies with nothing in reach "se reacomodan"
  - [x] Hub lets the player order the party (↑/↓, since P3-01); now also hints each class's positions
  - [x] Unit tests (`tests/test_formation.gd`)

### P1-03b · M · Push, pull and shuffle effects
- Status: `review` (Claude Code, `main`, 2026-11-12; owner to try Retén / Patada and the Duende in a fight) · Depends: P1-03a
- Spec: `03` (Retén "pull enemy forward", Patada de Corral "push and stun chance"), `01` §2.5 (Control: stun, pull, push, root)
- Done when: [x] skills can push/pull enemies and heroes by N positions; [x] enemy skills that shuffle the party; [x] a status that stops moving (root: Amarrado) and its resist (Empujones); [x] fix the formation between fights (hero card)

### P1-04 · M · Status effect engine
- Status: `review` (all in, tested headless; needs a human playtest) · Depends: P1-02
- Owner 2026-11-08: every Darkest Dungeon status effect with Tico names. Definitions `data/statuses.json`; rules `scripts/domain/status_effects.gd`; combat hooks in `scripts/combat/combat_controller.gd`; icons/tooltips in `battle_unit.gd`. Effects: Sangrado, Envenenado, Atarantado → Espabilado, Salado, Fichado, Susto, Chiva, Encarrerado, Al cuido / Cuidando, Respondón, Sobado, Santiguado, Agazapado, Al Borde, Convaleciente. Stacking per application, 3-turn default, crit DoTs 5 turns, `status_resist` on enemies. Hero skills, enemy specials and two items (té de tilo, agua bendita) use them. Tests: `tests/test_status.gd` (50 checks).
- Done when:
  - [x] Supports bleed, stun, mark, guard at minimum; durations tick per round
  - [x] Initiative includes status speed changes; tie-breakers speed → resolve → random
  - [x] Status shown on unit UI (icons + tooltips)
  - [ ] Move / Shuffle (needs formation ranks, P1-03)
  - [ ] Art for the new status icons (letter badges until then)
### P1-05 · S · Spec-accurate Al Borde and crit stress
- Status: `review` (Claude Code, `main`, 2026-11-11; owner to feel the new death odds and crits in a few fights) · Depends: —
- Spec: `01` §2.3–2.4, §3.4. Owner 2026-11-11: surviving the death roll stays Al Borde at 0 PV; DD-style crit stress (hero crit relieves the party, enemy crits shock the hero hit).
- Files: `scripts/domain/combat_resolver.gd`, `scripts/combat/combat_controller.gd`, `scripts/domain/stress_system.gd`
- Done when:
  - [x] Death save chance drops for each prior Al Borde check in the same mission and for high stress
  - [x] Crits apply "stress shock" to the target side
  - [x] Damage formula includes `atkMods` / defense multipliers (0 by default)

### P1-06 · S · Balance constants to data
- Status: `review` (Claude Code, `main`, 2026-11-12) · Depends: P1-05. Owner 2026-11-12: also move the tunable limits (roster, inventory, recruits, graveyard); party size 4 stays in code.
- Spec: `04`, roadmap §8 item 1
- Files: `data/balance.json` (new), `scripts/domain/*.gd`, `scripts/autoload/game_state.gd`
- Done when:
  - [x] Hit band, crit cap/multiplier, death save base/decay, stress thresholds, shop prices are read from `data/balance.json`
  - [x] No magic balance numbers left in `scripts/domain/` (enforced by `tools/validate_data.py`)

### P1-07 · M · Combat Monte Carlo sim
- Status: `done` (Claude Code, `main`, 2026-11-12) · Depends: P1-06
- Spec: `04`, `06` Phase 1 "combat simulation sheet"
- Files: `tools/sim_combat.gd` (new). It is a headless Godot script, not the planned Python mirror. It runs the real `combat_controller.gd` (new `instant` flag) with stub units, so the rules can't drift. Options: `--chain`, `--policy`, `--set` (Balance overrides).
- Done when:
  - [x] Prints win rate, average turns, and stress delta per party-vs-node over N=10k runs
  - [x] Results for Sótanos written to `docs/10-implementation-notes.md`

### P1-08 · S · Technical architecture doc
- Status: `done` · Depends: P1-02, P1-04
- Spec: `06` Phase 1 deliverables
- Files: `docs/13-architecture.md` (new), `docs/README.md`
- Done when:
  - [x] Documents save schema + versioning, encounter flow (hub → map → combat → map), status engine, data file schemas (`docs/13-architecture.md`, also covers the map generator per doc 06)

### P1-09 · S · Paper/headless playtest + Phase 1 sign-off
- Status: `done` (owner signed off Phase 1 on 2026-11-17) · Depends: P1-03, P1-04, P1-07
- Spec: `09`, `06` Phase 1 exit criteria
- Files: `docs/09-paper-prototype-playtest.md` (notes section)
- Done when:
  - [x] One recorded playtest (human or sim-based) with notes (`tools/playtest_campaign.gd`, 48 expeditions; doc 09 §5, raw output in `docs/playtests/`)
  - [x] Owner marks Phase 1 exit criteria met → set **Current phase** to P2 (owner 2026-11-17)

---

## P2 — Vertical slice content (Sótanos complete)

Goal: roadmap Phase 2 scope. 1 region, 8 classes, 1 apex boss + 1 mini-boss, 30–40 events.

### P2-01 · M · Data-driven events (traps/curios/camp)
- Status: `review` (Claude Code, `main`, 2026-11-12; owner to try the new trap choices) · Depends: P1-06
- Curios: `data/curios.json` (key items, blind outcome tables). Traps: `data/traps.json` + `scripts/domain/trap_rules.gd` (DD disarm: best trampa + Luz − difficulty; "Pasar con cuidado" costs Luz). Camp: `data/camp_skills.json` (meals, respite, ambush, no-firewood relief). Curios and traps share one outcome vocabulary (`GameState.apply_event_outcome`), checked by the validator. The old "Con cuidado / A la rápida" trap was replaced on purpose (owner 2026-11-12, DD-style), so the old behaviour is not kept.
- Spec: `07`, `01` §4
- Files: `data/traps.json` (new), `scripts/domain/trap_rules.gd` (new), `scripts/expedition/expedition_screen.gd`, `scripts/domain/map_generator.gd`, `tools/validate_data.py`
- Done when:
  - [x] Trap/curio/camp choices and outcomes come from JSON (no hard-coded `_trap_fast`/`_curio_touch` etc.)
  - [x] Nodes reference `trap_id` / `curio_id` (generator pools per region); validator checks references
  - [x] ~~Existing behavior preserved as the first entries~~ replaced by the DD-style traps (owner 2026-11-12)
  - [ ] `humo_infernal` (doc 07's mid-combat smoke) — needs combat environment hooks; later

### P2-02 · M · 30–40 Sótanos event variants
- Status: `review` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-16): 36 events built and tested headless; owner to read the Spanish text and play a few rooms · Depends: P2-01
- Spec: `07`, `05` §1.1, `08` (tone)
- Files: `data/curios.json` (15 curios + 7 choice events), `data/traps.json` (5 traps), `data/regions/sotanos.json` (pools; the region pool is the tag, there is no separate `events.json`), `scripts/autoload/game_state.gd` (`curio_options`, `pick_curio_option`, `curio_can_leave`; outcome keys `light`, `stress_random`), `scripts/expedition/expedition_screen.gd` (`_open_curio`), `tools/validate_data.py`, `tests/test_expedition_systems.gd`
- Done when:
  - [x] ≥30 events tagged for `sotanos` (36), Spanish text, tone-reviewed against `08` by the agent (owner read pending)
- Follow-up: P2-10 (event conditions: after combat, low light).

### P2-10 · S · Conditions for choice events
- Status: `done` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-17) · Depends: P2-02
- Files: `data/curios.json` (`requires`, `fallback`, `missing_text`), `scripts/autoload/game_state.gd` (`rooms_since_fight`, `note_fight_won`, `curio_ready`, `room_curio`), `scripts/expedition/expedition_screen.gd` (`_open_curio`, victory), `tools/validate_data.py`, `tests/test_expedition_systems.gd`
- Spec: `07` §5 (Condition column)
- Done when: [x] Choice events can require a situation when the room is entered (`mercado_clandestino` after a fight, `vision_del_abuelo` at Luz ≤ 50); otherwise a fallback curio is used

### P2-11 · M · Retreat from a fight (found in P5-02)
- Status: `cut — done as P5-04 (Retirada) on betomm/happy-faraday-5yrmcr, merged 2026-11-17` · Depends: —
- Spec: `01` §5.3 (failure/retreat); Darkest Dungeon's combat retreat
- Why: in the P5-02 bot runs most deaths came from full wipes (16 of 25 in 48 expeditions). Once a fight turns there is no way out, so the deaths target (1 per 5–8 missions, doc 04 §4) can't be reached by numbers alone.
- Done when: [ ] a "Retirarse" combat action (chance by position/speed, failure costs the turn) that ends the expedition as a retreat; [ ] the campaign bot uses it when 2 heroes are Al Borde; [ ] re-measure deaths with `tools/playtest_campaign.gd -- --telemetry`

### P2-03 · M · Classes 5–8
- Status: `review` (done 2026-11-07 without ranks: Guachimán, Médica Josefina, Curandero Nicoyano, Exorcista in `heroes.json`, 4 skills each incl. ally/party support, guard-granting, cures and stun; hireable at the terminal. Rank constraints added in P1-03a) · Depends: P1-03, P1-04
- Spec: `03`. **Owner confirmed 2026-11-06:** classes 3 Guachimán Jubilado, 5 Médica Josefina, 6 Curandero Nicoyano, 9 Exorcista de Barrio.
- Files: `data/heroes.json`, `data/skills.json`, `assets/portraits/`
- Done when:
  - [x] 8 heroes, each with 4 skills
  - [ ] Rank constraints (P1-03)
  - [x] Portraits generated with SD metadata (`assets/portraits/{guachiman,medica_josefina,curandero,exorcista}.png`; hero ids should match these names)

### P2-04 · M · Sótanos enemy roster to ~12 units
- Status: `review` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-17): every doc 05 §2.6 gimmick built and tested headless; owner to play a few fights · Depends: P1-03, P1-04
- Spec: `05` §1.1, §2
- Files: `data/enemies.json` (gimmick fields, Embargo, Bendición torcida, Vigía mark + reinforce), `data/statuses.json` (Embargado), `data/regions/sotanos.json` (`squads`, `squad_template_pct`), `scripts/combat/combat_controller.gd` (gimmicks, `spawn_enemy`, `enemy_spawner`), `scripts/autoload/game_state.gd` (`make_enemy`, `expand_packs`), `scripts/domain/map_generator.gd` (`_template_squad`), `scripts/domain/item_effects.gd` (Embargado), `scripts/expedition/expedition_screen.gd` (`_spawn_enemy_unit`), `tools/sim_combat.gd`, `tools/validate_data.py`, `tests/test_enemies.gd`, `tests/test_formation.gd`
- Done when:
  - [x] Roster spec approved by owner 2026-11-06: `05` §2.6 (11 regulars incl. summon, Cadejo mini-boss, Mayordomo boss). Art for all of them already exists in `assets/enemies/`
  - [x] ≥12 Sótanos enemies with skills, ranks, statuses (13, each with its doc 05 gimmick); 3+ mixed squads used in the map (4 authored squads, 50% of regular fights)

### P2-05 · M · Bosses: Mayordomo Hundido (apex) + 1 mini-boss
- Status: `review` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-17): built and tested headless; owner to play the Mayordomo and meet the Cadejo in a Veterano run · Depends: P2-04
- Spec: `05` §3.1–3.2 (Mayordomo: summon servants, darkness pulses, anti-guard)
- Files: `data/enemies.json` (`summon`, `cycle`, `vs_guard_pct`, `flee_after`), `data/regions/sotanos.json` (`generator.roaming`; Cadejo out of the elite pool), `scripts/combat/combat_controller.gd` (`_boss_round_start`, cycle, anti-guard), `scripts/autoload/game_state.gd` (roaming: `_place_roaming`, `roaming_tick`, `build_roaming_context`, `finish_roaming`), `scripts/expedition/expedition_screen.gd` (roaming encounter + bounty), `scripts/expedition/map_view.gd` (red mark + tooltip), `tools/sim_policy.gd` (steps back into position), `tools/validate_data.py`, `tests/test_enemies.gd`
- Done when:
  - [x] **Owner confirmed 2026-11-06:** Mayordomo is the Sótanos final boss: the boss room of every generated map (the old static `n7`/`n9` layout is replaced by the P2-06 generator), with his 3 mechanics (servants every 3 rounds, max 2 per fight; Pulso de oscuridad every 4th round; Golpe al escudo +50% on guarding heroes)
  - [x] One roaming mini-boss with a spawn rule: Cadejo Negro, 50% Veterano / 75% Campeón, moves every 3 party moves, flees after 4 rounds, bounty when killed

### P2-06 · M · Random grid dungeon generator (owner spec 2026-11-07)
- Status: `review` (owner: play a few runs) · Depends: —
- Spec: owner request + `01` §4.2–4.3, `07`. Rooms sit on a grid and connect up/down/left/right. Branching is random: some rooms have one exit, others several. The **last room is always the region boss** (Sótanos: El Mayordomo Hundido), placed farthest from the entrance.
- Files: `scripts/domain/map_generator.gd` (new, pure), `data/regions/sotanos.json` (`generator` block), `scripts/autoload/game_state.gd`, `scripts/domain/expedition_loader.gd` (undirected edges)
- Done when:
  - [x] Seeded generation; start → boss always reachable; boss room = farthest dead end, ≥5 rooms away (`python3 tools/preview_map.py --check 3000`: 0 problems)
  - [x] Room types weighted from region data (combat, elite, trap, curio, camp, empty); one camp mid-way
  - [x] Fog: only visited rooms and their neighbors are drawn; boss room always marked
  - [x] Hand-authored region files (Bosque) still load (directed edges unchanged)

### P2-07 · S · Bosque: decide slice status
- Status: `done`
- Notes: **Owner decision 2026-11-06: Bosque moves to the Alpha phase.** Hidden from the hub picker via `GameState.PLAYABLE_REGIONS`; data and art kept. Old saves pointing at Bosque fall back to Sótanos. Re-enable in Alpha by adding it back to `PLAYABLE_REGIONS`.
- Done when:
  - [x] Decision recorded in HANDOFF; picker updated accordingly

### P2-08 · S · Each class has its own basic attack (owner request 2026-11-11)
- Status: `review` (Claude Code, `main`, 2026-11-11; owner to try the three new attacks in a fight) · Depends: —
- Spec: owner "I want each class to have their own basic attack"; AGENTS.md §4 (Tico names that fit the class); weapons from `tools/art_manifest.json` sprite entries
- Files: `data/skills.json`, `data/heroes.json`, `scripts/ui/skill_icon.gd` (glyphs), `scripts/autoload/game_state.gd` (save v9: loadouts follow the class, ranks carried over), `tools/validate_data.py` (no skill shared between classes), `tests/test_progression.gd`
- Done when: [x] Abuela, Tecnólogo and Montador no longer use Machetazo (Cucharonazo, Corrientazo, Mecatazo); [x] no skill id is shared by two classes, and every class starts with an attack (validator); [x] old saves swap the skill and keep its rank (save v9)

---

## P3 — Hacienda baseline (campaign loop)

### P2-09 · M · Curios per doc 07 + item and camp fixes
- Status: `review` (Claude Code, `main`, 2026-11-12; owner to try the new bad outcomes) · Depends: P2-01
- Spec: `07` §3, §6
- Files: `data/curios.json`, `scripts/autoload/game_state.gd` (`apply_event_outcome`), `scripts/domain/camping_system.gd`, `scripts/combat/combat_controller.gd`, `scripts/expedition/expedition_screen.gd`
- Done when:
  - [x] Bad blind outcomes per doc 07: Maldición del altar (curse), the caja's ambush (mimic), Susto from the pozo, Fiebre del árbol (disease stand-in), the radio's noise ambush; Limpia de ruda buff with the key item
  - [x] Event curses/blessings live with the camp buffs (counted down per fight), shown red/gold with their source
  - [x] Thrown items respect Santiguado; camp ambush gets doc 07's exhausted +4%
  - [ ] Real diseases (P3-06 Clínica) replace the Fiebre stand-in

### P3-01 · M · Weekly tick + roster lifecycle
- Status: `review` (done 2026-11-07: `GameState.end_of_expedition_week()` — +1 week after every expedition, fallen heroes removed for good, Al Borde cleared, recruits rotate; roster up to 8, party of 4 chosen and ordered in the hub; save v5 with v4 migration; `tests/test_hub.gd`) · Depends: —
- Spec: `02` §1, §12
- Files: `scripts/autoload/game_state.gd`, `scripts/hacienda/hacienda_hub.gd`
- Done when:
  - [ ] Single `advance_week()` does the recruit refresh, market rotation, and recovery resolution (today `week += 1` is scattered in 2 places)
  - [ ] Roster > 4 heroes; choose 4 for a mission; dead heroes leave the roster

### P3-02 · M · Terminal de Buses (recruitment)
- Status: `review` (done 2026-11-07: 3 weekly candidates from all 8 classes with Tico names per class, `hire_cost` per class, roster cap 8) · Depends: P3-01, P2-03
- Spec: `02` §3
- Done when: [ ] Weekly recruit pool, hire cost, roster cap

### P3-03 · M · Iglesia Vieja + Cantina (stress duality)
- Status: `review` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-16): built and tested headless; owner to play-test prices, relief and side-effect odds · Depends: P3-01
- Spec: `02` §7
- Files: `data/hub_activities.json`, `scripts/domain/hub_activities.gd`, `scripts/autoload/game_state.gd` (`send_to_activity`, `cancel_activity`, `_resolve_hub_activities`, party lock, save v10), `scripts/hacienda/hacienda_hub.gd` (panel under the misa button, busy tag on the roster), `scripts/domain/town_events.gd` (`cantina` service), `tools/validate_data.py`, `tests/test_hub_activities.gd`, `tools/screens/relief_screenshot.gd`
- Done when: [x] Both buildings with activities, slots, and side effects; [x] heroes are busy for the week
- Follow-ups: P3-18 (Iglesia/Cantina upgrade tracks).

### P3-04 · M · Casa Comunal (skills) + hero XP/resolve level
- Status: `review` (Claude Code, `main`, 2026-11-11): everything built and tested headless; owner to play-test ranks and balance · Depends: P3-01
- Spec: `02` §4, `04`, `01` §6.1, §6.3
- Files: `data/progression.json` (`skill_ranks`), `scripts/domain/resolve_system.gd`, `scripts/domain/skill_ranks.gd`, `scripts/autoload/game_state.gd` (difficulty, under-level penalty, `complete_mission`, `hero_skill`, `buy_skill_rank`, save v8), `scripts/hacienda/hacienda_hub.gd` (difficulty picker, level/XP per hero, Casa Comunal row), `scripts/ui/skill_button.gd` (rank pips, `body_for`), `tests/test_progression.gd`, `tools/screens/skills_screenshot.gd`
- Done when: [x] Heroes gain resolve XP per mission; [x] levels 0–6 add resistances; [x] difficulty gating (refuse / under-leveled penalty); [x] skill ranks purchasable; [x] per-region level on top of the picker (owner 2026-11-08, Sótanos easiest)
- Follow-ups: P3-16 (building upgrade tracks), P3-17 (skill unlocks).

### P3-05 · M · Taller (equipment) + Feria Nocturna (trinkets)
- Status: `todo` · Depends: P3-04
- Spec: `02` §5, §8
- Done when: [ ] Weapon/armor tiers; trinket slots with market rotation

### P3-06 · M · Clínica de Espantos + quirks
- Status: `review` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-17): built and tested headless; owner to read the quirk names and try the Clínica · Depends: P3-01
- Spec: `02` §6, `01` §3
- Files: `data/quirks.json` (new), `data/balance.json` (`quirks`), `scripts/domain/quirks.gd` (new), `scripts/domain/status_effects.gd` (`stat`), `scripts/autoload/game_state.gd` (`_roll_expedition_quirks`, `clinic_options`, `clinic_treat`, recruits, refusals, save v12), `scripts/hacienda/hacienda_hub.gd` (Clínica button + card, roster tooltip), `scripts/domain/town_events.gd` (`clinica` service), `tools/validate_data.py`, `tests/test_quirks.gd` (new), `tests/test_hub_activities.gd`, `tools/screens/clinic_screenshot.gd` (new)
- Done when: [x] Positive/negative quirks gained on missions (plus diseases); [x] treatment in Clínica (remove negatives, lock/remove positives, cure diseases; doc 04 §3.5 prices; one of each per week)
- Note (owner 2026-11-16): quirks may lock a hero out of an Iglesia/Cantina activity or tie them to one (DD "won't go to the church" / "only drinks"). Quebrantos never block activities: activities are how a Quebranto is cured.

### P3-19 · S · Clínica treatments keep the hero home for the week (owner 2026-11-17)
- Status: `done` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-17) · Depends: P3-06
- Files: `scripts/autoload/game_state.gd` (`in_clinic`, `hero_busy`, `busy_place`, `clinic_options`, `clinic_treat`), `scripts/hacienda/hacienda_hub.gd`, `tools/playtest_campaign.gd`, `tests/test_quirks.gd`
- Spec: `02` §6; owner answer to the P3-06 question ("like the Iglesia and Cantina, the Darkest Dungeon way")
- Done when: [x] a treated hero leaves the cuadrilla and can't rejoin or book the Iglesia/Cantina until the week ends; a hero already booked elsewhere can't be treated; the last free hero can't be treated; test

### P3-07 · S · Guardabosques (camp skills)
- Status: `review` (Claude Code, `betomm/amazing-clarke-lv3whd`, 2026-11-08; owner asked for it ahead of P2-01) · Depends: P2-01
- Spec: `02` §9, `01` §4.4
- Files: `data/camp_skills.json` (19 skills, meals, ambush), `data/heroes.json` (`camp_skill_ids`), `scripts/domain/camping_system.gd`, `scripts/expedition/expedition_screen.gd` (camp flow, ambush), `scripts/combat/combat_controller.gd` (surprise round, buffs tick per fight), `scripts/domain/status_effects.gd` (`stat()` reads camp buffs)
- Done when: [x] Camp node uses per-hero camp skills instead of the fixed "feast/skip"; [x] meal tiers, 12 respite, 4-fight buffs, night ambush with surprise round, Luz back to 100
- Follow-up: P3-13 (Guardabosques building: learn/swap camp skills).

### P3-15 · M · Town events, Modo Pura Vida (owner request 2026-11-08)
- Status: `review` (Claude Code, `betomm/amazing-clarke-lv3whd`, 2026-11-08) · Depends: P3-04
- Spec: `02` §12, §12.1; `01` §6.1 (Pura Vida, Mano vuelta); owner: "add the two exceptions, that town event, and something similar to each of the other Darkest Dungeon town events with Tico flavour"
- Files: `data/town_events.json` (56 events), `scripts/domain/town_events.gd`, `GameState` (event state, prices, services, mission modifiers, graveyard, thief, offers, `radiant_mode`, save v7), `hacienda_hub.gd` (event card, Pura Vida checkbox, live prices), `main.gd`, `tests/test_town_events.gd`, validator
- Done when: [x] every DD town event has a Tico version; [x] Mano vuelta and Pura Vida lift level limits; [ ] owner reviews the texts (doc 08 tone) and balance

### P3-13 · S · Guardabosques building: learn and swap camp skills
- Status: `review` (Claude Code, `betomm/trusting-hamilton-bga408`, 2026-11-19) · Depends: P3-07, P3-20
- Spec: `02` §9; owner 2026-11-19: "start knowing 3" (of the 6 class camp skills), upgrade tracks later
- Files: `data/balance.json` (`camp.*`), `data/town.json` + `assets/town/guardabosques.png` + `assets/town/painted/` (the shed split off the Cantina crop), `scripts/domain/camping_system.gd` (`starting_known`, `known_ids`, `fixed_id`, `deal_hand`), `GameState` (learn/fix/swap, save v13), `hacienda_hub.gd/.tscn` (page `guardabosques`, hero sheet), `tools/playtest_campaign.gd`, `tools/art_manifest.json` (`town_guardabosques`), validator, `test_progression`, `test_ui`
- Done when: [x] a new hero knows 3 of 6 class camp skills; the fogata draws only known ones; [x] learn / fix / let go / swap shared, with prices in balance.json; [x] town building + page; old saves know all 6; [x] tests; [x] prices approved (owner 2026-11-19); [x] town events close or discount it (service `guardabosques`, 2 new events); [ ] owner playtest; [ ] upgrade tracks (P3-21)

### P3-21 · S · Guardabosques upgrade tracks
- Status: `todo` · Depends: P3-13, P3-16 (building-upgrade system)
- Spec: `02` §9 (Guía de Supervivencia: 3 class skills per fogata, later stronger camp skills; Entrenamiento de Patrulla: cheaper lessons and fixing)
- Done when: [ ] both tracks buyable with materials; [ ] `class_skills_per_camp` and `camp.*` prices read through the track level

### P3-20 · S · Random class camp skills at every fogata (owner request 2026-11-19)
- Status: `review` (Claude Code, `betomm/trusting-hamilton-bga408`, 2026-11-19) · Depends: P3-07
- Spec: owner: "add 4 more possible class specific respiros, they will be randomized on every campfire"; `01` §4.4
- Files: `data/camp_skills.json` (32 new class skills, `class_skills_per_camp`), `data/heroes.json` (`camp_skill_ids` = the 2 shared skills), `scripts/domain/camping_system.gd` (`shared_skills`, `class_pool`, `deal_hand`, `hand_skills`), `scripts/expedition/expedition_screen.gd` (`_camp_hands`, `camp_hand`), `scripts/hacienda/hacienda_hub.gd` (hero sheet), `tools/playtest_campaign.gd`, `tools/validate_data.py`, `tests/test_progression.gd`
- Done when: [x] every class has 6 class camp skills (2 old + 4 new, Tico names); [x] each fogata deals every hero their 2 shared skills + 2 random class skills; [x] hero sheet shows the pool; [x] validator + test; [ ] owner reviews names/balance
- Note: P3-13 builds on this (owner 2026-11-19: heroes start knowing 3 of the 6).

### P3-16 · M · Casa Comunal building upgrades
- Status: `todo` · Depends: P3-04, a building-upgrade system (materials, doc 02 §11)
- Spec: `02` §4 (upgrade tracks), `04` §3.3 (discount up to 50% at cap)
- Done when: [ ] Maestría de Oficio raises the max skill rank (start lower than 5); [ ] Plan de Formación lowers rank prices up to 50%

### P3-18 · S · Iglesia Vieja + Cantina upgrade tracks
- Status: `todo` · Depends: P3-03, a building-upgrade system (materials, doc 02 §11)
- Spec: `02` §7 (upgrade pattern)
- Done when: [ ] Per-activity upgrades: more relief, lower cost, more slots, repeated for higher tiers (data in `data/hub_activities.json`)

### P3-17 · S · Unlockable skills
- Status: `todo` · Depends: classes having more than 4 skills (doc 03)
- Spec: `02` §4, `04` §3.3 ("Unlock new skill: 1,000 base")
- Done when: [ ] Classes have extra skills to unlock at the Casa Comunal and pick 4 to take on an expedition

### P3-14 · S · Level-tiered hub prices
- Status: `todo` · Depends: P3-04
- Spec: `04` §3.5 (treatment tiers by resolve 0–2 / 3–4 / 5–6)
- Done when: [ ] EBAIS / Iglesia / future Clínica prices scale with the hero's resolve tier

### P3-11 · M · Equipment and elements (owner request 2026-11-07)
- Status: `review`
- 25 Tico-themed pieces in `data/items.json` (`usable: equip`): 9 weapons (some typed: Machete bendito = sagrado, Tizón de fogón = fuego…), 7 armors, 9 accessories (immunities, element resistances, speed, dodge, stress resistance). 1 weapon + 1 armor + 2 accessories per hero; `GameState.equip/unequip/recompute_stats`. Drag-and-drop from the inventory to equipment slots (hub and expedition hero panel) or onto a hero on the stage; click a slot to unequip. In combat only the hero whose turn it is can change gear, and it spends the turn (owner 2026-11-08).
- 8 classic elements; every enemy has affinities; enemy magic skills carry elements. Hero attacks use the weapon's element; armor protection reduces physical damage before Guard; resistances scale elemental damage; immunities block ailments; stress resistance lowers stress taken. Enemy tooltips show weaknesses. Bombeta is fuego.
- Tests: `tests/test_equipment.gd` (17 checks). Icons for the 25 pieces are in the art manifest (P4-10).
- 2026-11-07 additions (owner): 64 items total. +12 consumables (incl. elemental throwables, two with stun), dark weapon (Puñal del Portón), armors for earth/wind/holy (every element now has a weapon and an armor), +11 accessories incl. **Lentes del abuelo** (`scout`: party sees exact HP, attacks and affinities in the enemy info panel; without it only health %). Caja del abuelo + llave = random 250–700 ₡ + random equipment. Owner note: items may target enemies/situations that don't exist yet; that's intended.
- Follow-ups: class restrictions on weapons? Balance (fights got longer with squads + armor: ~100 hero turns per expedition in the smoke test).

### P3-12 · S · Dismiss heroes (owner request 2026-11-07)
- Status: `review` · "Despedir" on each roster row, with confirmation. Equipment goes back to the inventory (refused if it doesn't fit); the last hero can't be dismissed. `GameState.dismiss_hero`, covered in `tests/test_hub.gd`.

### P3-10 · S · EBAIS healing in the hub (owner request 2026-11-07)
- Status: `review` · Each roster row has "EBAIS N ₡": full HP for `HEAL_COST_PER_HP` (15) per missing HP, minimum `HEAL_MIN_COST` (100). Constants in `game_state.gd`.

### P3-09 · M · Items, inventory and Pulpería (owner spec 2026-11-07)
- Status: `review` (owner: try the Pulpería in Godot) · Depends: —
- Spec: owner request. Tico-themed consumables in `data/items.json`. Using an item **in combat spends the hero's turn**. **Out of combat each hero can use each item `uses_per_node` times per room (default 1); the limit is per character, not per team (owner, 2026-11-07)**. Bought at the hacienda's Pulpería. Food and light become items (gallo pinto, candela) instead of hub counters. Curio-key items (llave, mecate, agua bendita, ruda) prepare `07` curio interactions.
- Files: `data/items.json` (new), `scripts/autoload/game_state.gd` (inventory, per-room use counts, save v4 + migration of `hub_pending_*`), `scenes/hacienda/hacienda_hub.tscn` + `.gd` (Pulpería replaces rations/lantern buttons), `tools/validate_data.py`
- Done when:
  - [x] Inventory saved (save v4, migrates old hub purchases); buy at Pulpería; per-room limit enforced outside combat
  - [x] Effects: heal, stress, light, damage, hp_risk; validator checks item data
  - [x] Curio-key items do something at curios: `data/curios.json` (altar roto ← agua bendita, caja del abuelo ← llave, pozo seco ← mecate, árbol amarillo ← ruda, radio vieja ← new batería de radio, which reveals the map). Generator assigns a curio to each curio room.

### P4-09 · L · Unified expedition screen (owner spec 2026-11-07)
- Status: `review` (owner: play-test in Godot; written without running Godot) · Depends: P2-06, P3-09, P4-07
- Spec: owner screenshots of the reference layout. **One screen** for exploring and fighting:
  - **Top:** stage with the party; enemies appear in place when a fight starts. Event panels (trap, curio, camp) open over the stage.
  - **Bottom left:** hero panel showing the hero whose turn it is. Clicking any hero on the stage shows that hero's data instead.
  - **Bottom right:** room map, moving room by room with arrows or by clicking a neighbor. A side button flips this panel to the inventory grid (use items there).
- Files: `scenes/expedition/expedition_screen.tscn` + `scripts/expedition/expedition_screen.gd` (new), `scripts/expedition/map_view.gd` (new), `scripts/combat/combat_controller.gd` (combat rules moved out of `combat_scene.gd`), `scripts/bootstrap/main.gd`. Old `expedition_map` and `combat_scene` are removed once replaced.
- Done when:
  - [x] Explore → fight → explore without changing scenes; boss room ends the mission on victory
  - [x] Hero panel follows the turn; clicking a hero shows that hero
  - [x] Map and inventory toggle (tabs or M / I keys); arrows, arrow keys or clicking a neighbor room to move; items usable in and out of combat with the rules above
  - [x] Verified running in Godot 4.6.2 headless (`tests/smoke_expedition.gd`: 3 expeditions to boss victory, 0 failures)

### P4-11 · S · Victory screen after a completed expedition (owner request 2026-11-08)
- Status: `review` (Claude Code, `betomm/amazing-clarke-lv3whd`, 2026-11-08) · Depends: P3-04
- Spec: `01` §6.2; owner screenshots (DD-style rewards page + per-hero Resolve XP cards)
- Files: `scripts/expedition/victory_screen.gd` (new), `scripts/bootstrap/main.gd`, `GameState.mission_ledger`/`complete_mission`, `tools/screens/progression_screenshot.gd`
- Done when: [x] page 1 rewards (encargo, loot, items, fights/curios/camps); [x] page 2 hero cards (XP, level badge + bar, level-up, new Quebranto/Virtud, fallen); [ ] owner looks at it in-game

### P1-14 · S · Seven Quebrantos and seven Virtudes (owner request 2026-11-08)
- Status: `review` (Claude Code, `betomm/amazing-clarke-lv3whd`, 2026-11-08) · Depends: —
- Spec: `01` §3.3
- Files: `scripts/domain/stress_system.gd`, `data/statuses.json` (`mental_mods`), `scripts/domain/status_effects.gd`, `scripts/combat/combat_controller.gd`, `scripts/combat/battle_unit.gd`
- Done when: [x] 7 + 7 with hooks; Paranoia refuses heals/buffs per spec instead of skipping turns; [x] names shown everywhere

### P1-16 · S · Shared hero damage rule outside combat (bug)
- Status: `done` (Claude Code, `main`, 2026-11-12) · Depends: —
- Owner 2026-11-12: trap and curio damage follows the combat rule (Al Borde, then the death roll; heroes can die).
- Files: `scripts/domain/hero_damage.gd` (new), `scripts/combat/combat_controller.gd`, `scripts/expedition/expedition_screen.gd`, `scripts/autoload/game_state.gd`
- Done when:
  - [x] Trap and curio damage use the same Al Borde / Golpe de gracia rule as combat; a wipe outside combat ends the expedition
  - [x] Test in `tests/test_expedition_systems.gd`

### P1-17 · M · Luz tiers (DD torch)
- Status: `review` (Claude Code, `main`, 2026-11-12; owner to feel the tiers in a run) · Depends: P1-16
- Owner 2026-11-12: full DD-style tiers (enemy danger, stress, loot, surprise, trap disarm) and "Apagar la candela".
- Files: `scripts/domain/light_system.gd` (new), `data/balance.json` (`light.*`), `combat_controller.gd`, `expedition_screen.gd`, `game_state.gd`, region JSONs
- Done when:
  - [x] 5 tiers from data affect enemy damage/crit, hero stress, loot, surprise and trap disarm (`trap_pct`, used by the traps in P2-01); per-move stress in the dark
  - [x] Faster decay (8 per move), "Apagar la candela", tier shown on the HUD; camp resets to `light_max()`; doc 07 "exhausted party" +4% camp ambush
  - [x] Owner 2026-11-12: heroes lose accuracy in the dark (`hero_accuracy`: Penumbra −3, Oscuro −6, Negro −10)

### P1-18 · M · Travel hunger + provisions
- Status: `review` (Claude Code, `main`, 2026-11-12; owner to try the hunger stop and the provisions prompt) · Depends: P1-16
- Owner 2026-11-12: every 6 moves the party eats 1 gallo pinto per living hero; a hero who can't eat takes −10% PV (never below 1) and +10 stress; a camp meal resets the count.
- Files: `data/balance.json` (`hunger.*`), `scripts/domain/camping_system.gd`, `game_state.gd`, `expedition_screen.gd`, `scripts/hacienda/hacienda_hub.gd`, region JSONs (`provisions`)
- Done when:
  - [x] Hunger event every 6 moves (eat / share / go hungry); camp meal resets it
  - [x] Hub warns about missing recommended provisions and can buy them
  - [x] Owner 2026-11-12 asked for a price recommendation: gallo pinto 75 ₡, candela 100 ₡, fósforos 60 ₡ (full Sótanos kit 1,050 ₡ ≈ 30% of a run, DD ratio; doc 04 §3.1)

### P1-19 · S · Tests and tools must not touch the real save
- Status: `done` · Depends: —
- Why: `SaveService._ready` loads and rewrites `user://save.json` on every Godot start, headless tests and the sim included. Two instances at once can read a half-written file; the one that fails starts a new game and saves it over the owner's save. This happened on 2026-11-12 while sims ran in parallel: the dev save went back to week 1.
- Files: `scripts/autoload/save_service.gd`, maybe `project.godot` (a test feature tag or command-line flag)
- Done when:
  - [x] Running a `-s` script (tests, `tools/sim_combat.gd`, `tools/screens/*`) never writes `user://save.json` (for example, skip save/load when `OS.get_cmdline_args()` has `-s`/`--script`, or use a separate save path)
  - [x] A failed load never overwrites the existing file (write to a temp file, then rename; keep a `.bak`)
  - [x] `tests/test_save.gd` (17 checks); the real save's md5 is unchanged after the whole suite

### P1-20 · S · Smoke expedition sometimes runs out of frames
- Status: `todo` · Depends: —
- Why: `tests/smoke_expedition.gd` stops after `MAX_STEPS` (3000 frames). About 1 run in 27 (2026-11-12) has a fight that doesn't end in time ("expedition ended () after 4 moves, 288 hero turns"); normal runs already reach ~250 hero turns. Fights got longer with hero accuracy in the dark (P1-17), and the bot plays badly (it often presses the first skill).
- Files: `tests/smoke_expedition.gd`
- Done when:
  - [ ] The smoke passes 30 runs in a row (raise `MAX_STEPS`, cap a fight's rounds in the bot, or seed `randi`), and still fails when an expedition really hangs

### P1-21 · S · A lone hero stuck where none of their skills work
- Status: `done` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-17) · Depends: —
- Spec: `01` §2.1 (formation)
- Files: `scripts/domain/formation.gd` (`can_use`), `tests/test_formation.gd`, doc 01 §2.1
- Found in P2-05 sim runs (about 1 stall in 300 chains): the last hero standing (e.g. the Tecnólogo) ends up in position 1, where none of their attacks can be used, and can't Moverse with nobody beside them. The fight never ends.
- Done when: [x] a lone hero can always act on the enemy, with a test. The last one standing on a side ignores `use_ranks`; `target_ranks` still apply.

### P1-15 · M · Expedition sim: camp, items and room events in the chain mode
- Status: `todo` · Depends: P1-07, P2-01 (data-driven traps/curios/camp)
- Spec: doc 10 "Combat sim (P1-07)", `06` (55–70% mission success)
- Files: `tools/sim_combat.gd`
- Why: P1-07's `--chain` covers fights only, with no camp, potions, traps, curios, light or hunger. So it can't measure mission success yet, and P5-02 needs that.
- Done when:
  - [ ] Chains follow a generated map path (rooms in order) with the starting provisions
  - [ ] The policy uses heal and stress items and camps once
  - [ ] Prints the mission success rate, for comparison with the 55–70% target

### P4-10 · S · Item icons
- Status: `review` (all 64 generated 2026-11-07: dark painted style, 128×128, opaque dark background, candle-free; gallo pinto and venda redone once) · Depends: P3-09 · Generate one icon per item into `assets/items/<id>.png` via the manifest.

### P4-12 · S · Pulpería icon tiles + item tooltip card (owner request 2026-11-09)
- Status: `review` (Claude Code, `betomm/tender-brown-x04ghq`, 2026-11-09; owner to look at it in-game) · Depends: P3-09, P4-10
- Spec: owner request: the Pulpería shows item icons like the alforja instead of long text rows; a better-designed, opaque item tooltip.
- Files: `scripts/ui/shop_slot.gd` (new), `scripts/ui/item_tooltip.gd` (new), `scripts/ui/inventory_slot.gd`, `scripts/ui/equip_slot.gd`, `scripts/hacienda/hacienda_hub.gd` + `.tscn` (`ShopGrid` is an `HFlowContainer`), `GameState.item_tooltip_parts`, `tools/screens/shop_screenshot.gd`
- Done when: [x] store tiles = icon + this week's price (green when cheaper, red when dearer, "cerrado" when an event blocks it); [x] one opaque card (icon, name, category chip, description, one line per effect, where it is used, buy/sell price, hint or warning) for the store, the alforja, equipment slots and the combat alforja; [ ] owner looks at it in-game

### P4-13 · S · Defeated enemies: not selectable, drawn behind the living (owner request 2026-11-09)
- Status: `review` (Claude Code, `betomm/tender-brown-x04ghq`, 2026-11-09; owner to look at it in-game) · Depends: P4-07
- Files: `scripts/combat/battle_unit.gd` (`DEAD_Z`, `_apply_dead_look`, `_gui_input`), `scripts/expedition/expedition_screen.gd` (`_on_unit_clicked`), `scenes/expedition/expedition_screen.tscn` (background at z -2), `tests/test_feedback.gd`
- Done when: [x] a defeated enemy ignores the mouse (no click, no tooltip, no info panel; clicks reach the living enemy next to it); [x] fallen fighters (enemies and heroes) draw behind living ones; [ ] owner looks at it in-game

### P4-14 · S · One tooltip design for the whole game (owner request 2026-11-09)
- Status: `review` (Claude Code, `betomm/tender-brown-x04ghq`, 2026-11-09; owner to look at it in-game) · Depends: P4-12
- Spec: owner request: style all tooltips with a better design. Content of skill/status/stress tooltips is still P4-02.
- Files: `scripts/ui/tooltip_card.gd` (new, shared look), `scripts/autoload/tooltip_styler.gd` (new autoload `TooltipStyler`), `project.godot`, `scripts/ui/item_tooltip.gd`, `scripts/ui/skill_button.gd`, `scripts/ui/equip_slot.gd`, `tools/screens/tooltip_screenshot.gd`
- Done when: [x] every plain `tooltip_text` tooltip (hub, expedition, status icons, map, option lists) shows as the opaque card, with "Title\nbody" or "Title — body" split into a gold title and wrapped body; [x] skill and item tooltips use the same card; [ ] owner looks at it in-game

### P4-15 · M · Menus in the item-card style (owner 2026-11-17)
- Status: `review` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-17): owner to look at the screenshots / play the hub · Depends: —
- Files: `scripts/ui/ui_theme.gd` (new), `scripts/ui/hero_card.gd` (new), `scripts/ui/card_button.gd` (new), `scripts/ui/tooltip_card.gd` (`chip`, `picture`, `section`, `is_bad_line`), `scripts/autoload/tooltip_styler.gd` (sets the theme), `scripts/hacienda/hacienda_hub.gd` (Clínica, event, provisions and dismiss cards; hover cards on activities, candidates and the roster), `scripts/expedition/victory_screen.gd` (section bars), `tests/test_ui.gd` (new), `tools/screens/clinic_screenshot.gd`
- Spec: owner request "make all menus better in the UX, including Clínica de Espantos, similar to the style of the item tooltips"; style source `scripts/ui/tooltip_card.gd`, `scripts/ui/item_tooltip.gd`
- Done when: [x] one UI theme in the card palette for buttons, dialogs, option buttons and check boxes; [x] the Clínica, the town-event card and the hub confirmations are built from card parts (header, chips, rules, bullets); [x] hub menus that list things (Iglesia/Cantina activities, recruits, roster) show item-style cards on hover; [x] screenshots for review

### P4-16 · S · Skill tooltips stay up during a fight (owner 2026-11-17)
- Status: `done` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-17) · Depends: P4-15
- Files: `scripts/expedition/expedition_screen.gd` (`_bar_begin` / `_bar_button` / `_bar_end` / `_lock_skills`), `scripts/ui/skill_button.gd` (`setup` can be called again, `action`), `tests/test_ui.gd`, `tests/smoke_expedition.gd`
- Spec: owner "the tooltips for skills in mid battle disappear when something makes an action, it should always stay on"
- Done when: [x] the combat bar keeps its buttons from turn to turn (refilled in place), so the hovered button is never freed and its tooltip stays; [x] after a hero acts the bar stays up, locked, until the next hero's turn; [x] test

### P4-17 · L · Town view: clickable buildings, Darkest Dungeon style (owner 2026-11-17)
- Status: `review` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-17): owner to look at the screenshots / play the hub · Depends: P4-15
- Spec: owner request with a screenshot of the Darkest Dungeon hamlet: "change the main town view to look like this; each building clickable and highlighted on hover; a click opens that building's menu; keep the Tico style and be true to the design of each place". Buildings: doc 02 §2.
- Files: `data/town.json` (new), `scripts/hacienda/town_building.gd` (new), `scripts/hacienda/hacienda_hub.gd`, `scenes/hacienda/hacienda_hub.tscn`, `assets/town/` (new art), `tools/art_manifest.json`, `tools/sd_cutout.py` (new), `tests/test_ui.gd`, `tests/test_hub_activities.gd`, `tests/test_quirks.gd`, `tools/screens/town_screenshot.gd` (new), `tools/screens/clinic_screenshot.gd`, `docs/02` (town view)
- Done when: [x] the hub is a painted town with one picture per building (Terminal, Casa Comunal, Taller, Clínica, Iglesia, Cantina, Pulpería), the roster on the right and a bottom bar (colones, week, region, difficulty, start); [x] hovering a building highlights it and names it; [x] clicking opens that building's menu; [x] buildings closed by a town event look closed; [x] screenshot for review

### P4-18 · S · Equipment sold at the Taller, consumables at the Pulpería (owner 2026-11-17)
- Status: `review` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-17): owner to look at it in-game · Depends: P4-17
- Files: `scripts/autoload/game_state.gd` (`shop_of`, per-shop closures, `sell_item(id, shop)`), `scripts/domain/town_events.gd`, `scripts/hacienda/hacienda_hub.gd` + `scenes/hacienda/hacienda_hub.tscn` (shop on the Taller page, shared sell mode), `data/town_events.json` (El herrero anda de buenas; Corte de luz also closes the Taller's buying), `data/town.json`, `tools/validate_data.py`, `tests/test_hub.gd`, `tests/test_town_events.gd`, `AGENTS.md`, `docs/02`
- Spec: owner "make the weapons, armours and accessories also be sold at the taller and the pulpería will only sell consumables"
- Done when: [x] the Pulpería lists only consumables; [x] the Taller lists weapons, armor and accessories with a filter and buys used equipment back; [x] town-event closures are per shop; [x] tests; [x] each shop buys back only what it sells (owner decision 2026-11-17: the Pulpería no longer buys equipment)

### P4-19 · M · The town painted as one picture (owner 2026-11-17)
- Status: `review` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-17): owner to look at it in-game · Depends: P4-17
- Files: `tools/town_paint.py` (new), `assets/town/town_painted.png`, `assets/town/painted/` (crops + `layout.json`), `assets/town/filler/` (unclickable houses), `data/town.json` (`filler`), `scripts/hacienda/hacienda_hub.gd` (`Painting`, crops placed at their rects), `AGENTS.md`, `docs/02`
- Spec: owner "make the buildings make sense in their design; right now they look like a collage of splattered images and not like a town"
- Done when: [x] the town is one painting with shared light, ground and fog (layout → SD img2img + ControlNet canny); [x] each building is its crop of that painting, so hover and clicks stay exact; [x] the buildings keep their identity (bus, white church, blue-and-yellow pulpería, forge, cantina lights); [x] screenshot

### P4-20 · S · Dev menu (owner 2026-11-19)
- Status: `done` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-19) · Depends: P4-17
- Files: `scripts/autoload/game_state.gd` (`dev_set_infinite_money`, `dev_skip_week`, `dev_add_resolve`; `end_of_expedition_week(went_out)`), `scripts/hacienda/hacienda_hub.gd` (`_show_dev_menu`, DEV button, F12), `tests/test_hub.gd`
- Spec: owner "a dev menu where we can add infinite money, force instant next week (with all that happens in a week change), add resolución to each separate character"
- Done when: [x] debug builds only (`OS.is_debug_build()`): DEV button in the banner and F12; [x] infinite money (the bank stays at 999999, not saved); [x] next week now: the same week change as coming back from an expedition, with everyone at home; [x] +1 resolución per hero; [x] tests; [x] (2026-11-19 later) set an exact amount of colones ("Poner"; turns infinite money off); [x] "Reiniciar el juego desde cero…" with a confirm card: deletes save.json + .bak, every GameState variable back to its default, starter heroes/alforja/colones, the town reloads; [x] the Resolución hero list scrolls (30 beds)

### P4-21 · M · 1080p pass: scaling, bigger fighters, glow targeting (owner 2026-11-19)
- Status: `review` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-19): owner to play at 1080p · Depends: —
- Files: `project.godot` (`window/stretch/mode="canvas_items"`, `aspect="expand"`), `scripts/combat/battle_unit.gd` (HERO_SIZE / ENEMY_SIZE, glow), `scripts/combat/combat_controller.gd` (`_refresh_markers` clears the acting enemy), `scenes/expedition/expedition_screen.tscn` (stage/bottom panel), `scripts/ui/skill_button.gd`, `scripts/expedition/expedition_screen.gd`
- Spec: owner "this is 1080p, make the enemies and the characters appropriately larger; adapt everything for 1080p; improve the lower UI; instead of the red and green lines for targeting use a highlight around them; keep the portraits for enemies, just resize"
- Done when: [x] the whole game scales from its 1280×720 design to any window (canvas_items stretch, crisp text; wider screens get more room); [x] heroes 160×262 (slight overlap), enemy portraits 146×146 framed squares on the same line (about 1.6–1.85× larger at 1080p); [x] targeting as a glow (hero silhouette / enemy frame): gold active, red enemy target, green ally; [x] lower panel lower and tidier (skill icons 52, map column 390, log 13 pt); [x] screenshots at 1920×1080

### P4-22 · S · Clínica rows, quirk tooltips, more quirks, 30 beds (owner 2026-11-19)
- Status: `review` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-19): owner to read the new quirk names (doc 08) · Depends: P3-06, P4-17
- Files: `scripts/hacienda/hacienda_hub.gd` (`_add_clinic_button`), `scripts/ui/hero_card.gd` (`quirk_chips`, `quirk_tooltip`), `data/quirks.json`, `data/balance.json` (`limits.roster_cap`), `tests/test_quirks.gd`
- Spec: owner "in the Clínica de Espantos the traits should be listed as in the Terminal de Buses; trait badges need a tooltip with flavour text and explanation; add more Tico negative/positive traits; remove the traits from the button tooltip; make the hero limit 30 instead of 8"
- Done when: [x] one card row per hero (portrait, PV/estrés, quirk badges, "Tratar (n)" button; no quirk list in the button tooltip); [x] every quirk badge (Clínica, Terminal, hero cards) has a tooltip: name, kind, flavour, effect; [x] 8 positive, 8 negative and 2 disease quirks added (16/16/5); [x] `limits.roster_cap` 30; [x] tests

### P4-23 · S · Hero sheet from the town roster (owner 2026-11-19)
- Status: `review` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-19): owner to check the layout · Depends: P4-17
- Files: `scripts/hacienda/hacienda_hub.gd` (`_show_hero_sheet`, `_roster_click_hint`), `tests/test_ui.gd`
- Spec: owner "the characters tooltip says 'clic para ver su equipo y sus habilidades' but that window doesn't exist: build it, showing the profile picture and listing all the data/traits/skills/abilities of that character when clicked and no town spot is open"
- Done when: [x] a roster click with no building open opens "Ficha de X" (with a building open it still picks the hero for it); [x] big portrait, class, resolve + XP, Quebranto/Virtud, party position, busy place, ideal positions; [x] every stat; status resistances and element resistances; [x] the 4 equipment slots (item card on hover); [x] the 4 skills with rank pips, description and effects (skill card on hover); [x] quirks with flavour and effect (badge tooltip); [x] camp skills; [x] the roster hint says what a click does; [x] test

### P4-24 · L · Heroes are men and women: names, class names, portraits and sprites per sex (owner 2026-11-19)
- Status: `review` (owner look at the new art in game) · Depends: —
- Files: `data/heroes.json` (`base_sex`, `class_names`, `names_m`, `names_f`), `scripts/autoload/game_state.gd` (`sex`, `_fresh_name`, `class_name_for`, `art_id`, `portrait_path`, `sprite_id`, save v13), `scripts/combat/battle_unit.gd`, every portrait user, `tools/validate_data.py`, `tools/art_manifest.json`, `tools/sd_sprites.py` (per-character `redo_states` / `redo_modes`), `assets/portraits/<id>_<m|f>.png`, `assets/sprites/<id>_<m|f>/`, `tests/test_hub.gd`
- Spec: owner "add Keilor and Tito to Campesino Machetero, Don Vito to Curandero Nicoyano, Greivin to Tecnólogo Errante; at least 40 names per class (15+ male, 15+ female), Tico flavour; heroes male and female, with names and sprites separated per sex; make the other sex's sprites and portraits"
- Done when: [x] 20 male + 20 female names per class, no name twice (validator); [x] recruits 50/50, name not already in use, class name per sex (Campesina Machetera, Abuelo Sabio, Médico Josefino…); [x] old saves get a sex from the name lists (else the class's base sex); [x] portrait + sprites follow the sex, falling back to the class art; [x] 8 new portraits (campesina re-rolled to hold her machete, guachimana retouched, priest re-rolled without glowing eyes); [x] 8 new sprite sets with every pose matching the portrait (flawed poses re-rolled with per-character `redo_*`; redrawn dead poses use `redo_band`); [ ] owner look at the art in game

### P4-25 · S · Random starting party: 2 warriors + 2 supports (owner 2026-11-20)
- Status: `done` · Depends: —
- Files: `data/heroes.json` (`role` per class, `starter_party`), `scripts/autoload/game_state.gd` (`reset_party_from_catalog(random_classes)`, `starter_class_ids_random`), `scripts/autoload/save_service.gd`, `tools/validate_data.py`, `tests/test_hub.gd`
- Spec: owner "the first 4 heroes on reset or on clean start should be randomized, but they should be 2 warrior and 2 support heroes always"
- Done when: [x] every class has `role` warrior | support (validator); [x] a new campaign (no save) and the dev reset draw 2 random warriors (front) + 2 random supports (back), no class twice; [x] `-s` scripts keep the fixed `starter_party.fixed` party so tests and balance baselines don't move; [x] test_hub checks it

### P4-26 · S · Missing other-sex portraits; resistance icons + tooltips in the hero sheet (owner 2026-11-20)
- Status: `done` · Depends: P4-23, P4-24
- Files: `scripts/autoload/game_state.gd` (`load_texture`), `scripts/ui/tooltip_card.gd`, `scripts/hacienda/hacienda_hub.gd` (`_resist_grid`), `scripts/expedition/expedition_screen.gd`, `scripts/expedition/victory_screen.gd`, `scripts/combat/battle_unit.gd`, `data/statuses.json` (`resist_categories[].desc`, Empujones badge), `tests/test_ui.gd`, `tools/screens/hero_sheet_screenshot.gd`
- Spec: owner "after the dev reset these heroes don't have a portrait" (male Exorcista, Abuelo Sabio) and "in the hero details modal add a tooltip and the symbol for the resistances"
- Done when: [x] portraits/sprites load even when the PNG isn't imported yet (`GameState.load_texture` falls back to reading the file); [x] the sheet's Resistencias is a grid of icon + name + % with a tooltip per category (desc from data); [x] test_ui checks both

### P4-27 · S · Missing status icons: Empujones, Amarrado, Embargado (owner 2026-11-20)
- Status: `done` · Depends: P4-26
- Files: `tools/art_manifest.json` (`status_movimiento`, `status_embargado`; `status_amarrado` seed), `assets/status/movimiento.png`, `amarrado.png`, `embargado.png` (+ `.metadata.json`)
- Spec: owner "generate an icon for Empujones" and "check if any of the status effects are missing icons and generate them"
- Done when: [x] every status in `data/statuses.json` and every resist category has an icon (Cuidando reuses Guardia on purpose); [x] validator has no "not generated yet" warning
### P4-28 · M · Town-event modal with a picture per event (owner 2026-11-20)
- Status: `review` · Depends: P3-15
- Files: `scripts/hacienda/hacienda_hub.gd` (`_show_event_card`), `scripts/ui/tooltip_card.gd` (`banner`), `scripts/domain/town_events.gd` (`image_path`), `tools/art_manifest.json` (`event_<id>`, 58), `assets/events/`, `tools/validate_data.py`, `tests/test_ui.gd`, `tools/screens/town_event_screenshot.gd`
- Spec: owner "a modal like Darkest Dungeon's town-event scroll: Title, Image, Flavour text, Effects; generate images for all current town events in our style, coloured"
- Done when: [x] the event card shows title, a 16:9 picture, the flavour text and the effects in their own box (choices — resurrect, paid offer — stay below); [x] every event has `assets/events/<id>.png` + metadata (validator error otherwise); [x] test_ui opens every event's card and checks title + picture; [ ] owner looks at the art

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
- Status: `review` (owner: confirm Debugger shows no warnings)
- Found by owner 2026-11-07 (Godot debugger warnings). Hub, map and combat load PNGs with `Image.new().load("res://…")`. That works in the editor but **images will be missing in an exported build**.
- Files: `scripts/hacienda/hacienda_hub.gd:64`, `scripts/expedition/expedition_map.gd:44,132`, `scripts/combat/combat_scene.gd:66,80`
- Done when:
  - [x] All five use `ResourceLoader.exists(path)` + `load(path) as Texture2D` (keep the procedural fallback when missing)
  - [x] The 4 "parameter is never used" / shadowing GDScript warnings fixed (`combat_resolver.gd` `resolve_level`, `expedition_map.gd` `tr` and `cn`, `combat_scene.gd` `first`)
  - [ ] Debugger shows no warnings after a hub → map → combat run

### P4-06 · S · Readable map node icons
- Status: `todo` · Depends: —
- Icons render at 40×40 next to route buttons (`expedition_map.gd:136`) and are hard to read in the owner's screenshots. Try 64×64, or a type label color per node type.

### P4-07 · M · Side-view battle screen (owner request 2026-11-07)
- Status: `done` — folded into P4-09: the stage, `battle_unit.gd` and the combat rules (now `combat_controller.gd`) live in the expedition screen; `combat_scene` was removed. · Depends: —
- Spec: owner wants the classic side-view layout: party on the left facing enemies on the right in a stage across the top; portrait, stats and skills in a panel below. Own art and UI style; layout only.
- Files: `scenes/combat/combat_scene.tscn`, `scripts/combat/combat_scene.gd`, `scripts/combat/battle_unit.gd` (new)
- Done when:
  - [x] Stage: heroes rank 1 nearest the middle, enemies opposite; HP bar per unit, stress bar per hero, status text (Al Borde, affliction, virtue)
  - [x] Bottom panel: active hero portrait + stats, one button per skill (+ Pasar), combat log, target portrait + stats
  - [x] Animations from poses + tweens: idle breathing, attack lunge, cast glow, hurt flash/shake, ailment pose at rest, death collapse; falls back to portrait art when sprites are missing
  - [ ] Owner checks it in Godot
  - [ ] Click-to-target once there are several enemies (P1-02)

### P4-08 · L · Battle sprites for all characters
- Status: `in-progress (Claude Code, betomm/sleepy-ramanujan-78dwh9, 2026-11-07)` · Depends: —
- 23 characters × 6 states (idle, attack, cast, hurt, ailment, dead) = 138 transparent PNGs in `assets/sprites/<id>/<state>.png`, made by `tools/sd_sprites.py` from the `sprites` section of `tools/art_manifest.json`. Humanoids: one character sheet with all 6 poses (OpenPose per cell), attack redrawn full-size; beasts: img2img from idle. Every call uses the character's portrait (cut out on grey) as an IP-Adapter reference so the sprite looks like the portrait (owner rule). Background cut with rembg. ~12 min per humanoid on CPU.
- Workflow per character: `--only <id> --try-seeds 2 --preview-dir <dir>` → pick a seed (and `redo_seeds.attack` if the attack cell has a third hand / no blade) → set them in the manifest → `--only <id> --force`.
- Progress: all 8 heroes done; attack poses face LEFT with the weapon in the right arm (stage mirrored 2026-11-08). 15 enemies left.
- Done when:
  - [ ] All 138 generated with metadata
  - [ ] Reviewed; bad ones re-rolled (`--only <id> --states <state> --force` after changing seed/look)

### P4-04 · M · Audio mood + narrator lines
- Status: `todo` · Depends: — · Spec: `08`

---

## P5 — Slice validation (roadmap Phase 2 exit)

### P5-01 · M · Local telemetry log
- Status: `done` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-17) · Depends: P3-01
- Files: `scripts/autoload/telemetry.gd` (new autoload), `project.godot`, `scripts/autoload/game_state.gd` (`colones` setter, `week_colones_*`, `log_mission_end`, `_log_week`, spike hook, save v11), `scripts/domain/stress_system.gd` (`spike_hook`), `scripts/expedition/expedition_screen.gd` (`_end_expedition`), `tools/playtest_campaign.gd` (`--telemetry`), `tools/telemetry_report.py` (new), `tests/test_telemetry.gd` (new)
- Done when: [x] `user://telemetry.jsonl` records mission result, stress spikes, colones in/out per week

### P5-02 · L→ split · Balance pass on the P1-09 playtest findings
- Status: split into P5-02a–f (owner 2026-11-14: pulled ahead of P2 and P5-01 to fix the six findings in doc 09 §5). All six are in `review` (2026-11-15). They were done in the order a, b, d, e, c, f: stress and difficulty could only be tuned once food and levelling were right.
- Owner decisions (2026-11-14):
  - Clear rate for the careful bot: about 85–90% on Aprendiz, 70–80% on Veterano, 55–70% on Campeón. The doc 06 target of 55–70% applies to the hardest tier, since the bot plays near-perfectly.
  - Healer stall: dragging-fight stress (Darkest Dungeon's stall penalty).
  - Progression: Darkest Dungeon curve (XP thresholds become per-level costs).
  - Provisions: two recommended kits, short run and full exploration.
  - Recruits are free, as in Darkest Dungeon (2026-11-15).
- Every task reruns `tools/playtest_campaign.gd -- --campaigns 3 --weeks 16` on both routes and compares with the P5-02a baseline in `docs/playtests/`.

### P5-02a · M · Measurement first: a playtest bot that spends like a player
- Status: `review` (Claude Code, `betomm/happy-faraday-5yrmcr`, 2026-11-14; owner to check that the bot's shopping is how a player would spend) · Depends: P1-09
- Why: part of the "loose economy" in doc 09 §5 is the bot. It bought one skill rank a week and no equipment, so prices can't be tuned against it.
- Files: `tools/playtest_campaign.gd`, `docs/playtests/`, doc 09. No game data changes.
- Done when:
  - [x] `--set path=value` (balance.json overrides, as in `tools/sim_combat.gd`) and `--party id,id,id,id` (forced class mix)
  - [x] The bot takes at most 1 dedicated healer unless `--party` is given
  - [x] The bot buys every affordable skill rank, equipment for empty slots, and stress items for heroes at 50+ stress
  - [x] The report shows stress on returning to the hub, colones by sink, and the clear rate per difficulty
  - [x] Baseline of 3 campaigns × 16 weeks on both routes saved in `docs/playtests/`
- Result (doc 09 §6): with a spending bot the bank stays at 5–12k through week 16, so the economy was not the problem. The game is still too easy (93 of 96 cleared), stress is held under 50 by free relief skills, and the longest stalls came from Campesinos healing, not only from healer-heavy parties.

### P5-02b · S · Dragging-fight stress
- Status: `review` (Claude Code, `betomm/happy-faraday-5yrmcr`, 2026-11-14; owner to feel a long fight: does the warning read clearly, and are 8 and 12 rounds the right moments?) · Depends: P5-02a · Spec: `01` §3
- From round `combat.drag_round` (8; `combat.drag_round_boss` 12 against a boss) every living hero gains `combat.drag_stress` (4) at the start of the round, plus `combat.drag_stress_step` (2) per round after. Rule in `scripts/domain/stress_system.gd` (`drag_stress`, `apply_drag`), called from `_start_round()` in `scripts/combat/combat_controller.gd`.
- Also in this task:
  - A second Colapso in the same fight is a death roll, and dragging stress on a hero already at 200 is a Colapso (doc 01 §3.4). Without it two heroes revived each other for ever.
  - The boss threshold (12) is separate because boss fights average 7–10 rounds.
  - `tools/sim_policy.gd`: the smart bot plays to finish once a fight is about to drag. `tools/sim_combat.gd`: `--party` and `--log-long N`. `tools/playtest_campaign.gd`: the bot retreats after losing two heroes on the expedition, not whenever two or fewer are alive.
- Done when:
  - [x] With `--party abuela,abuela,abuela,curandero` no fight passes 20 rounds (longest 12; with three Campesinos and an Abuela, 13)
  - [x] `tools/sim_combat.gd` reports 0 chains past 40 rounds (starting party and both stall-prone parties, 10,000 chains each)
- Result (doc 09 §6, doc 10): longest fight 58 → 23 rounds in the standard playtest; all 96 expeditions cleared, so the game is easier for the bot than before. One boss fight still reached 23 rounds.

### P5-02c · M · Stress pass
- Status: `review` (Claude Code, `betomm/happy-faraday-5yrmcr`, 2026-11-15; owner to play a full-route expedition and judge whether stress now matters without being unfair) · Depends: P5-02b, P5-02e · Spec: `01` §3, `04` §4
- Done after P5-02d and P5-02e, not before: while half the full route's hunger stops were short of food, stress could not be tuned (the first try did nothing on the direct route and wrecked the full one).
- What changed:
  - `data/skills.json` `stress_relief`: *No Me Tumban* 5 → 2, *Círculo de Tiza* and *Humo de Hierbas* 6 → 3, *Regaño Santo* 12 → 8, *Rezo de Nicoya* 3 → 2.
  - `enemy_stress` per difficulty in `data/progression.json`: 1.5 / 2.0 / 2.25. It scales the stress of enemy skills (`stress_mult` on the enemy; `combat_controller.gd`), not the extra stress of an enemy crit. Shown in the hub's difficulty tooltip; checked by the validator.
  - Enemy basic-attack stress in `data/enemies.json` was not needed.
- Done when (full route):
  - [ ] Top hero's stress at the end 60–80 (measured 83; 55 on the direct route)
  - [x] A resolve check in about 1 of 3 expeditions (26 of 72; 9 of 72 on the direct route)
  - [x] Party average back at the hub 30–50 (38; 28 on the direct route)

### P5-02d · S · Darkest Dungeon XP curve
- Status: `review` (Claude Code, `betomm/happy-faraday-5yrmcr`, 2026-11-15; owner to judge whether Campeón in week 15–17 is the pace wanted) · Depends: P5-02a · Spec: `01` §6.1
- `xp_thresholds` `[0, 2, 10, 24, 48, 84, 132]`, Pura Vida about 20% lower (`[0, 2, 8, 19, 38, 67, 106]`); XP per expedition stays 4 / 8 / 16. `SAVE_VERSION` 10: on load a hero's XP is raised to the threshold of their level, so nobody loses a level.
- Done when:
  - [x] Veterano around week 7 and Campeón around week 15 in the playtest (weeks 7–9 and 15–17; the spread is the bot resting heroes)
  - [x] `tests/test_progression.gd` covers the curve and the migration (`tests/test_town_events.gd` the Pura Vida curve)
  - [x] Doc 01 §6.1 and doc 13 updated

### P5-02e · M · Two provision kits
- Status: `review` (Claude Code, `betomm/happy-faraday-5yrmcr`, 2026-11-15; owner to try the prompt before leaving the hub) · Depends: P5-02a · Spec: `01` §4.6, `04` §3.1
- Region `provisions` is `{ "short": {...}, "full": {...} }`. Sótanos: 10 gallo pinto + 3 candelas (1,050 ₡) and 16 + 5 (1,700 ₡); Bosque 9 + 3 and 14 + 4 (an estimate; Bosque is not in the slice). `GameState.missing_provisions(region, kit)` / `buy_missing_provisions(region, kit)`; the hub prompt lists both kits with a button for each and asks nothing when the full kit is covered; the validator requires both; the bot buys by `--route`.
- Also in this task (tools only): the bot steps back into position when it can't attack, and plans its party per difficulty (`_plan_party` in `tools/playtest_campaign.gd`).
- Done when:
  - [x] Full-route hunger stops short of food fall from about half to under 10% (2%: 3 of 152)
  - [x] Both kits covered by a test (`tests/test_expedition_systems.gd`, where the provision checks already were)
- Result (doc 09 §6): with food sorted and the bot fixes, 144 of 144 expeditions are cleared and stress comes back at 12–16.

### P5-02f · M · Economy and clear-rate tuning
- Status: `review` (Claude Code, `betomm/happy-faraday-5yrmcr`, 2026-11-15; owner decisions listed in the handoff of that date) · Depends: P5-02c, P5-02d, P5-02e
- What changed:
  - **Recruits are free** (owner 2026-11-15, as in Darkest Dungeon): `hire_cost` removed from `data/heroes.json`; `GameState.hire_cost` is 0 except for a hero a town event prices (`hire_veteran`). With paid recruits every full-route campaign went bankrupt after its first wipes.
  - Enemies per difficulty in `data/progression.json`, PV / damage: Aprendiz ×1.1 / ×1.2, Veterano ×1.75 / ×1.6, Campeón ×2.4 / ×2 (were ×1 / ×1, ×1.22 / ×1.12, ×1.46 / ×1.24).
  - *Sopa Milagrosa* heals 1–3 (was 2–4).
  - Rewards, the Iglesia and the EBAIS were not changed: the bank no longer piles up.
  - Tools: `tools/sim_combat.gd --level N --ranks R --gear` and `tools/playtest_campaign.gd --start-level N --start-ranks R --start-gear K --start-colones C` measure one difficulty on its own; the bot keeps a core team and two free spares.
- Done when:
  - [ ] Clear rates in the owner's bands: Aprendiz 91% (band 85–90), Veterano 86% (band 70–80; 64% full route, 96% direct), Campeón 4 of 5 (band 55–70; too few). See the note below.
  - [x] The Iglesia and stress items take at least 10% of weekly spending on the full route (12%; 7% on the direct route)
  - [ ] Colones after week 8 between 8k and 15k (measured 4.2–8.0k: the economy is now tight, and all 12 campaigns are solvent in week 24; loot was not raised)
  - [x] Before/after tables in doc 09 §6 and doc 10
- Why the later tiers are not pushed to the bottom of their bands: the bot retreats only after two heroes are down, so its failures are wipes. Veterano on the full route already loses 1.5 heroes per expedition at a 64% clear rate, against doc 04 §4's one death every 5–8 missions. Lowering the clear rate further this way would cost several heroes per expedition. Reaching the bands needs a decision first (see the handoff): a bot and a player who retreat earlier, or a retreat that keeps part of the loot.
- Known limits: Campeón has almost no data (no full-route campaign reached it in 24 weeks); the first six weeks of a campaign are still never lost (36 of 36).
- Parallel pass (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-17, made without knowing about P5-02a–f): bot campaigns that never bought gear, tuned to 71% success (doc 09 §7). **Superseded by the 2026-11-17 merge**: its difficulty and stress numbers were dropped for P5-02a–f's. Two parts were kept:
  - `hub.idle_stress_relief` (15 stress off a hero home all week without a booking; replaces the misas the bot relied on, since the group misa is gone, owner 2026-11-16);
  - the campaign bot's Iglesia/Cantina bookings.
  The re-measurement after the merge is in the handoff.

### P5-07 · M · Rebalance after the 2026-11-17 merge
- Status: `done` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-19): Aprendiz `enemy_hp` 1.0, `enemy_dmg` 1.0, `enemy_stress` 1.15; EBAIS 12 ₡/PV; rest at home 20 · Depends: —
- Spec: doc 04 §4–§5, doc 09 §6–§7; the merge handoff (2026-11-17 (11))
- Why: P5-02a–f tuned the difficulty table and the support skills' stress relief on a game with a cheap weekly group misa. The misa is gone (owner 2026-11-16); stress relief is now the Iglesia/Cantina (a week off per hero), resting at home (15) and the Clínica. The merged game measured 19%, then 29% success after the bot rotated frayed heroes; mostly retreats. Money is about 2.0k in and 2.4k out a week.
- Done when: [x] bot runs (6 seeds, 144 expeditions; 2 seeds proved too noisy) back in the doc 04 bands: 58% cleared, 0.19 deaths/expedition, ₡ in 2946 / out 3118 a week (docs/playtests/2026-11-19-p5-07.md) (55–70% success, deaths 1 per 5–8 missions, weekly money in ≈ out); likely levers: Aprendiz `enemy_stress` (1.5), the support skills' `stress_relief`, Iglesia/Cantina prices or relief, `hub.idle_stress_relief`

### P5-08 · S · Retune Veterano and Campeón for the game without the group misa
- Status: `done` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-19): scope widened to all three tiers — P5-07 aimed Aprendiz at 55–70%, but the owner's bands are per tier (Aprendiz 85–90, Veterano 70–80, Campeón 55–70; line "Clear rate for the careful bot" above) · Depends: P5-07
- Why: P5-07 retuned Aprendiz only; 8-week bot campaigns played 139 of 144 expeditions there. The Veterano/Campeón rows of `data/progression.json` are still the P5-02c/f values from the misa era.
- Done when: [x] each tier in the owner's band for the careful bot: Aprendiz 91% (6 seeds, fresh campaigns), Veterano 80%, Campeón 63% (4 seeds each, tier-start runs); docs/playtests/2026-11-19-p5-08.md. Not done: a 24-week run (parties that reach Veterano in an 8-week campaign cleared 7 of 22) — see P5-09

### P5-09 · S · 24-week campaigns on the P5-08 numbers
- Status: `done` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-19): Veterano ×1.15/×1.1/×1.3, Campeón ×1.6/×1.4/×1.65 · Depends: P5-08
- Why: P5-08 measured Veterano and Campeón with parties started at the tier. Parties that reach Veterano inside an 8-week campaign have fewer ranks and less gear and cleared only 7 of 22 there.
- Done when: [x] 24-week runs on 6 seeds (18 campaigns): Veterano 70%, Campeón 63% (7 of 18 campaigns reached it), 0.14 deaths/expedition, money in ≈ out (docs/playtests/2026-11-19-p5-09.md). Moving up is forced by the level ranges, so "wait longer" was not an option; Veterano/Campeón are now sized for the party that arrives

### P5-10 · M · Enemy drops + battle victory card (owner 2026-11-19)
- Status: `review` (Claude Code, `claude/p3-03-followup-48gkar`, 2026-11-19): owner to play · Depends: —
- Files: `data/enemies.json` (`drops`), `data/balance.json` (`drops.*`), `scripts/domain/loot_drops.gd` (new), `scripts/autoload/game_state.gd` (`roll_drops`), `scripts/expedition/expedition_screen.gd` (`_show_battle_result`, `_card_dialog`), `tools/validate_data.py`, `tests/test_enemies.gd`, `tests/test_ui.gd`, `AGENTS.md`
- Spec: owner "add a victory screen; make some enemies drop loot some times, balanced for each enemy and the run; the more powerful the enemy the better the loot; each enemy can drop 3 different items with different percentages; only 1 at a time and most of the times they won't drop; in the victory screen show the things gained/lost after the battle"
- Done when: [x] 3 themed drops per enemy, one roll, at most one item; [x] chance by strength (vermin ~15% … bosses ~70%) × difficulty × Luz/event loot, capped; [x] a card after every won fight: colones, drops (and what didn't fit), each hero's PV and stress change, fallen, new Quebranto/Virtud; boss drops go to the expedition's victory screen; [x] validator + tests; [ ] owner feel check (bot: Aprendiz 96% on 4 seeds, slightly above the 85–90 band: drop chances are the knob)

### P5-03 · S · 3-loop new-player playtest + slice sign-off
- Status: `todo` · Depends: all P2–P5
- Done when: [ ] Roadmap Phase 2 exit criteria checked by owner → Current phase = Alpha (break down roadmap Phase 3 into P6+ tasks then)

### P5-04 · M · Retreat from a fight ("Retirada")
- Status: `review` (Claude Code, `betomm/happy-faraday-5yrmcr`, 2026-11-15; owner to try a retreat in a fight that is going badly) · Depends: P5-02f · Spec: `01` §5.3
- Why (owner 2026-11-15): failing should be cheaper than dying. Retreating on the map already kept every colón and item found, but there was no way out of a fight, where nearly all deaths happen.
- Rule: on a hero's turn, "Retirada" works with `combat.retreat_chance` (0.75; a failed try spends the turn), costs every living hero `combat.retreat_stress` (10) and takes the party back to the room it came from; the room keeps its enemies. Not from a night ambush. `CombatResolver.roll_retreat`, `combat_controller.gd` `retreat()` / `combat_fled`, `GameState.previous_node_id` / `retreat_to_previous_room()`, `expedition_screen.gd` `_on_combat_fled`.
- Also: the "Abandonar expedición" tooltip and ending line now say what the party keeps; the action row shrinks its icons when it holds nine; a retreat icon; `tools/screens/battle_screenshot.gd` saves `battle_actions.png`.
- Done when:
  - [x] `tests/test_retreat.gd` (13 checks: failed try, good retreat, room not cleared, enemies back at full PV, no retreat from an ambush)
  - [x] The button and the action row checked in a screenshot
  - [x] Doc 01 §5.3, doc 13, AGENTS.md §3 and §4

### P5-05 · S · A bot that retreats (tools only)
- Status: `review` (Claude Code, `betomm/happy-faraday-5yrmcr`, 2026-11-15; owner to say whether these are the moments a player would retreat) · Depends: P5-04
- `tools/sim_policy.gd`: the smart bot calls a retreat when a hero has died in this fight, two heroes are Al Borde, or the fight drags with someone at 150+ stress (`--no-retreat` in `tools/sim_combat.gd` turns it off; the sim counts retreats). `tools/playtest_campaign.gd`: the bot goes home after a Retirada and after one death on the map (was two), pays for up to three misas a week, and reports abandoned expeditions with the loot kept.
- Done when: [x] 3 × 24 weeks on both routes with no data change saved as `docs/playtests/2026-11-15-retreat-{full,direct}.md`
- Result (doc 09 §6): heroes lost per expedition fell from 0.76 to 0.18 (full) and 0.25 to 0.06 (direct). The direct route is near the bands (94% / 96% / 55%). The full route is a stress spiral: 28 of 72 cleared, parties leaving the hub at 84 stress.

### P5-06 · M · Retune Veterano and Campeón
- Status: `blocked — needs P3-03 (stress relief at the hacienda) and bigger playtest samples` · Depends: P5-05, P3-03
- Why blocked (2026-11-15): with retreating bots the full route is a stress spiral (the Iglesia removes 10 per misa), so harder enemies would only deepen it. And three campaigns per route swing by 15–30 points between identical or near-identical settings (doc 09 §6), which is more than the change this task is after. Run about ten campaigns per setting (`--campaigns 10`, about 1.5 hours per pair of routes) once P3-03 is in. A try at `hub.iglesia_relief` 20 and 30 was inconclusive and was not kept.
- Lever: `enemy_hp` / `enemy_dmg` / `enemy_stress` for Veterano and Campeón in `data/progression.json`; Aprendiz only if the P5-05 reference moves it out of 85–90%. Tier-start runs first (`--start-level 3 --start-ranks 3 --start-gear 2 --start-colones 6000` and `--start-level 5 --start-ranks 4 --start-gear 4 --start-colones 9000`, 4 × 8 weeks per route), then one 3 × 24-week pair.
- Owner 2026-11-15: keep the economy tight (no reward changes), the event veteran stays at 6,000 ₡, bosses keep dragging from round 12.
- Done when: [ ] Veterano 70–80% and Campeón 55–70% cleared, both routes together [ ] heroes lost per expedition at or under about 0.3 [ ] all campaigns solvent in week 24, bank 4–8k [ ] doc 01 §6.1, doc 09 §6, doc 10 updated

---

## Later (not broken down yet)

Roadmap Phase 3 (Alpha: 4–5 regions, 16 classes, 120+ events, difficulty tiers), Phase 4 (Beta/polish), Phase 5 (Launch). Break these into tasks only once P5-03 is done. Don't plan that far ahead in detail.
