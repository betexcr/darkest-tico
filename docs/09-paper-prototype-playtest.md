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

### With retreat from a fight (P5-04, P5-05)

Owner 2026-11-15: failing should be cheaper than dying. The game now has "Retirada" in a fight (doc 01 §5.3), and the bot uses it: it leaves a fight when a hero has died in it, when two heroes are Al Borde, or when the fight drags with someone at 150+ stress; then it goes home. On the map it goes home after one death. No game numbers changed. Raw output: [playtests/2026-11-15-retreat-full.md](playtests/2026-11-15-retreat-full.md) and [playtests/2026-11-15-retreat-direct.md](playtests/2026-11-15-retreat-direct.md).

| | Full: final | Full: with retreat | Direct: final | Direct: with retreat |
|---|---:|---:|---:|---:|
| Expeditions cleared | 60 / 72 | 28 / 72 | 68 / 72 | 64 / 72 |
| Cleared on Aprendiz | 88% | 39% (21 of 54) | 95% | 94% (33 of 35) |
| Cleared on Veterano | 64% | 39% (7 of 18) | 96% | 96% (25 of 26) |
| Cleared on Campeón | not reached | not reached | 80% (4 of 5) | 55% (6 of 11) |
| Heroes lost per expedition | 0.76 | 0.18 | 0.25 | 0.06 |
| Expeditions abandoned | 1 | 44 | 0 | 8 |
| Stress leaving the hub / coming back | 29 / 38 | 84 / 98 | 25 / 28 | 33 / 38 |
| Loot kept on an abandoned expedition | — | 1,010 ₡ | — | 1,955 ₡ |

- **Deaths fall to about a quarter on both routes.** That was the point.
- **The direct route is close to the owner's bands**: Aprendiz 94%, Veterano 96%, Campeón 55%, with a hero lost every 17 expeditions.
- **The full route turns into a stress spiral.** A retreat costs stress and brings no relief, and the Iglesia takes off 10 per misa. Parties leave the hub at 84 stress, reach 150 in the next long fight and retreat again. Nobody dies; nothing gets done either.
- **A stronger Iglesia did not settle it.** I tried 20 and 30 stress per misa (same 800 ₡, the bot paying for up to three). Full-route Aprendiz went from 39% to 29% and 60%; on the direct route, where the change should only help, Veterano went from 96% to 76% and 68%. Those swings are larger than the effect I was looking for, so I left the Iglesia at 10.
- **What that says about the method.** Three campaigns per route can't measure a change of 10–15 points: one bad week sets off a run of failures in that campaign. Tuning Veterano and Campeón further (P5-06) needs about ten campaigns per setting, and the full route needs real stress relief at the hacienda first (P3-03, Iglesia and Cantina).

## 7) Parallel balance pass — 2026-11-17 (superseded by the merge)

> Made on `claude/p3-03-followup-48gkar` without knowing about the P5-02a–f work in §6, with a campaign bot that never bought gear. On 2026-11-17 the branches were merged and §6's numbers won; only `hub.idle_stress_relief` and the bot's Iglesia/Cantina bookings were kept. Kept here for the record.

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

## 8) Rebalance after the merge (P5-07) — 2026-11-19

The merged game (no group misa) cleared 26% of 144 bot expeditions, all failures retreats, with money draining. Aprendiz now uses the plain enemy numbers (`enemy_hp` 1.0, `enemy_dmg` 1.0) and `enemy_stress` 1.15; the EBAIS costs 12 ₡ per PV and a week at home takes 20 stress off. Result over 6 seeds: 58% cleared, 0.19 deaths per expedition, money in 2946 / out 3118 a week, broke weeks 31 → 7 of 144. Numbers and method: [playtests/2026-11-19-p5-07.md](playtests/2026-11-19-p5-07.md).

**P5-08, same day: all three tiers to the owner's bands.** P5-07 had aimed Aprendiz at 55–70%; the owner's bands are per tier (85–90 / 70–80 / 55–70). Enemy PV / damage / stress now: Aprendiz ×0.8 / ×0.8 / ×0.95, Veterano ×1.5 / ×1.4 / ×1.7, Campeón ×2.0 / ×1.7 / ×2.0. Cleared: Aprendiz 91% (fresh campaigns), Veterano 80% and Campeón 63% (tier-start runs); deaths 0.05–0.18 per expedition. Parties that reach Veterano inside an 8-week campaign still struggle there (7 of 22). Details: [playtests/2026-11-19-p5-08.md](playtests/2026-11-19-p5-08.md).

**P5-09, same day: 24-week campaigns.** P5-08 measured Veterano and Campeón with parties started at the tier. In real 24-week campaigns a party that has just moved up (forced: level-3 heroes refuse Aprendiz) cleared Veterano 30% and spiralled back down. Veterano is now ×1.15 / ×1.1 / ×1.3 and Campeón ×1.6 / ×1.4 / ×1.65. 18 campaigns × 24 weeks: 69% cleared overall, Veterano 70%, Campeón 63% (7 of 18 campaigns got there), 0.14 deaths per expedition, money in 4544 / out 4448 a week. Details: [playtests/2026-11-19-p5-09.md](playtests/2026-11-19-p5-09.md).

**P5-06, 2026-11-20: after enemy drops (P5-10).** Same 18 × 24-week setup, game data unchanged. Drops didn't move the tiers: Veterano 74%, Campeón 60% (20 expeditions; noisy). Two bot fixes: Iglesia/Cantina weeks booked before the party is picked were reported as hires (relief is really about 27% of spending), and broke campaigns no longer send heroes at 150+ stress out to retreat from the first fight every week (they rest at home; free recruits go). With the fixes: 72% overall, Veterano 72%, Campeón 74% (19), 0.11 deaths per expedition, weeks under 500 ₡ 19 → 9. The week-24 bank is in 4–8k for 7 of 18 campaigns (median 2.7k): money in ≈ out and the bot spends to its reserve, so the owner dropped that band (2026-11-20): the week-24 target is solvent (≥ 500 ₡), 17 of 18. Details: [playtests/2026-11-20-p5-06.md](playtests/2026-11-20-p5-06.md).

**P3-14/16/18/21, 2026-11-20: building upgrades, Reliquias, tiered prices.** Same 18 × 24-week setup, enemy numbers unchanged. The bot buys Maestría (when a hero is capped) and Plan de Formación before ranks, other upgrades with what ranks and gear leave. Upgrade colones prices were halved so Reliquias are the limit. Result: 74% overall, Veterano 86% (above its band), Campeón 49% on 39 expeditions (below), 0.12 deaths, every campaign solvent in week 24, 15 of 24 upgrade levels bought (median). Retuning Veterano/Campeón for the upgraded game is P5-11. Details: [playtests/2026-11-20-p3-upgrades.md](playtests/2026-11-20-p3-upgrades.md).

**P5-11, 2026-11-21: Veterano / Campeón after the upgrades and the Feria.** 12 seeds × 3 campaigns × 24 weeks per setting (6 seeds proved too few: the unchanged data cleared Campeón 67% on seeds 1–6 and 81% on seeds 7–12). With upgrades and the Feria both tiers were too easy (Veterano 82%, Campeón 76%), and the tiers are coupled through money: a harder Veterano leaves parties poorer and weaker when they reach Campeón. Kept: Veterano enemies ×1.18 HP / ×1.13 damage (were ×1.15 / ×1.1), Campeón ×1.65 / ×1.44 (were ×1.6 / ×1.4). Result: Veterano 77%, Campeón 65% on 63 expeditions, 0.15 deaths per expedition, 34 of 36 campaigns with money at week 24. Details: [playtests/2026-11-21-p5-11.md](playtests/2026-11-21-p5-11.md).
