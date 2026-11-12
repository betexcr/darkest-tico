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
- Status: `todo` · Depends: P2-01
- Spec: `07`, `05` §1.1, `08` (tone)
- Files: `data/events.json`
- Done when:
  - [ ] ≥30 events tagged for `sotanos`, Spanish text, tone-reviewed against `08`

### P2-03 · M · Classes 5–8
- Status: `review` (done 2026-11-07 without ranks: Guachimán, Médica Josefina, Curandero Nicoyano, Exorcista in `heroes.json`, 4 skills each incl. ally/party support, guard-granting, cures and stun; hireable at the terminal. Rank constraints added in P1-03a) · Depends: P1-03, P1-04
- Spec: `03`. **Owner confirmed 2026-11-06:** classes 3 Guachimán Jubilado, 5 Médica Josefina, 6 Curandero Nicoyano, 9 Exorcista de Barrio.
- Files: `data/heroes.json`, `data/skills.json`, `assets/portraits/`
- Done when:
  - [x] 8 heroes, each with 4 skills
  - [ ] Rank constraints (P1-03)
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
- Status: `todo` · Depends: P3-01
- Spec: `02` §7
- Done when: [ ] Both buildings with activities, slots, and side effects; heroes are busy for the week

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
- Status: `todo` · Depends: P3-01
- Spec: `02` §6, `01` §3
- Done when: [ ] Positive/negative quirks gained on missions; treatment in Clínica

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
- Status: `todo` · Depends: P3-07
- Spec: `02` §9
- Done when: [ ] Hub building to swap a hero's 4 camp skills among the class + shared list, and the upgrade tracks from doc 02 §9

### P3-16 · M · Casa Comunal building upgrades
- Status: `todo` · Depends: P3-04, a building-upgrade system (materials, doc 02 §11)
- Spec: `02` §4 (upgrade tracks), `04` §3.3 (discount up to 50% at cap)
- Done when: [ ] Maestría de Oficio raises the max skill rank (start lower than 5); [ ] Plan de Formación lowers rank prices up to 50%

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

### P1-18 · M · Travel hunger + provisions
- Status: `review` (Claude Code, `main`, 2026-11-12; owner to try the hunger stop and the provisions prompt) · Depends: P1-16
- Owner 2026-11-12: every 6 moves the party eats 1 gallo pinto per living hero; a hero who can't eat takes −10% PV (never below 1) and +10 stress; a camp meal resets the count.
- Files: `data/balance.json` (`hunger.*`), `scripts/domain/camping_system.gd`, `game_state.gd`, `expedition_screen.gd`, `scripts/hacienda/hacienda_hub.gd`, region JSONs (`provisions`)
- Done when:
  - [x] Hunger event every 6 moves (eat / share / go hungry); camp meal resets it
  - [x] Hub warns about missing recommended provisions and can buy them

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
