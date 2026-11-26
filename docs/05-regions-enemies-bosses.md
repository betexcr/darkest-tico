# Regions, Enemies, and Boss Progression

This content spec defines launch biomes, enemy factions, and boss escalation toward the portal to hell.

## 1) Launch Regions

## 1.1 Sotanos de la Hacienda (Starter Corruption Zone)

- Theme: collapsed cellar tunnels beneath inherited hacienda.
- Combat profile: short corridors, ambush chains, infernal scouts.
- Hazards:
  - Darkness bursts
  - Structural collapse traps
  - Whispering curio nodes
- Resource identity:
  - High colones
  - Moderate relics
  - Low infernal fragments

## 1.2 Bosque Nuboso Maldito

- Theme: foggy cloud forest with spiritual distortion.
- Combat profile: stealth enemies, stress pressure, dodge-heavy threats.
- Hazards:
  - Confusing routes
  - Poison flora
  - Ambush chance spike at low light
- Resource identity:
  - Trait and ritual components
  - High scouting value rewards

## 1.3 Canaverales Profanados

- Theme: sugarcane fields converted into cult ritual grids.
- Combat profile: swarm enemies, bleed pressure, midline disruption.
- Hazards:
  - Fire spread events
  - Forced movement terrain
  - Cult totems buffing enemies
- Resource identity:
  - Good soft currency yields
  - Upgrade materials for smith and guild equivalents

## 1.4 Ruinas Volcanicas

- Theme: lava-scarred ruins and obsidian ritual sites.
- Combat profile: armored enemies, burn effects, high burst damage.
- Hazards:
  - Heat stress pulses
  - Eruption telegraphs
  - Falling rock stun traps
- Resource identity:
  - High infernal fragment yield
  - Late-tier crafting resources

## 1.5 Pueblo Fantasma de Cartago Viejo

- Theme: abandoned colonial town warped by collective fear.
- Combat profile: fear mechanics, illusion clones, stress-to-damage conversion.
- Hazards:
  - False exits
  - Possessed relic curios
  - Party split event risks
- Resource identity:
  - Rare trinkets
  - Story-critical archive fragments

## 2) Enemy Family Framework

## 2.1 Espantos Folcloricos

- Includes reinterpretations inspired by regional legends.
- Role style: stress damage, fear debuffs, and deception.
- Mechanical hooks:
  - Duplicate decoy creation
  - Terror marks
  - Escape/reappear patterns

## 2.2 Culto del Porton

- Infernal cultist network serving portal expansion.
- Role style: formation buffs, sacrifice combos, summon pressure.
- Mechanical hooks:
  - Backline chanters power frontline brutes
  - Ritual progress meter if not interrupted

## 2.3 Bestias Malditas

- Corrupted wildlife and livestock.
- Role style: bleed, pounce, speed pressure.
- Mechanical hooks:
  - Beastpack synergy
  - Bonus actions on wounded targets

## 2.4 Penados de la Hacienda

- Possessed workers and ancestral shades.
- Role style: tanky attrition and anti-heal pressure.
- Mechanical hooks:
  - Grudge stacks against specific hero actions
  - Retaliation when marked

## 2.5 Entes Infernales Mayores

- Mid-endgame infernal lieutenants.
- Role style: mixed elemental and stress burst.
- Mechanical hooks:
  - Arena control fields
  - Forced rank shifts
  - Corruption stacks over time

## 2.6 Sotanos Enemy Roster (approved 2026-11-06)

Vertical slice roster. `id` is the key used in `data/enemies.json` and `assets/enemies/<id>.png`. Ranks follow `03` notation (1 = front). In data: each enemy's `ranks` and each single-target skill's `target_ranks` in `data/enemies.json` (P1-03a; rules in doc 01 §2.1).

| id | Name | Family | Ranks | Role and gimmick |
|---|---|---|---|---|
| `espanto` | Espanto del Sótano | Espantos Folclóricos | 1–2 | Stress attacks, fear |
| `sombra_cuadrilla` | Sombra de cuadrilla | Penados de la Hacienda | 1–2 | Elite tank; riposte when marked |
| `peon_penado` | Peón penado | Penados de la Hacienda | 1–2 | Tank; grudge stacks against whoever heals |
| `mandador_en_pena` | Mandador en pena | Penados de la Hacienda | 2–3 | Anti-heal: blocks healing on one hero |
| `rata_de_troje` | Rata de troje | Bestias Malditas | 1–3 | Fast, bleed; spawns in pairs (beastpack) |
| `murcielago_bodega` | Murciélago de bodega | Bestias Malditas | 3–4 | Pounces on back ranks; each hit drains light |
| `monaguillo_porton` | Monaguillo del Portón | Culto del Portón | 3–4 | Backline chanter; buffs front ranks |
| `vigia_porton` | Vigía del Portón | Culto del Portón | 2–3 | Infernal scout: marks a hero, calls reinforcements if alive after 2 rounds |
| `susurro_aljibe` | Susurro del aljibe | Espantos Folclóricos | 3–4 | Stress damage to back ranks |
| `duende_sotano` | Duende del sótano | Espantos Folclóricos | 2–4 | Escape/reappear; steals colones if not killed |
| `sirviente_ahogado` | Sirviente ahogado | Penados de la Hacienda | 1–2 | Summon only (Mayordomo); weak guard |
| `cadejo_negro` | **Cadejo Negro** | Bestias Malditas | 1–2 | Roaming mini-boss (§3.2); flees if not killed fast |
| `mayordomo_hundido` | **El Mayordomo Hundido** | Penados de la Hacienda | 1–2 | Sotanos apex boss at the objective node (§3.1) |

Example squad: `peon_penado` + `sombra_cuadrilla` + `monaguillo_porton` + `vigia_porton` (tough front, buffing back line).

**Built (P2-04, 2026-11-17).** Enemy fields in `data/enemies.json`, rules in `scripts/combat/combat_controller.gd`:

| Enemy | Gimmick | How |
|---|---|---|
| `sombra_cuadrilla` | Riposte when marked | `riposte_when_marked`: strikes back like Respondón while Fichado |
| `peon_penado` | Grudge against healers | `grudge {dmg_pct 15, max 3}`: each heal adds a stack against that healer; it goes for them when in reach |
| `mandador_en_pena` | Anti-heal | New special *Embargo*: 80% *Embargado* for 3 turns (new status: no healing from skills, items or statuses) |
| `rata_de_troje` | Pairs | `pack 2`: a rat in a squad brings a second one if there is room |
| `murcielago_bodega` | Light drain | `on_hit_light −3` on every hit (plus *Aleteo apagavelas*); *Chupasangre* already reaches positions 3–4 |
| `monaguillo_porton` | Buffs the front | New special *Bendición torcida* (`target: allies`, `ally_ranks [1, 2]`): Chiva (+15% daño, +5 precisión) on the two in front, never twice |
| `vigia_porton` | Marks, then reinforcements | *Pedrada certera* now also marks (Fichado); `reinforce {after_round 2, count 1}`: alive at the start of round 3, it calls a Monaguillo, Peón or Rata (once, if there is room) |
| `duende_sotano` | Steals colones | Stolen colones come back if it dies; Agazapado on stealing is its escape |

Authored squads (`generator.squads`, used for 50% of regular fights): Portón (Peón, Vigía, Monaguillo), Hacienda (Peón, Mandador, Susurro; punishes healing), Bestias (2 Ratas, Murciélago), Espantos (Espanto, Duende, Susurro). Mid-fight spawning (`CombatController.spawn_enemy`, `GameState.make_enemy`) is ready for the Mayordomo's summons (P2-05).

## 2.7 Enemy Ability Rules (owner, 2026-11-07)

- Every enemy: one **basic attack** + **1–3 specials**. At least one special is **magical** (ignores Guard) or **inflicts an ailment** (`sangrado` bleed, `veneno` poison, `aturdido` stun).
- Ability names are Costa Rican and specific to the monster (folklore, hacienda work, Church, pulpería life), following [08-content-standards-satire.md](08-content-standards-satire.md).
- Data lives in `data/enemies.json` → `skills`; the AI picks by `weight`.

## 3) Boss Ladder

Each region includes:
- 1 apprentice boss
- 1 veteran boss variant
- 1 champion boss variant

## 3.1 Regional Apex Bosses (Launch)

1. `El Mayordomo Hundido` (Sotanos)
   - Mechanics: summon servants, darkness pulses, anti-guard attacks.
   - **Built (P2-05, 2026-11-17):**
     - He is the boss in the last room of every generated Sótanos map, with 2 *Sirvientes ahogados* as escort.
     - *Summons* (`summon`): every 3 rounds (rounds 4 and 7), he "toca la campanita del servicio" for another servant while fewer than 2 are standing, at most 2 per fight (with no cap the fight could stall: 77% clears in the sim).
     - *Darkness pulses* (`cycle`): every 4th round he always uses *Pulso de oscuridad* (party damage, −10 Luz, Chiva on himself). Every 3rd round drove long fights to Luz 0 and into stalls in the sim.
     - *Anti-guard*: *Golpe al escudo* ignores Guard, goes for a guarding hero, and does +50% to them (`vs_guard_pct`).
2. `La Segua de Niebla` (Bosque)
   - Mechanics: stress charm, mirror image phases.
3. `Capataz de Ceniza` (Canaverales)
   - Mechanics: field hazards and forced movement.
4. `El Herrero del Crater` (Ruinas Volcanicas)
   - Mechanics: armor phases, overheat detonations.
5. `La Campanera Sin Rostro` (Pueblo Fantasma)
   - Mechanics: sound-based fear stacks and illusion punish.

## 3.2 Roaming Mini-Bosses

- `Cadejo Negro`
- `Monje del Filo`
- `Recolector de Diezmos`

Rules:
- Randomly inserted in high-risk missions.
- Drop high-value trinkets and infernal shards.
- Escape if not killed quickly, reducing reward quality.

**Built (P2-05, 2026-11-17): Cadejo Negro in the Sótanos** (`generator.roaming` in `data/regions/sotanos.json`; rules in `GameState` and `CombatController._boss_round_start`).
- **When:** 0% Aprendiz, 50% Veterano, 75% Campeón. It starts in a fight, empty, curio or trap room away from the entrance, the camp and the boss.
- **Roaming:** every 3 party moves it moves to a neighbouring room of those kinds, never into the party's room. Once its room is revealed, the map marks it with a red dot (tooltip: *Rastro del Cadejo*).
- **The fight:** entering its room starts it: the Cadejo (elite HP) and a pair of Ratas de troje. The room's own reward is not paid. A curio or trap room still holds its event afterwards.
- **Flees:** if alive when round 5 starts (`flee_after 4`), it escapes, with no bounty.
- **Bounty:** killing it pays 600–900 ₡ × the difficulty's reward × loot multiplier, plus one random piece of equipment. Infernal shards wait for the material system (doc 02 §11).
- It is no longer in the regular elite pool; the Mandador en pena took its place.

## 3.3 Final Arc Boss Sequence

1. `Los Tres Notarios del Pacto` (multi-phase council fight)
2. `Corazon del Porton` (arena-transforming objective boss)
3. `Pacto del Abuelo` (final truth confrontation, branching finale)

## 4) Difficulty Ramp Targets

**Built (P6-01, 2026-11-26):** the region order and unlocks are data (`data/regions.json`): the Sótanos are open from the start; the Bosque opens once the Mayordomo is beaten (Cañaverales will too); later regions use `cleared_any` / `cleared_count`. Beating a region's boss at any difficulty counts (`GameState.regions_cleared`). The hub lists locked regions greyed out with the reason; a region still being built (`wip`) shows only in debug builds.

- Region order target:
  1. Sotanos
  2. Canaverales / Bosque (player choice)
  3. Pueblo Fantasma
  4. Ruinas Volcanicas
  5. Portal sequence

- Enemy stat scaling per tier:
  - Apprentice baseline
  - Veteran +22% HP, +12% damage, +10% resist
  - Champion +46% HP, +24% damage, +20% resist

## 5) Narrative Integration Hooks

- Every boss defeat unlocks:
  - Grandfather memory fragment
  - One new hacienda event type
  - New enemy mutation set in previously cleared regions

- Final arc conditions:
  - Minimum 4 regional apex clears
  - Portal key assembled from 3 ritual components
  - Story lock opens final mission chain
