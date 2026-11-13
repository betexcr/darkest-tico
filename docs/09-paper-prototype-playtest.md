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
