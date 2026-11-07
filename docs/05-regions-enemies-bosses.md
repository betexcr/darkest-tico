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

Vertical slice roster. `id` is the key used in `data/enemies.json` and `assets/enemies/<id>.png`. Ranks follow `03` notation (1 = front).

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

## 3.3 Final Arc Boss Sequence

1. `Los Tres Notarios del Pacto` (multi-phase council fight)
2. `Corazon del Porton` (arena-transforming objective boss)
3. `Pacto del Abuelo` (final truth confrontation, branching finale)

## 4) Difficulty Ramp Targets

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
