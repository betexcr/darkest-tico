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

- `Paranoia`: chance to refuse buffs/heals.
- `Cobardia`: chance to move backward and self-debuff.
- `Ira Ciega`: chance to mis-target attacks.
- `Bravata`: chance to consume extra resources.
- `Virtud` examples:
  - `Serenidad`: incoming stress reduced.
  - `Firmeza`: death save chance increased.

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

- One camp trigger item allowed per mission segment.
- Camp phase:
  1. Food spend decision (heal/stress tradeoff).
  2. Respite points allocated to camp skills.
  3. Ambush chance roll (affected by buffs).

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

## 7) Balancing Guardrails (Initial)

- Average mission win rate target: 60-70% for equal-level parties.
- Attrition target:
  - 1-2 heroes needing recovery per successful mission.
  - 0.2-0.4 deaths per long mission in high-risk tiers.
- Stress economy target:
  - Low light should feel profitable but dangerous.
  - Stress healing should never fully erase poor decisions in one week without heavy spending.
