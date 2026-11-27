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

**Built (P6-10a, 2026-11-26): the Bosque roster** (`data/enemies.json`, `data/regions/bosque.json`; art in P6-10b, balance in P6-10c):

| id | Name | Family | Ranks | Role and gimmick |
|---|---|---|---|---|
| `tigrillo_bruma` | Tigrillo de la bruma | Bestias | 1–2 | Fast, dodgy; pounce that bleeds and hides it (Agazapado) |
| `danta_embrujada` | Danta embrujada | Bestias | 1–2, **large** | Tank (prot 15); charge pushes a hero back 2; mud slows dodge (elite) |
| `mono_congo_poseido` | Mono congo poseído | Bestias | 3–4 | Thrown guavas anywhere; howl that stresses the whole party |
| `sapo_quebrada` | Sapo de la quebrada | Bestias | 2–3 | Vermin in pairs; poison spit |
| `llorona_del_rio` | La Llorona del río | Espantos | 3–4 | Party stress + Susto; marks the weakest (elite) |
| `viejo_del_monte` | Viejo del Monte | Espantos | 2–3 | Vines that root (Amarrado); false directions (−8 precisión) (elite) |
| `brujo_de_la_montana` | Brujo de la montaña | Culto | 3–4 | Poison curse; black copal smoke buffs the two in front |
| `lenador_penado` | Leñador penado | Penados | 1–2 | Tank; bleeding axe; falling tree stuns; grudge against healers |
| `nuboso_spectre` | Espectro de niebla | Espantos | 1–2 | (slice) dodgy ghost; boss escort |
| `segua_boss` | **La Segua de Niebla** | Espantos | 1–2 | Apex boss (70 PV): at 60% she splits into 2 mirror images; Veterano adds a 30% phase (one more image, Chiva); Campeón: *Galope de niebla* (party, may Susto) replaces *Relincho* |

Squads: fog ghosts (Espectro, Viejo, Llorona), beasts (Tigrillo, Sapos, Mono), the woodcutter's camp (Leñador, Brujo, Mono), Danta + Brujo. Hazards: *Flora venenosa* (8%/move, veneno), *Sendero que confunde* (5%/move, back to the room before), *Niebla cerrada* (+15% night ambush below Luz 50). Events: 15 new curios (quetzal nest, hollow ceiba, spring, roadside cross, highlander's shack, orchids, toad stone, lagoon, hunters' camp, offering to the Viejo del Monte, wasp nest, shawl in the creek, ranger station, warm hearth, shoe tree) + 4 outdoor Sótanos ones; 6 new traps + Raíces traicioneras.

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

**Built (P6-11a, 2026-11-27): the Cañaverales roster** (`data/enemies.json`, `data/regions/canaverales.json`; art in P6-11b, balance in P6-11c; the region is still `wip`):

| id | Name | Family | Ranks | Role and gimmick |
|---|---|---|---|---|
| `machetero_de_zafra` | Machetero de la zafra | Penados | 1–2 | Bleed bruiser; low cut that bleeds hard |
| `quemador_de_cana` | Quemador de caña | Culto | 2–3 | Sets the cane on fire: party damage, smoke (−precisión); boss escort and summon |
| `rata_canera` | Ratas cañeras | Bestias | 2–3 | Swarm in pairs; gnaws ankles: bleed and pulls a hero forward |
| `zompopas_de_mayo` | Zompopas de mayo | Bestias | 1–2 | Swarm in pairs; the ground crawls: party −esquiva |
| `boyero_maldito` | Boyero maldito | Penados | 2–3 | Midline disruption: pushes back, shuffles a hero, marks |
| `espantapajaros_del_canal` | Espantapájaros del cañal | Espantos | 1–2 | Tank (prot 10, fuego ×2); straw roots a hero; party stress |
| `buey_de_ceniza` | Buey de ceniza | Bestias | 1–2, **large** | Tank (prot 15); burning cart drags a hero to the back (elite) |
| `rezadora_del_porton` | Rezadora del Portón | Culto | 3–4 | Party stress + Susto; ash blessing buffs the front three (elite) |
| `tulevieja` | La Tulevieja | Espantos | 3–4 | Dodgy flyer: bleeding talons, pulls a hero 2 forward, bell that stresses everyone (elite) |
| `monaguillo_porton`, `vigia_porton` | (Sótanos cultists) | Culto | 3–4, 2–3 | The cult runs these fields too |
| `capataz_de_ceniza` | **El Capataz de Ceniza** | Penados | 1–2 | Apex boss (65 PV, prot 10): *¡A la fila!* pulls a back hero 2 forward; *Arreo de peones* shuffles one; *Quema del cañal* every 4th round (fire, party, bleed); whistles up a Quemador (max 2 a fight). Veterano: Chiva at 50% PV, burns every 3 rounds. Campeón: *Humo de trapiche* (party, −precisión/esquiva) replaces *Arreo* |

Squads: the zafra crew (Machetero, Boyero, Quemador), the swarm (Zompopas + Ratas: four bodies), the cult rite (Espantapájaros, Vigía, Monaguillo), Buey + Quemador. Hazards: *Fuego en el cañal* (8%/move, party damage + stress), *Zanjas y surcos* (15% of fights start with the party shuffled), *Tótems del Portón* (20% of fights: enemies start with Chiva). Rewards: richer colones than the Bosque (440–600 a fight, objective 1300) and Reliquias from two curios (Trapiche de bueyes, Cruz de ceniza) until the Fragmentos (P6-05). Events: 15 new curios (oxcart, ox mill, sugar pan, ritual spiral, harvesters' graves, workers' barracks, molasses tank, ash cross, estate store, abandoned yoke, cult flag, irrigation ditch, hawk's nest, foreman's house, half-done burn) + 4 Sótanos ones; 6 new traps + 2 Sótanos ones.

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

**Built (P6-02, 2026-11-26): region hazards.** A region file lists `hazards`, each `{id, name, text, trigger, chance_pct, min_light?, max_light?, …}`: `trigger: "move"` rolls on every room move and applies an event `outcome` (poison flora, heat pulses, falling rocks, eruptions, fire…); `"fight_start"` rolls when a fight starts, with an `outcome` on the party and/or `enemy_applies` on every enemy (cult totems, shifting ground); `"camp"` adds `ambush_pct` to the night ambush. New outcomes: `shuffle_party` (forced-movement terrain) and `send_back` (a false exit returns the party to the room before). The hub's region tooltip and the start of an expedition list the region's dangers; a hit shows as a result card. Rules `scripts/domain/region_hazards.gd`. The Sótanos have none (their dangers are traps and curios); the Bosque has placeholder poison flora (8% per move) and *Niebla cerrada* (+15% night ambush below Luz 50) until P6-10. Party split (Pueblo Fantasma) still needs its own design (P6-12).

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

**Built (P6-03, 2026-11-26): the engine for the Alpha rosters** (`data/enemies.json`, `scripts/combat/combat_controller.gd`, `scripts/domain/formation.gd`):
- Every enemy has a `family` (espantos, culto, bestias, penados, infernales; Spanish names in `families`), shown in the enemy panel. Hero attacks may have `vs_family` ({family: +%}).
- `size: 2` is a large enemy: it stands on two positions, is hit by a skill reaching either, and counts as two when squads, summons and reinforcements are fitted into the four positions. On stage it is wider.
- `phases`: [{at_hp_pct, text, self_applies, prot, clones}] trigger once when its PV fall to that %: statuses on itself, extra protection, mirror images.
- Mirror images (`clones` {count, hp_pct, stress_on_hit}): copies with few PV and only the basic attack, named "(reflejo)", no phases or drops; a hero who hits one gains stress (illusion punish); once no real enemy is left they fade and the fight is won.
- Stealth enemies were already built (Agazapado, the Duende): single-target attacks skip a hidden unit while another is in reach.

## 2.7 Enemy Ability Rules (owner, 2026-11-07)

- Every enemy: one **basic attack** + **1–3 specials**. At least one special is **magical** (ignores Guard) or **inflicts an ailment** (`sangrado` bleed, `veneno` poison, `aturdido` stun).
- Ability names are Costa Rican and specific to the monster (folklore, hacienda work, Church, pulpería life), following [08-content-standards-satire.md](08-content-standards-satire.md).
- Data lives in `data/enemies.json` → `skills`; the AI picks by `weight`.

## 3) Boss Ladder

Each region includes:
- 1 apprentice boss
- 1 veteran boss variant
- 1 champion boss variant

**Built (P6-06, 2026-11-26):** a boss may list `tiers` (`veterano`, `campeon`; Campeón also takes the Veterano block): `text` (logged when the fight starts), `add_skills` / `replace_skills` (the merged boss still has 1 basic + 1–3 specials), `phases`, `summon` / `cycle` overrides, `status_resist` and `prot` additions. Rules `scripts/domain/boss_tiers.gd`, applied in `GameState.make_enemy` before the difficulty numbers; the enemy panel shows "variante Veterano / Campeón". The Mayordomo has both: at Veterano he hardens at 50% PV (+15% protección, Chiva +15% daño); at Campeón *Agua de la bodega* (agua, the whole party, may slow) replaces *La cuenta, por favor*, the darkness pulse comes every 3 rounds and up to 3 servants come. Sim (2000 boss fights, seasoned parties): Veterano 100 → 99.8%, Campeón 99.5 → 98.5% with more stress (party +85 → +122).

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
