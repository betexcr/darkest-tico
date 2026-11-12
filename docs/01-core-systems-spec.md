# Core Systems Specification

This document formalizes the gameplay loop and systemic rules for the Tico Gothic Roguelike.

## 1) Session Loop

1. Hacienda prep:
   - Review roster state, stress, injuries, diseases, and locked traits.
   - Buy provisions and utility items.
   - Upgrade hero skills and gear.
2. Mission selection:
   - Pick region, mission type, length, and risk tier.
   - Preview reward package and known hazards.
3. Expedition:
   - Traverse node-to-node map and resolve encounters.
   - Manage light pressure, supplies, stress, and inventory.
4. Extraction:
   - Return voluntarily, complete objective, or fail/retreat.
   - Process deaths, trauma, disease, and loot.
5. Week resolution:
   - Trigger town events, refresh recruit pool, update market offers.

## 2) Combat Model

### 2.1 Party and Ranks

- Player squad size: 4 heroes.
- Enemy squad size: 1-4 enemies.
- Battlefield ranks: front (1) to back (4) on each side.
- Skill availability depends on:
  - User position constraints.
  - Target position constraints.
  - Status conditions (stun, daze, immobilize).

### 2.2 Turn Order

- Initiative roll each round:
  - `initiative = baseSpeed + random(-2..+2) + statusModifiers`
- Highest initiative acts first.
- Tie-breakers:
  1. Higher base speed
  2. Higher resolve level
  3. Random

### 2.3 Hit, Crit, and Damage

- Hit check:
  - `hitChance = attackerAccuracy + skillAccuracy - targetDodge`
  - Clamp to 5%-95%.
- Crit check:
  - `critChance = baseCrit + skillCritMod + buffs - targetCritResist`
  - Crit multiplies damage and applies stress shock.
- Damage:
  - `rawDamage = random(skillMin, skillMax) * (1 + atkMods)`
  - `finalDamage = rawDamage * defenseMultipliers * resistMultipliers`

### 2.4 Death's Door Equivalent

- At 0 HP hero enters `Al Borde`.
- While at `Al Borde`, any further damage triggers death save:
  - Base survival chance: 67%.
  - Reduced by prior `Al Borde` checks in same mission.
  - Reduced by high stress and doom-type debuffs.
- Failed save -> hero death.

### 2.5 Status Types

- Damage-over-time: bleed, burn, rot.
- Control: stun, pull, push, root.
- Utility: mark, guard, riposte, stealth, taunt.
- Mental: fear, paranoia, panic spikes.

## 3) Stress and Affliction Model

### 3.1 Stress Scale

- Stress ranges from 0 to 200.
- Common stress sources:
  - Enemy crits and fear attacks.
  - Ambushes and traps.
  - Low light state.
  - Horror events and failed curios.

### 3.2 Resolve Check at 100

- At 100 stress, hero tests resolve:
  - 75% chance `Quebranto` (negative affliction).
  - 25% chance `Virtud` (positive breakthrough).
- On `Virtud`, stress drops to 40.
- On `Quebranto`, stress remains and behavior corruption begins.

### 3.3 Affliction Behavior Hooks

Seven `Quebranto` afflictions (one picked at random on a failed resolve check). Behaviour hooks live in `scripts/domain/stress_system.gd`; stat changes are data (`data/statuses.json` `mental_mods`, read by `StatusEffects.stat()`).

- `Paranoia`: 35% chance to refuse a heal/buff skill (turn lost); in camp, may refuse a companion's care.
- `Cobardia`: 20% chance to skip the turn and gain +5 stress.
- `Ira Ciega`: 15% chance per attack to hit a random ally for 2–5 instead.
- `Bravata`: 20% chance per attack to waste 5 Luz showing off (extra resource use).
- `Desesperanza`: when hit, 25% chance to give every other living hero +3 stress.
- `Nervios`: −5 accuracy, −5 crit.
- `Fatalismo`: −15 points of death-save chance (Al Borde and Colapso).

Seven `Virtud` breakthroughs (stress drops to 40):

- `Serenidad`: incoming stress −25%.
- `Firmeza`: +8 points of death-save chance.
- `Valentia`: +15% damage.
- `Punteria`: +5 accuracy, +5 crit.
- `Esperanza`: from round 2 on, other living heroes −2 stress at the start of each round.
- `Vigor`: from round 2 on, +1 PV at the start of each round (not while Al Borde).
- `Abnegacion`: 25% chance to take a single-target attack aimed at a companion (not while Al Borde).

### 3.4 Heart-Attack Equivalent at 200

- At 200 stress, hero suffers `Colapso`.
- If above 0 HP: drops to `Al Borde`.
- If already at `Al Borde`: immediate death check with severe penalty.

## 4) Expedition Map Structure

### 4.1 Node Types

- Combat node
- Curio node
- Trap node
- Camp node (`Fogata de Trocha`)
- Elite node
- Boss node
- Safe pocket node (rare)

### 4.2 Graph Rules

- Mission graph is generated as a directed branching network.
- Minimum one critical path to objective.
- Optional branches contain risk/reward spikes.
- Dead ends can host rare relic or elite ambush.

### 4.3 Scouting and Fog

- Base map reveals adjacent node type only.
- Scouting effects can reveal:
  - Future nodes
  - Encounter danger
  - Trap placement
  - Curio outcomes

### 4.4 Camp Rules

Implemented (P3-07). Data: `data/camp_skills.json`; rules: `scripts/domain/camping_system.gd`.

- Each expedition carries **1 leña** (`firewood_per_expedition`, or region `firewood`). Camping in a Fogata room spends it; the party may also walk on and come back later.
- Camp phase:
  1. **Meal** in gallo pinto (cost listed for 4 heroes, scaled down with fewer living): Festín 4 (+25% PV, −10 stress), Comida completa 2 (+10% PV), Media ración 1 (no effect), Ayuno 0 (−20% PV, never below 1; +15 stress).
  2. **Respite: 12 points.** Each hero carries 4 camp skills (`camp_skill_ids`: 2 of the class + 2 shared). Each hero may use each of their skills once per camp. Targets: self, one companion, every companion, or the whole party. Effects: stress, % PV, cures, and buffs that last **4 fights** (same stat keys as statuses).
  3. **Night ambush:** 12% base, +6% if Luz was under the low-light threshold, 0% if a watch skill was used (Dron vigía, Guardia de corral, Ronda con foco, Vigilia de oración). The ambush is a fight against 2–3 region monsters in which the enemies act first in round 1. It pays nothing.
- After sleeping, Luz resets to 100.
- Guardabosques del Arenal (swapping and learning camp skills, doc 02 §9) is not built yet.

## 5) Mission and Objective System

### 5.1 Mission Types

- Explore X% of map.
- Purge corrupted altar.
- Recover relic set.
- Defeat roaming elite.
- Kill regional boss.
- Escort survivor to exit.

### 5.2 Mission Length Tiers

- Short: 8-12 nodes
- Medium: 13-18 nodes
- Long: 19-26 nodes

Longer missions increase reward multipliers and roster fatigue.

### 5.3 Failure/Retreat

- Retreat options:
  - Combat retreat with penalty chance.
  - Mission abandon with partial loss.
- Penalties:
  - Increased stress
  - Possible random trinket loss
  - Reputation/morale hit event next week

## 6) Reward Resolution

- Reward bundle is made of:
  - Colones
  - Upgrade relics
  - Trinkets
  - Story fragments
- Completion grades:
  - Perfect clear
  - Objective clear
  - Partial
  - Failed extraction

Grade impacts loot roll quality and town event weighting.

### 6.1 Resolve Level and Expedition Difficulty

Implemented (P3-04, XP part). Data: `data/progression.json`; rules: `scripts/domain/resolve_system.gd`.

- Heroes have a **resolve level 0–6** (Novato, Aprendiz, Baquiano, Veterano, Maestro, Campeón, Leyenda). Cumulative XP to reach each level: 2 / 8 / 14 / 24 / 36 / 48.
- **Resolve XP is earned only by completing an expedition** (killing the boss). Fleeing or a wipe gives none, and the fallen get none.
- Each level adds **+10% resistance** to Atarantado, Veneno, Sangrado and Salado, and **+5%** to Trampas.
- **Expedition difficulty** is picked in the hub (one global picker, owner 2026-11-08). Enemy scaling follows doc 05 §4:

| Difficulty | Level | Heroes without penalty | XP per survivor | Enemy PV / damage / accuracy / ailment resist | Pay |
|---|---|---|---|---|---|
| Aprendiz | 1 | 0–2 | 4 | ×1 / ×1 / +0 / +0% | ×1 |
| Veterano | 3 | 3–4 | 8 | ×1.22 / ×1.12 / +3 / +10% | ×1.6 |
| Campeón | 5 | 5–6 | 16 | ×1.46 / ×1.24 / +6 / +20% | ×2.5 |

- **Regions have their own level** (owner 2026-11-08: "dungeons should have scaling difficulty, Sótanos the easiest"). Each region JSON has a `region_level` following the doc 05 §4 order: Sótanos 0, Cañaverales/Bosque 1, Pueblo Fantasma 2, Ruinas Volcánicas 3, Portal 4. It **adds to the picked difficulty**:
  - The expedition level and the hero range both move up by the region level, capped at 6. For example, Aprendiz in Bosque is level 2 for heroes 1–3.
  - Per region level, enemies get +11% PV, +6% damage, +1 accuracy and +5% ailment resist, pay grows 15%, and survivors earn +1 XP (`progression.json` `region_scaling`).
  - The hub shows the combined level on each difficulty and the region's offset in the region list. The validator requires Sótanos to have the lowest `region_level`.

- A hero **above** the difficulty's range refuses to go, and the expedition can't start with them in the party (same rule as Darkest Dungeon). Two exceptions, also from DD:
  - **Modo Pura Vida** (DD's Radiant mode; a checkbox in the hub, saved): heroes accept expeditions up to 2 levels below their range (`radiant_extra_levels`) and level up on a faster curve: 2 / 7 / 13 / 21 / 29 / 40 XP.
  - **Mano vuelta** (DD's Helping Hand town event): for that week nobody refuses. Under-leveled heroes still take the penalty.
- A hero **below** it goes **under-leveled**: +20 stress per missing level on entering, plus 25% more stress taken per missing level for the whole mission.
- Skill ranks gated by level: see §6.3. Not built yet: level-tiered treatment prices (doc 04 §3.5).

### 6.2 Victory Screen

After a completed expedition (`scripts/expedition/victory_screen.gd`, shown by `main.gd` before the hub):

1. **Page 1:** the encargo reward, colones from fights and curios, the items found, fights won (elites and bosses), curios, camps, ambushes, and the total.
2. **Page 2:** one card per hero with portrait, Resolve XP gained, a level badge and XP bar, any level-up, a new Quebranto or Virtud, PV and stress. The fallen are greyed out with no XP.

The data comes from `GameState.mission_ledger`, filled during the run, and `GameState.complete_mission()`.

### 6.3 Skill Ranks (Casa Comunal de Oficios)

Implemented (P3-04). Data: `data/progression.json` `skill_ranks` (and an optional `rank_bonus` per skill in `skills.json`); rules: `scripts/domain/skill_ranks.gd`; hub row: `hacienda_hub.gd` `_refresh_skills`.

- Every hero skill has a **rank 1–5**, bought one step at a time in the hub for the selected hero. Gated by resolve level, as in Darkest Dungeon:

| Rank | Needs Resolución | Cost (doc 04 §3.3) |
|---|---|---|
| 2 | 1 | 300 ₡ |
| 3 | 2 | 900 ₡ |
| 4 | 3 | 1,500 ₡ |
| 5 | 4 | 2,700 ₡ |

- **Each rank above 1** adds to the numbers the skill already has (`per_rank`):
  - attacks: +1 min and max damage, +1 accuracy, +1% crit;
  - heals: +1 min and max;
  - stress relief: +1;
  - statuses it applies: +5% chance (capped at 100%) and +1 value (bleed, poison, Sobado…).
  - Turns, status mods and cures don't change.
- A skill's own `rank_bonus` replaces `per_rank`. It may use `status_mods` (+N to each numeric status mod per rank). Escudo de Barrio uses it: +5 protection on its Chiva per rank.
- Combat reads every hero skill through `GameState.hero_skill(hero, id)`, so the action bar, tooltips, attacks, heals and ripostes all use the hero's rank. Rank pips show on the skill icons.
- Recruits start at rank 1. A seasoned hero from a town event (Veterano de las Bananeras) arrives with every skill at the highest rank their resolve allows. A resurrected hero keeps their ranks. Levels from the idle-class event don't grant ranks.
- Town events can close the Casa Comunal or change its price with the `casa_comunal` service (`closed`, `service_pct`). No event uses it yet.
- Save v8 stores `skill_ranks` per hero. Older saves load at rank 1.
- Not built: unlocking new skills (every class has exactly 4) and the building upgrades from doc 02 §4 (P3-16, P3-17).

## 7) Balancing Guardrails (Initial)

- Average mission win rate target: 60-70% for equal-level parties.
- Attrition target:
  - 1-2 heroes needing recovery per successful mission.
  - 0.2-0.4 deaths per long mission in high-risk tiers.
- Stress economy target:
  - Low light should feel profitable but dangerous.
  - Stress healing should never fully erase poor decisions in one week without heavy spending.
