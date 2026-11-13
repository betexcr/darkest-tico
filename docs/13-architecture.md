# 13 — Technical Architecture

How the game is put together in code: the layers, the save system, how an encounter runs from the hub to a fight and back, the status effect engine and the data files. Read [../AGENTS.md](../AGENTS.md) first for the working rules. The design itself is in docs 01–09.

Written 2026-11-12 (P1-08), against save version 9.

## 1. Layers

| Layer | Where | Rules |
|---|---|---|
| Data | `data/*.json`, `data/regions/*.json` | All content and balance numbers. Checked by `tools/validate_data.py`. |
| Domain rules | `scripts/domain/*.gd` | Pure static functions on plain dictionaries. No nodes, no autoloads, no numeric literals (balance comes from `Balance.num("section.key")`). |
| State | `scripts/autoload/game_state.gd` (`GameState`) | Owns the campaign (roster, colones, week, inventory) and the current expedition. Calls domain rules, holds the results. |
| Save | `scripts/autoload/save_service.gd` (`SaveService`) | Reads and writes `user://save.json` (§2). |
| Screens | `scripts/bootstrap/`, `scripts/hacienda/`, `scripts/expedition/`, `scripts/combat/`, `scripts/ui/` | UI and flow. `CombatController` runs a fight; the screens own the nodes. |
| Tests and tools | `tests/*.gd`, `tools/*.gd`, `tools/*.py` | Headless Godot `-s` scripts and Python checks. |

Autoloads, in order: `GameState`, `SaveService`, `TooltipStyler` (draws every `tooltip_text` as the shared card).

Units are plain dictionaries everywhere. A hero is one dictionary that lives in `GameState.roster`. The same dictionary sits in `GameState.party` and is what combat changes, so PV, stress and statuses carry over between fights without copying. An enemy is a deep copy of its `data/enemies.json` entry, scaled for the fight.

## 2. Save system

**File:** `user://save.json`. On the owner's Windows machine that is `%APPDATA%\Godot\app_userdata\Darkest Tico\save.json`.

**When it is read and written:**
- `SaveService._ready` loads the save once at startup and writes it straight back. If there is no save, or it can't be read, the game starts new with `GameState.reset_party_from_catalog()`.
- `main.gd` `_back_to_hub` saves after every expedition, once the week has ended and the town event is drawn.
- `hacienda_hub.gd` saves after hub actions.

**Safety (P1-19):**
- **Scripts:** while a `-s` script runs (tests, `tools/sim_combat.gd`, `tools/screens/*`), `SaveService.enabled` is false. These scripts start from a fresh catalog party and never read or write the real save. Several can run at once.
- **Writes:** `save_to()` writes `save.json.tmp` and reads it back. The previous good save becomes `save.json.bak`, then the temp file is renamed into place. A crash mid-write leaves the old save.
- **Bad loads:** `load_from()` copies an unreadable save to `save.broken-<unix time>.json` and loads the `.bak` instead. A broken file never becomes the backup.

**Schema** (`GameState.to_save_dict()`):

| Key | Contents |
|---|---|
| `version` | `GameState.SAVE_VERSION` (9) |
| `colones`, `week` | Campaign money and week |
| `roster` | Every hired hero dictionary (stats, PV, stress, equipment, skill ranks, Quebranto/Virtud, Resolve XP, `uid`) |
| `party_uids` | The expedition party in formation order (position 1 first) |
| `recruit_pool`, `next_uid` | Candidates at the terminal; next hero uid |
| `selected_mission_region_path`, `selected_difficulty_id` | The last expedition choice in the hub |
| `radiant_mode` | Modo Pura Vida |
| `active_event_id`, `event_seen`, `event_deck`, `events_done_once`, `event_flags` | Town events (doc 02 §12) |
| `graveyard`, `stolen_items` | The fallen (for resurrection) and items a town event took |
| `inventory` | `[{id, qty}]`, the shared alforja |

**Not saved:** the expedition in progress. Loading always calls `end_mission_abandon()`, so quitting mid-expedition abandons it. Mission state (map, Luz, hunger count, firewood, ledger) lives only in `GameState` while the expedition runs.

**Versioning:** `apply_save_data()` reads any older version and fills in what is missing. History:

| Version | Change |
|---|---|
| ≤ v3 | `colones`, `week`, `party` |
| v4 | `inventory`; older saves keep the starter pack |
| v5 | `roster` + `party_uids` + `recruit_pool`; older `party` lists become the roster |
| v6 | Expedition difficulty |
| v7 | Modo Pura Vida and town events |
| v8 | Casa Comunal skill ranks; older saves start every skill at rank 1 |
| v9 | A hero's `skill_ids` always follow the class; a rank in a replaced skill moves to the new skill in the same slot |

`_sanitize_runtime_hero()` fills hero fields added after a save was written, so new hero keys don't need a version bump on their own. Change the version when a key is renamed or its meaning changes:
1. Bump `SAVE_VERSION`.
2. Add a migration step in `apply_save_data()`.
3. Add a case to `tests/test_hub.gd` or `tests/test_progression.gd` (both load old-shape saves).

JSON numbers load as floats: compare uids and counts with `int()`.

## 3. Encounter flow (hub → map → combat → map)

```
HaciendaHub ──start_mission_requested──▶ main.gd ──GameState.start_mission()──▶ ExpeditionScreen
     ▲                                                                              │
     │                       room loop: move ▶ hunger? ▶ room event ▶ combat ◀─────┘
     │                                                                              │
     └── main._back_to_hub ◀── (VictoryScreen if objective) ◀── expedition_finished(reason)
```

### 3.1 Start (`GameState.start_mission`)
1. Refuses if nobody is alive or a hero refuses the difficulty (`party_refusals`).
2. Loads the region JSON (`ExpeditionLoader.load_region`). There are two kinds of region:
   - **Hand-made** (Bosque) lists `nodes` and `edges`.
   - **Generated** (Sótanos) has a `generator` block. `MapGenerator.generate(region, seed)` builds a grid dungeon from it (§3.2).
3. Curio and trap rooms take their names from `curios.json` / `traps.json`.
4. Sets up the mission state:
   - Luz = `initial_light`, capped by `light_max()`; hunger count 0.
   - Difficulty (`ResolveSystem.expedition`), with the town event's mission mods applied.
   - Firewood, the ledger and the party prep (`_prepare_party_for_mission`: clears camp buffs, snapshots each hero's mental state, applies the under-level penalty).

### 3.2 Map generator (`scripts/domain/map_generator.gd`)
- **Layout:**
  - Grows `rooms` cells on an integer grid from the entrance; corridors join orthogonal neighbours, with `max_exits` per room and `extra_links` loops.
  - The dead end farthest from the entrance is the boss room. If it is closer than `min_boss_distance`, the generator tries the next seed (up to 30 tries).
- **Room types:**
  - The entrance is `safe`.
  - `camps` camp rooms go about halfway to the boss; `elites` elite fights go in the far half.
  - Every other room is picked by `weights` (combat, trap, curio, empty). If there are fewer than `min_combat` fights, empty, curio and trap rooms become fights.
  - Curio and trap rooms get a `curio_id` / `trap_id` from the generator's `curios` / `traps` lists.
- **Fights:**
  - A fight gets a squad from `enemy_pool` and `squad_size`. Elites (`elites`, `elite_pool`) and the boss (`boss_enemy_id` + `boss_escort`) have their own rewards.
- **Output:** the same shape as a hand-made region: `nodes` (with `pos: [x, y]`), `edges`, `start_node`, `objective_node`, `undirected: true`, `seed`.

### 3.3 Room loop (`scripts/expedition/expedition_screen.gd`)
1. **Move:** `_on_room_clicked` / `_try_move` call `GameState.move_to_node`, which:
   - spends Luz (`light_decay`);
   - adds walking-in-the-dark stress (Luz tier);
   - counts one move toward hunger.
2. **Hunger:** `_enter_room` opens the travel meal first when `hunger_due()` (doc 01 §4.6), then `_resolve_room`.
3. **Room:** `_resolve_room` reads the node `type`:
   - `combat` / `boss`: `_start_combat`.
   - `trap`: `_open_trap` (disarm or pass with care, `TrapRules`).
   - `curio`: `_open_curio`.
   - `camp`: `_open_camp` (meal, respite skills, watch, sleep; may end in a night ambush).
   - `safe` and the rest: narrated and cleared.
4. **Outcomes:** traps and curios resolve through `GameState.apply_event_outcome()`, the one outcome vocabulary the validator checks. An outcome can be an ambush, which starts a fight from `build_ambush_context`.
5. **After any event,** `_check_wipe()` ends the expedition if trap or curio damage killed the last hero.

### 3.4 Building a fight (`GameState.build_combat_context_for_node`)
Writes `GameState.combat_context` (`enemies`, `enemy`, `is_elite`, `is_boss`, `is_ambush`, `surprise`).

For each enemy in the room's `enemy_ids`:
1. Deep copy the data entry.
2. Scale PV:
   - leader multiplier (elite or boss);
   - squad scale for the escorts (`balance.json` `enemies.squad_hp_scale`);
   - difficulty `enemy_hp`.
3. Add the difficulty's accuracy, damage and `enemy_resist`.
4. Letter duplicate names: "Cadejo A", "Cadejo B".
5. Order the squad by preferred position (`Formation.sort_squad`).
6. Roll Luz surprise (`LightSystem.roll_surprise`), except for the boss.

Night and curio ambushes use `build_ambush_context(node_id, count)` instead.

### 3.5 Combat (`scripts/combat/combat_controller.gd`)
`ExpeditionScreen._start_combat_from_context` spawns the units and calls:

```
CombatController.start(party, enemies, hero_units, enemy_units, elite, boss, ambush, surprised_enemies, note)
```

- **Rounds:**
  - `_start_round` applies the round-start Virtud effects, then `_roll_initiative_queue` (speed + roll, ties by speed, then Resolve, then a random roll).
  - In round 1, an ambush puts every enemy first; surprised enemies put every hero first.
- **Turns (`_process_turn`):** the fallen move to the back (`_collapse_ranks`). On a hero's turn:
  1. Guard drops.
  2. `StatusEffects.tick` runs, and its damage, heal and stress are applied.
  3. A stun, or a cowardice affliction, skips the turn.
  4. Otherwise `hero_turn_started(hero)` is emitted and the controller waits.
- **Hero input:** the screen shows the skill bar and calls one of `use_skill`, `use_item`, `guard`, `move_hero` or `pass_turn`. Each resolves, then `_after_action` animates, applies queued pushes and pulls, and goes on to the next turn.
- **Enemy turns:** tick, pick a skill by weight (`_pick_enemy_skill`) among those in reach, or step toward the preferred positions (`_enemy_reposition`).
- **Damage to heroes:** Santiguado, protection and Guard first, then `HeroDamage.take()`: Al Borde, then Golpe de gracia. Traps and curios use the same rule.
- **Live Luz:** enemy damage and crit and the stress heroes take read `GameState.mission_light` at that moment, so a skill that drains the candle matters in the same fight.
- **End:**
  1. `_check_end` → `_finish(victory)` clears statuses and Guard and ticks camp buffs.
  2. It emits `combat_over(victory)`.
  3. The screen pays the reward (`combat_reward × loot_mult`, which includes the Luz tier) unless it was an ambush.
  4. A boss or objective win calls `complete_mission()` and ends the expedition with `"objective"`.
  5. A loss ends it with `"defeat"`.
- **Signals to the screen:** `hero_turn_started`, `actor_changed`, `logged`, `enemy_changed`, `combat_over`.
- **Instant mode:** `instant = true` (plus stub units) makes the controller resolve without timers. `tools/sim_combat.gd` uses it to play thousands of fights headless.

### 3.6 Back to the hub
`expedition_finished(reason)` reaches `main.gd`:
1. On `"objective"`, the victory screen comes first (loot and Resolve XP from `last_expedition_summary`).
2. `_back_to_hub` ends the week (`end_of_expedition_week`) and draws a town event.
3. It saves, then opens the hub.

## 4. Status effect engine

**Rules:** `scripts/domain/status_effects.gd`. **Definitions:** `data/statuses.json`: name, letter, colour, `kind` (positive/negative), `stacks`, `resist` category, `irresistible`. The same file holds `state_mods` (Al Borde, Convaleciente), `mental_mods` (Quebranto/Virtud stat effects), `resist_categories` and caps.

**Storage on any unit dictionary:**
```
unit["statuses"][id] = {"stacks": [{"turns": int, "value": int, "mods": {stat: delta}}], "by_uid": int}
```
- Stacking statuses (sangrado, veneno, susto, salado, chiva, sobado, espabilado) keep one stack per application, each with its own timer.
- The others hold one stack that a new application refreshes.

**API:**
- `apply(unit, id, turns, value, opts)` returns a log line, or "" if nothing happened.
  - It checks death, immunity and the resist roll (`resist_chance`; Amarrado uses the Empujones category through `resist`).
  - `opts`: `mods`, `by_uid` (who guards), `crit` (DoTs last longer), `ignore_resist`.
- `tick(unit)` runs at the start of the unit's own turn. It returns `{damage, heal, stress, skip, logs}`; the controller applies these so Al Borde, death and stress rules run in one place.
  - Sobado heals before Sangrado and Veneno damage.
  - Susto adds stress.
  - Atarantado skips the turn, then grants Espabilado.
- `stat(unit, key)` is the sum of every stat delta (accuracy, dodge, speed, crit, prot, dmg_pct, stress_pct) from statuses, Al Borde/Convaleciente and Quebranto/Virtud. Combat reads stats only through it.
- `use_aegis` (Santiguado blocks), `targetable` / `pick_target` (Agazapado, Fichado), `guardian_of` (Al cuido / Cuidando), `remove_all_negative`, `clear`.

**Where effects come from:**
- Skills and items: `applies` / `self_applies` (`{status, chance, turns, value, mods}`), `cure`.
- Enemy skills: `applies`.
- Trap and curio outcomes: `applies`.
- Camp buffs and debuffs are a separate list (`hero["camp_buffs"]`, `CampingSystem.add_buff`) that lasts a number of fights and counts down in `_finish`.

**Lifetime:** every status is cleared when a fight ends. Convaleciente is a hero flag for the whole expedition.

## 5. Data files

Every file has a `_doc` string that explains its fields; the validator is the strict reference.

| File | What | Loaded by |
|---|---|---|
| `balance.json` | Hit band, crits, death roll, stress, afflictions, enemy squad scaling, hub prices, limits, hunger, Luz tiers | `Balance` (`num`, `int_of`, `arr`, `req`) |
| `heroes.json` | 8 classes: stats, preferred `ranks`, `skill_ids` (first = the class's basic attack), `camp_skill_ids`, `status_resist`, `names`, `hire_cost` | `GameState` |
| `skills.json` | Hero skills: `kind`, `target`, `use_ranks`/`target_ranks`, damage/heal ranges, `applies`, `cure`, movement, stress, `rank_bonus` | `GameState` |
| `enemies.json` | Enemies by id: stats, `ranks`, `elements` (affinities), `status_resist`, `crit`, `skills` (one `basic`, 1–3 specials with `type`, `element`, `applies`, `target_ranks`, `weight`, `light`, `steal_colones`) | `GameState` |
| `statuses.json` | Status definitions and stat tables (§4) | `StatusEffects` |
| `items.json` | 83 items: consumables (`effects`, `target`, `usable`, `uses_per_node`), equipment (`slot`, `bonus`, `element`, `resist`, `immune`, `status_resist`, `on_hit`, `start_status`), `curio_keys`, `price`; `starter_inventory`; the element list | `GameState` |
| `camp_skills.json` | Respite points, firewood, ambush chances, meals, 19 camp skills | `CampingSystem` |
| `curios.json` | Curios: `text`, `blind` outcome, `key_item` + `key_outcome` | `GameState` |
| `traps.json` | Disarm settings and traps (`difficulty`, `effects` in the outcome vocabulary) | `TrapRules` |
| `progression.json` | Resolve levels and XP, Casa Comunal skill rank costs, region scaling, the 3 difficulties | `ResolveSystem` |
| `town_events.json` | 56 weekly town events (`effects`, `requires`, week range, `once`) | `TownEvents` |
| `regions/*.json` | Region: Luz start and decay, `provisions`, rewards, `region_level`, then either `nodes` + `edges` or a `generator` block (§3.2) | `ExpeditionLoader`, `MapGenerator` |

**Conventions:**
- Ids are `snake_case` Spanish; display text is Costa Rican Spanish (doc 08).
- **Outcome vocabulary:** trap and curio results share one key set: `damage_random`, `damage_party`, `heal_party`, `stress_party`, `applies`, `buff`/`debuff`, `colones`, `random_equipment`, `add_item`, `reveal`, `ambush`. `GameState.apply_event_outcome` handles them; the validator rejects unknown keys.
- **New balance number:** put it in `balance.json`, add the key to `BALANCE_KEYS` in the validator, and read it with `Balance.num`. The validator rejects numeric literals in `scripts/domain/`; mark real structural numbers `# structural`.

## 6. Tests and tools

| Command | What |
|---|---|
| `python3 tools/validate_data.py` | Parses every data file and checks cross-references, the content rules in AGENTS.md §4, balance keys and the magic-number rule. |
| `godot --headless --path . -s tests/<name>.gd` | One test script. Most print `N failure(s)` and exit 1 on failure (`test_guard.gd` prints one `ok` line per check). `smoke_expedition.gd` plays 3 full expeditions through the real screen. The list is in AGENTS.md §3. |
| `godot --headless --path . -s tools/sim_combat.gd -- --runs N [--chain 3] [--light N] [--set path=value]` | Monte Carlo of real fights in instant mode (doc 10). |
| `godot --path . -s tools/screens/<name>.gd -- <out_dir>` | Screenshots for owner reviews (needs a window or `xvfb-run`; see each script's header). |

None of these touch the owner's save (§2).
