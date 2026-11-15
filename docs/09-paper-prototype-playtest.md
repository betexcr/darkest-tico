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

## 6) Baseline for the balance pass — 2026-11-14, a bot that spends (P5-02a)

**Why a new baseline.** The bot in §5 bought one skill rank a week and no equipment, so its "colones grow to 21–41k" said little about the game. The bot now spends like a player: it buys every skill rank and one piece of equipment per hero a week (cheapest first), carries a café for a tense hero, and takes at most one dedicated healer. `tools/playtest_campaign.gd` also has `--set path=value` and `--party id,id,id,id`. No game data changed.

**Runs.** 3 campaigns × 16 weeks on each route (96 expeditions), seed 1. Raw output: [playtests/2026-11-14-baseline-full.md](playtests/2026-11-14-baseline-full.md) and [playtests/2026-11-14-baseline-direct.md](playtests/2026-11-14-baseline-direct.md). Every task of the balance pass (P5-02b–f) compares with these.

| | Full route | Direct route |
|---|---:|---:|
| Expeditions cleared | 47 / 48 | 46 / 48 |
| Cleared on Aprendiz / Veterano / Campeón | 100% / 100% / 95% | 100% / 100% / 92% |
| Expeditions on Aprendiz / Veterano / Campeón | 15 / 13 / 20 | 13 / 10 / 25 |
| First week on Veterano / Campeón | 5 / 8 | 5–6 / 8–9 |
| Heroes lost per expedition | 0.15 | 0.21 |
| Stress leaving the hub / coming back (party average) | 20 / 24 | 11 / 14 |
| Top hero's stress at the end | 39 | 28 |
| Expeditions with a resolve check | 3 of 48 | 2 of 48 |
| Hunger stops (short of food) | 109 (56, in 35 expeditions) | 8 (0) |
| Avg rounds: normal / elite / boss | 4.2 / 4.8 / 10.1 | 4.2 / 5.2 / 7.6 |
| Boss fights over 8 rounds (longest) | 19 of 47 (58) | 8 of 47 (51) |
| Loot per week | 6,953 ₡ | 5,622 ₡ |
| Hub spending per week | 6,692 ₡ (96% of loot) | 5,391 ₡ (96% of loot) |
| Of it: skill ranks / equipment / provisions | 58% / 15% / 14% | 65% / 16% / 7% |
| Colones after week 8 | 6.9–10.7k | 7.6–9.9k |
| Colones after week 16 | 5.2–11.9k | 5.2–10.9k |

### What changed from §5

- **The economy is not loose when the player buys upgrades.** Skill ranks and equipment take 96% of the loot, and the bank stays at 5–12k through week 16. That is already inside the P5-02f target (8–15k after week 8). What remains for P5-02f:
  - The Iglesia and stress items get almost no colones (0–3% of spending), because stress is low.
  - Skill ranks end. A party's 16 skills cost 86,400 ₡ to max, about 25 weeks at this rate; after that the money has nowhere to go until the Taller and the Clínica exist (P3-05, P3-06).
- **The upgrades make the game easier still.** Deaths per expedition are about the same as in §5, with twice as many Campeón expeditions.

### What stayed

- **Too easy.** 93 of 96 cleared; Aprendiz and Veterano never lost. The owner's bands are 85–90% / 70–80% / 55–70%.
- **Stress is held under 50 for free.** The top hero ends at 45–49 in 19 of 96 expeditions and above 50 in only 8. The bot calms anyone who reaches 50 with a skill that costs nothing (*No Me Tumban* is 30–34% of the Montador's turns, *Regaño Santo* 12–26% of the Abuela's), so stress never climbs from there. A resolve check came up in 5 of 96 expeditions.
- **Levelling is fast.** Veterano in week 5, Campeón in week 8, every campaign.
- **Full exploration runs short of food.** 51% of hunger stops on the full route, in 35 of 48 expeditions.
- **Stalls are not only a healer problem.** The two longest fights (51 and 58 rounds, both against the boss on Campeón) had one Abuela with two or three Campesinos, who heal with *Aguante de Campo*. One of them ended in a wipe. Bosses pass 8 rounds in 27 of 94 fights.

### After dragging-fight stress (P5-02b)

Same runs with the rule on (doc 01 §3.1) and a bot that plays to finish once a fight drags. Raw output: [playtests/2026-11-14-drag-full.md](playtests/2026-11-14-drag-full.md) and [playtests/2026-11-14-drag-direct.md](playtests/2026-11-14-drag-direct.md).

| | Full: before | Full: after | Direct: before | Direct: after |
|---|---:|---:|---:|---:|
| Expeditions cleared | 47 / 48 | 48 / 48 | 46 / 48 | 48 / 48 |
| Avg rounds against the boss | 10.1 | 6.8 | 7.6 | 7.5 |
| Boss fights over 8 rounds | 19 of 47 | 5 of 48 | 8 of 47 | 13 of 48 |
| Longest fight | 58 | 23 | 51 | 17 |
| Heroes lost per expedition | 0.15 | 0.06 | 0.21 | 0.00 |
| Stress coming back (party average) | 24 | 20 | 14 | 18 |

- **The stalls are gone.** No fight passed 23 rounds. With the two stall-prone parties forced for 16 weeks (`--party campesino,campesino,campesino,abuela` and `--party abuela,abuela,abuela,curandero`, direct route), the longest fights were 13 and 12 rounds, and all 96 expeditions were cleared.
- **The game got easier for the bot, not harder.** Both losses in the baseline were stalled boss fights. Finishing a fight is simply better play than healing through it, so the clear rate is now 96 of 96. Difficulty is the job of P5-02c and P5-02f.
- **The first try failed, and why.** With the rule on and the old bot, a level-1 party was wiped in a 22-round normal fight: the bot kept healing and calming while the dragging stress piled up. A player who doesn't attack in a dragging fight will lose it. That is the rule working, and the log warns one round ahead.

### After the XP curve and the provision kits (P5-02d, P5-02e)

3 campaigns × 24 weeks per route (144 expeditions), so that Campeón is reached on the longer curve. Raw output: [playtests/2026-11-15-xp-kits-full.md](playtests/2026-11-15-xp-kits-full.md) and [playtests/2026-11-15-xp-kits-direct.md](playtests/2026-11-15-xp-kits-direct.md). The bot buys the full-exploration kit on the full route and the short kit on the direct one. "Before" is the P5-02b run above.

| | Full: before | Full: after | Direct: before | Direct: after |
|---|---:|---:|---:|---:|
| First week on Veterano | 5–6 | 7–9 | 5 | 8 |
| First week on Campeón | 8–11 | 15–17 | 8 | 16 |
| Hunger stops short of food | 50 of 103 (49%) | 3 of 152 (2%) | 0 of 10 | 0 of 13 |
| Expeditions cleared | 48 / 48 | 72 / 72 | 48 / 48 | 72 / 72 |
| Heroes lost per expedition | 0.06 | 0.03 | 0.00 | 0.00 |
| Stress coming back (party average) | 20 | 12 | 18 | 16 |
| Top hero's stress at the end | 31 | 22 | 33 | 28 |
| Provisions per week | about 930 ₡ | 1,190 ₡ | about 390 ₡ | 365 ₡ |
| Colones after week 8 | 7.3–10.3k | 4.1–7.1k | 7.8–10.0k | 4.6–6.0k |
| Colones after week 24 | — | 10.9–15.8k | — | 8.4–10.1k |

- **Levelling takes about twice as long.** Veterano comes in week 7–9 and Campeón in week 15–17. The spread is the bot resting a hero some weeks; a party that never changes reaches them in weeks 7 and 15.
- **Full exploration is fed.** With 16 gallo pinto the party runs short in 3 expeditions of 72. The kit costs about 260 ₡ a week more than the bot used to spend.
- **Without hunger the full route is calm too.** Stress back at the hub fell from 20 to 12. Most of the full route's stress in the baseline was hunger, not fights.
- **The bank is lower early.** Heroes spend more weeks on Aprendiz pay, so week 8 ends at 4–7k, down from 7–10k. Skill ranks still take about 60% of the spending.
- **Nothing is lost any more: 144 of 144.** Three bot fixes made in these two tasks account for that, and none of them changes the game:
  - A hero pushed out of position steps back to where an attack works. Before, the bot used support skills from the wrong place for the rest of the fight.
  - The bot picks the difficulty for which it can send the fullest party of the right level.
  - It never leaves with three heroes when it can send four.
- So with careful play the game currently has no losing condition in practice. The stress pass (P5-02c) and the clear-rate tuning (P5-02f) start from here.

### Final numbers: stress, difficulty and free recruits (P5-02c, P5-02f)

**What changed in the game**

- Free stress relief is smaller: *No Me Tumban* 5 → 2, *Círculo de Tiza* and *Humo de Hierbas* 6 → 3, *Regaño Santo* 12 → 8, *Rezo de Nicoya* 3 → 2.
- *Sopa Milagrosa* heals 1–3 (was 2–4).
- Enemies per difficulty, PV / damage / stress: Aprendiz ×1.1 / ×1.2 / ×1.5, Veterano ×1.75 / ×1.6 / ×2, Campeón ×2.4 / ×2 / ×2.25 (doc 01 §6.1).
- **Recruits are free** (owner 2026-11-15, as in Darkest Dungeon).

**Result.** 3 campaigns × 24 weeks per route, the same as the reference above. Raw output: [playtests/2026-11-15-final-full.md](playtests/2026-11-15-final-full.md) and [playtests/2026-11-15-final-direct.md](playtests/2026-11-15-final-direct.md).

| | Full: reference | Full: final | Direct: reference | Direct: final |
|---|---:|---:|---:|---:|
| Expeditions cleared | 72 / 72 | 60 / 72 | 72 / 72 | 68 / 72 |
| Cleared on Aprendiz | 100% | 88% (51 of 58) | 100% | 95% (37 of 39) |
| Cleared on Veterano | 100% | 64% (9 of 14) | 100% | 96% (27 of 28) |
| Cleared on Campeón | 100% | not reached | 100% | 80% (4 of 5) |
| Heroes lost per expedition | 0.03 | 0.76 | 0.00 | 0.25 |
| Stress coming back (party average) | 12 | 38 | 16 | 28 |
| Top hero's stress at the end | 22 | 83 | 28 | 55 |
| Expeditions where someone reached 100 stress | 0 | 26 | 1 | 9 |
| Avg rounds against the boss (longest fight) | 6.3 (12) | 11.2 (25) | 5.7 (20) | 8.3 (24) |
| Loot per week | 6,587 ₡ | 3,900 ₡ | 5,217 ₡ | 3,885 ₡ |
| Hub spending, share of loot | 95% | 100% | 97% | 101% |
| Iglesia and stress items, share of spending | 0% | 12% | 1% | 7% |
| Colones after week 8 | 4.1–7.1k | 4.2–8.0k | 4.6–6.0k | 4.6–7.6k |
| Colones after week 24 | 10.9–15.8k | 4.2–4.5k | 8.4–10.1k | 4.0–5.2k |
| Campaigns still solvent in week 24 | 3 of 3 | 3 of 3 | 3 of 3 | 3 of 3 |

Against the owner's targets:

| Target | Measured (both routes together) |
|---|---|
| Aprendiz cleared 85–90% | 91% (88 of 97) |
| Veterano cleared 70–80% | 86% (36 of 42); 64% on the full route, 96% on the direct one |
| Campeón cleared 55–70% | 4 of 5: too few to say |
| Stress back at the hub 30–50 | 38 full, 28 direct |
| A resolve check in about 1 of 3 expeditions | 26 of 72 full, 9 of 72 direct |
| Top hero's stress at the end 60–80 | 83 full, 55 direct |

**What the tuning showed** (about 60 campaign runs on copies of the project; only the final pair is saved in `docs/playtests/`)

- **The first six weeks are still never lost.** A fresh campaign cleared 36 of 36 Aprendiz expeditions in weeks 1–6 with no deaths. The Aprendiz losses come later, from parties rebuilt out of whoever was at the terminal after a wipe on Veterano. A rebuilt party has no ranks, little equipment and often a poor class mix.
- **The full route is much more sensitive than the direct one.** The same numbers give Veterano 64% on the full route and 96% on the direct one. More fights and more moves mean more stress, and stress is what kills.
- **Clear rate and hero deaths pull against each other.** The bot retreats only after two heroes are down, so nearly all its failures are wipes. On Veterano's full route a 64% clear rate already costs 1.5 heroes per expedition; doc 04 §4 asks for one death every 5–8 missions. Pushing Veterano and Campeón down to the bottom of their bands this way would cost several heroes per expedition.
- **Paid recruits made a wipe unrecoverable.** With recruits at 700–900 ₡, a wiped party cost about 3,000 ₡ on top of its ranks and equipment. At these same Aprendiz numbers every full-route campaign (9 of 9) went bankrupt between weeks 5 and 21. With free recruits all 12 campaigns are solvent in week 24.
- **Tiers have to grow with the party.** A prepared party (started at the tier with `--start-level`) cleared Veterano 54 of 54 at ×1.75 PV / ×1.6 damage and Campeón 58 of 58 at ×2.2 / ×1.9. Skill ranks roughly double a party's healing and damage. Parties that reach a tier in a real campaign are poorer than that, which is why the same Veterano numbers give 64% on the full route.
- **Results are noisy.** One early wipe changes a whole campaign, so failures cluster. Three campaigns per route separate "fine" from "broken", not 85% from 90%.

**Still open**

- Campeón has almost no data: on the full route no campaign got there in 24 weeks, because Veterano wipes send the roster back to Aprendiz.
- The economy is now tight (the bank sits at 4–8k) where I had planned for 8–15k after week 8. Loot per week fell from 5,200–6,600 ₡ to about 3,900 ₡, because most weeks are now played on Aprendiz pay. Skill ranks take 22–44% of spending, down from about 60%.
- The bot, the sim and these targets all measure a careful player. How it feels needs the owner.

