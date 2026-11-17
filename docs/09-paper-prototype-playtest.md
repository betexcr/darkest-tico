# Paper Prototype: Prep → Mission → Recover → Upgrade

Use this for first playtests without a build. One facilitator, 1–4 players controlling heroes.

## 1) Materials

- Printed expedition grid (8–12 nodes): circles, lines, node types written in pencil.
- Four hero sheets: name, class, HP, stress, 4 skill slots, position 1–4.
- Enemy cards: name, HP, damage band, special.
- Tokens: bleed, stun, mark, fear.
- Dice: d6 for hit variance, d20 for death save optional.
- Resource tracker: food, light (Valor de la Luz 0–100), colones.

## 2) Loop (one “week”)

1. **Prep at Hacienda** (5 min)
   - Buy provisions: 1 food per hero per 3 nodes (simplified).
   - Set light to 80.
   - Pick 4 heroes and write starting positions.

2. **Mission** (20–30 min)
   - Move token node to node; resolve each node type using [07-expedition-events-and-taxonomy.md](07-expedition-events-and-taxonomy.md) tables simplified to d6 rolls.
   - Combat: each hero one action per round; enemies one action each; 3 rounds max per fight unless boss.
   - On low light (<40): +1 stress per node; +1 ambush chance at camp.

3. **Extraction**
   - If any hero HP 0: death save (4+ on d6 = live at Al Borde once).
   - Record stress 100+ → resolve test: coin flip Quebranto / Virtud simplified.

4. **Recover / Upgrade** (5 min)
   - Spend colones: stress relief (remove 30 stress for 1000), or bank for next week.
   - Optional: one skill rank +1 on one hero if mission succeeded.

## 3) Success criteria for the session

- At least one meaningful choice between branches.
- At least one hero felt useful due to class skill.
- Economy felt tight but not hopeless.

## 4) Notes to capture

- Which nodes felt empty?
- Which combats dragged?
- Did players understand light and stress?

Feed results into [04-economy-progression-balance.md](04-economy-progression-balance.md) and combat tuning in [01-core-systems-spec.md](01-core-systems-spec.md).

## 5) Playtest notes — 2026-11-12, headless campaign (P1-09)

**How it was played.** `tools/playtest_campaign.gd` played 6 campaigns of 8 weeks (48 expeditions) in the Sótanos through the real expedition screen. Each week had the full loop: prep at the hacienda, the mission, the trip back, then recovery and upgrades. The player was a careful bot:
- **Hub:** hires to 4–6 heroes and takes the 4 least stressed. Pays the EBAIS and the Iglesia, buys the missing provisions plus 2 agua de pipa and a venda, and buys one Casa Comunal rank after a win. It moves up a difficulty when a hero refuses.
- **Expedition:** heals and lights a candle between rooms, eats when hungry, disarms traps at ≥ 50%, examines curios and always camps.
- **Combat:** the sim's "smart" policy (`tools/sim_policy.gd`) plus healing items.
- **Routes:** three campaigns visited every room before the boss (`--route full`); three went straight to the boss through the camp (`--route direct`).

Raw output: [playtests/2026-11-12-campaign-full.md](playtests/2026-11-12-campaign-full.md) and [playtests/2026-11-12-campaign-direct.md](playtests/2026-11-12-campaign-direct.md).

**Bot limits.**
- It ignores class mix when it picks the party, so some parties had 3 Tecnólogos or 3 Abuelas.
- It never equips gear, takes town-event offers or benches a seasoned hero to stay on Aprendiz.
- It can't judge feel, readability or whether a choice was interesting. Those need a human session.

### Results

| | Full route | Direct route |
|---|---:|---:|
| Expeditions cleared | 23 / 24 | 23 / 24 |
| Moves per expedition | 19.3 | 7.6 |
| Fights per expedition (incl. elite, boss, ambush) | 5.5 | 3.6 |
| Avg rounds: normal / elite / boss | 5.9 / 6.8 / 14.3 | 5.8 / 5.9 / 8.6 |
| Fights over 8 rounds | 32 of 132 | 17 of 87 |
| Heroes lost per expedition | 0.17 (all in 1 wipe) | 0.17 (all in 1 wipe) |
| Quebranto/Virtud per expedition | 0.25 | 0.04 |
| Average top stress at the end | 46 | 33 |
| Hunger stops (short of food) | 53 (26) | 5 (0) |
| Loot per expedition | 5,334 ₡ | 3,933 ₡ |
| Hub spending per week (provisions) | 2,162 ₡ (852 ₡) | 1,164 ₡ (352 ₡) |
| Colones after week 8 | 24–41k | 21–34k |
| Expeditions at Aprendiz / Veterano / Campeón | 13 / 9 / 2 | 13 / 9 / 2 |

Both wipes came late, in Veterano week 7 and Campeón week 8. Each was a long fight (41 and 22+ rounds) in which stress reached 143–200 and several heroes broke.

### Doc 09 success criteria
- **A meaningful choice between branches:** partly. Exploring every room pays about 36% more loot, but it costs 2.5× the moves, half the hunger stops go short, and fights and stress go up. That is a real trade-off. Whether it feels like a choice needs a human.
- **A hero felt useful thanks to a class skill:** every class used 2–3 of its skills. Some lean on one: Tecnólogo *Exploit Zero-Day* 55–67%, Guachimán *Ronda Nocturna* 78–89%, Exorcista *Expulsión* 79%. The Abuela's heal (*Sopa Milagrosa*) is about a third to a half of her turns.
- **Economy tight but not hopeless:** **not tight.** Loot is 2–4× what the hub costs, so colones grow from 5,000 to 21–41k in 8 weeks. The Iglesia was never needed: the party's average stress back at the hub never reached 30.

### Notes to capture
- **Empty nodes:** not measurable by the bot.
- **Combats that dragged:**
  - Bosses from Veterano up, which often ran 12–51 rounds.
  - Parties heavy on healers. In week 8 of one full campaign, 3 Abuelas + a Curandero fought 9 to 51 rounds per fight, out-healing what they could kill. This is the stall already seen in the sim (doc 10).
- **Understanding light and stress:** needs a human.

### Phase 1 exit criteria (doc 06)
- **Rank system:**
  - The rules hold: positions, reach and collapse are tested, and the validator guarantees every class can hit position 1.
  - With parties ordered by preferred position, the bot almost never needed *Moverse*.
  - How positions *feel* still needs a human (P1-03a is in `review`).
- **Stress breakpoints:** reached in only 3 of 48 expeditions, and each time in a fight past 20 rounds. In normal runs stress tops out around 35–50, so Quebranto rarely comes up. For a game built on stress, that is probably too low.
- **Mission pacing for short runs:**
  - The direct route (about 8 moves, 3–4 fights, about 1 hunger stop) fits a short mission, and the recommended 10 gallo pinto is enough.
  - Full exploration (about 19 moves) needs about 16. The recommended provisions only cover a direct run.

### For the owner (balance pass P5-02)
1. Make the economy tighter (less loot, or higher hub and provision costs).
2. More stress in normal fights so Quebranto shows up before the boss.
3. Heroes reach Veterano by week 4–6 and Campeón by week 7–8. Decide whether progression is too fast.
4. Decide whether recommended provisions should assume full exploration (about 16 gallo pinto).
5. Give healer-heavy parties a way to end fights (or heal less), so they don't stall.

## 6) Balance pass — 2026-11-17 (P5-02)

**How it was measured.** `tools/playtest_campaign.gd -- --campaigns 3 --weeks 8 --telemetry <path>` (seeds 1 and 2 from iteration 5 on, so 48 expeditions per measurement), summarised with `tools/telemetry_report.py`. The combat sim (`tools/sim_combat.gd`) checked fights in between.

**Bot changes.** These changed what "careful player" means; earlier numbers aren't directly comparable.
- It retreats a breaking party: 2 Quebrantos, or a hero at 150 stress.
- It leaves frayed heroes home (a Quebranto or 100+ stress sorts last; a hero at 150 stays home if 3 others can go).
- In combat it finishes a weak or last enemy before healing or calming (`tools/sim_policy.gd`), and calms at 70 stress instead of 50. Without this the bot calmed forever while a boss sat at 10 PV.

**Iterations** (success = objective reached; deaths per expedition):

| # | Change | Success (Aprendiz / Veterano) | Deaths | Notes |
|---|---|---:|---:|---|
| 0 | baseline | 96% | 0.29 | 0.08 Quebranto/Virtud per mission; colones 5k → 11–22k |
| 1 | enemy stress +150%, long fights +4/round from round 12, rewards −20% | 25% | 0.79 | 29 collapses; every campaign went broke |
| 2 | stress +60%, +3/round, rewards −10% | 46% (65 / 0) | 0.21 | stressed parties fled the first room, earned nothing: a spiral |
| 3 | + rest at home (15/week), bot leaves frayed heroes home | 54% | 0.71 | stress 150–200, collapses |
| 4 | stress +35%, long fights from round 14 | 71% (89 / 17) | 0.50 | first good run |
| 5 | Aprendiz enemy HP ×1.1, Veterano ×1.15 HP / ×1.06 damage | 40% | 0.54 | campaigns starved (2k in, 2.4k out a week) |
| **6** | **rewards back to original, Aprendiz HP ×1.0** | **71% (91 / 31)** | **0.52** | **kept**: money balanced, ~1 Quebranto/Virtud per mission |
| 7 | Aprendiz damage ×1.05, Veterano ×1.10 / ×1.03 | 56% (69 / 17) | 0.90 | 9 wipes, 53 collapses: reverted |

**Final numbers (iteration 6), against doc 04:**

| | Result | Target |
|---|---:|---:|
| Mission success | 71% | 55–70% |
| Deaths per expedition | 0.52 | 0.12–0.2 (1 per 5–8) |
| Heroes needing stress care | ~1 Quebranto/Virtud per mission; heroes come home at ~66 stress | ~1 per mission |
| Weekly money (early game) | ~3.5k in, ~3.6k out; 1.5–10k after 8 weeks | mild pressure, no snowball |
| Combat sim (300 chains) | boss cleared 97.3%, 0 stalls, top hero stress ~61 by the boss | — |

**What changed in the data:**
- `balance.json`:
  - `combat.enemy_stress_pct` 35;
  - `combat.long_fight_from` 14, `long_fight_stress` 3 (ends healer stalls);
  - `hub.heal_cost_per_hp` 20;
  - `hub.idle_stress_relief` 15 (new: a week at home without a booking).
- `progression.json`: Veterano enemies ×1.15 HP / ×1.06 damage (were ×1.22 / ×1.12); Campeón ×1.35 / ×1.15 (were ×1.46 / ×1.24).

**What the numbers say:**
- **The game is now stress-driven.** Missions fail mostly by retreat, Quebrantos show up every mission, and the Iglesia/Cantina matter.
- **Deaths stay above target.** Most come from full wipes, because a fight can't be fled (new task **P2-11**).
- **The jump from Aprendiz (91%) to Veterano (31%) is steep.** The bot reaches Veterano because seasoned heroes refuse easy runs, so parties of mixed level go out.
- **The system has strong feedback loops.** A 5–10% change in enemy damage or rewards swings success by 15–30 points, so retune in small steps and measure 48+ expeditions.
