# Economy and Progression Balance Spec

This spec defines currency loops, costs, reward scaling, and long-term pacing targets.

## 1) Currency Model

### 1.1 Colones (soft currency)

Primary use:
- Provisions
- Skill training
- Stress relief
- Trait treatment
- Basic upgrades

Primary sources:
- Mission completion rewards
- Gold stack loot nodes
- Sell duplicate trinkets

### 1.2 Reliquias del Abuelo (upgrade relics)

Primary use:
- Building upgrades in Hacienda
- District-style structures

Primary sources:
- Objective completion cache
- Curio outcomes
- Boss and elite drops

### 1.3 Fragmentos Infernales (hard progression)

Primary use:
- Late gear tiers
- Endgame rituals
- High-rank class mastery unlocks

Primary sources:
- High-risk map branches
- Regional apex bosses
- Portal event chains

## 2) Expedition Reward Bands

## 2.1 Base Reward by Mission Length

| Length | Colones | Reliquias | Fragmentos |
|---|---:|---:|---:|
| Short | 3,500-6,000 | 8-14 | 0-2 |
| Medium | 6,500-10,500 | 14-24 | 1-4 |
| Long | 11,000-18,000 | 24-40 | 3-8 |

## 2.2 Risk Modifier

- Low risk: `x0.85`
- Standard: `x1.00`
- High: `x1.25`
- Brutal: `x1.55`

## 2.3 Performance Modifier

- Perfect clear: `+25% total value`
- Objective clear: baseline
- Partial clear: `-35% total value`
- Mission fail: `-70% total value`, keep only extracted inventory

## 3) Core Cost Structure

## 3.1 Provisions

Per mission starting loadout target:
- Short: 1,200-2,200 colones
- Medium: 2,200-3,600 colones
- Long: 3,600-5,400 colones

## 3.2 Stress Relief

- Tier 1 activity: 1,000 colones
- Tier 2 activity: 1,250 colones
- Tier 3 activity: 1,500 colones
- Veteran tier multiplier: `x1.4`
- Champion tier multiplier: `x1.8`

## 3.3 Skill Training

- Unlock new skill: 1,000 base
- Rank 2: 300
- Rank 3: 900
- Rank 4: 1,500
- Rank 5: 2,700

Training discount building line should reduce this up to 50% at cap.

## 3.4 Equipment Upgrades

Weapon/armor costs per hero:
- Rank 1 -> 2: 900
- Rank 2 -> 3: 1,900
- Rank 3 -> 4: 3,400
- Rank 4 -> 5: 5,600 + 3 infernal fragments

## 3.5 Trait and Disease Treatment

- Negative trait remove: 1,500 / 2,100 / 2,700 (tiered by resolve)
- Locked negative remove: 5,000 / 7,000 / 9,000
- Positive trait lock/remove: 7,500 / 10,500 / 13,500
- Disease cure: 750 / 1,050 / 1,350

## 4) Attrition and Recovery Targets

- On average successful mission should produce:
  - 1 hero needing stress care
  - 1 hero needing medical/trait attention every 2 missions
  - 1 death every 5-8 medium/high-risk missions
- Reserve roster target:
  - At least 8 mission-ready heroes by midgame
  - 12+ by late game

## 5) Weekly Cashflow Expectations

## 5.1 Early Game (weeks 1-12)

- Expected inflow: 5,000-10,000 per week.
- Expected outflow: 4,500-9,500 per week.
- Goal: mild pressure, not bankruptcy spiral.

## 5.2 Midgame (weeks 13-35)

- Expected inflow: 11,000-24,000 per week.
- Expected outflow: 10,000-22,000 per week.
- Goal: maintain meaningful tradeoffs between building and roster maintenance.

## 5.3 Endgame (week 36+)

- Expected inflow: 22,000-42,000 per week.
- Expected outflow: 21,000-45,000 per week.
- Goal: force strategic spending and risk-taking for infernal progression.

## 6) Sink/Faucet Controls

### Faucets

- Mission completion bundles
- Curio jackpot outcomes
- Sell value from excess trinkets
- Event bonuses

### Sinks

- Stress and treatment spending
- Gear and skill investment
- Provisioning and utility item replenishment
- High-tier ritual unlock fees

Balancing policy:
- If average wallet growth > 20% over 5 weeks, increase sink pressure 8-12%.
- If bankruptcy events spike > 30% of campaigns, reduce provisioning and treatment costs 10%.

## 7) Progression Gates

- Region unlocks tied to:
  - Story beats
  - Hacienda upgrade thresholds
  - Boss clear flags
- Class unlocks tied to:
  - Quest chains and building levels
- Late power gates require both:
  - Colones (operational readiness)
  - Fragmentos Infernales (capstone progression)

## 8) Anti-Snowball Design

- Diminishing returns on repeated low-risk farming.
- Market inflation event can spike trinket/provision costs temporarily.
- Hero downtime constraints prevent one-core-team steamroll.
- Death of over-invested heroes should hurt but not delete campaign viability.
