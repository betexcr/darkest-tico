# Implementation notes (runtime tuning)

## Luz / Oscuridad (P1-17)

- **Decay:** each move between rooms lowers `mission_light` by the region's `light_decay_per_move` (8 in Sótanos and Bosque since 2026-11-12; it was 5, which never got below 40 on a Sótanos map). Town events can change it (`light_decay_pct`).
- **Tiers:** `data/balance.json` `light.tiers` (Radiante, Tenue, Penumbra, Oscuro, Negro), read by `scripts/domain/light_system.gd`. They change enemy damage and crit, hero stress taken, loot, surprise and trap disarming. Walking in Oscuro or Negro adds stress per move. Table and rules: [01-core-systems-spec.md](01-core-systems-spec.md) §4.5.
- **Apagar la candela:** an explore button, −25 Luz (`light.snuff`).
- The old region fields `low_light_threshold` / `low_light_stress` are gone. "Low light" now means Penumbra or darker.

## Combat sim (P1-07)

`tools/sim_combat.gd` plays thousands of fights headless and prints markdown tables. It runs the real `combat_controller.gd` (`instant = true`, stub stage units), so it always follows the current rules and `data/*.json`. There is no second copy of the combat math.

```
godot --headless --path . -s tools/sim_combat.gd -- --runs 10000                 # each room kind, fresh party
godot --headless --path . -s tools/sim_combat.gd -- --runs 10000 --chain 3       # 3 fights + elite + boss, no recovery
godot --headless --path . -s tools/sim_combat.gd -- --set combat.hit_base=0.8    # try a balance.json value
```

Other options: `--policy smart|basic`, `--node combat|elite|boss`, `--difficulty`, `--seed`, `--log` (prints the first fight).

What the sim leaves out:

- The heroes are the four starting classes at level 0 with starting gear, in formation order.
- Squads are drawn and scaled the way the map generator and `GameState` do it.
- Heroes never use items, camp or retreat.
- Chains skip traps, curios, light and hunger. For whole expeditions use the mission mode below.

### Mission success (P1-15)

`--chain` measures fights only. Mission success comes from the campaign bot instead, which plays real expeditions through the expedition screen: the region's provision kit, hunger, light, traps, curios, the camp, healing and stress items, retreats and going home after a death. That way there is no second copy of the expedition rules.

```
godot --headless --path . -s tools/playtest_campaign.gd -- --missions 40                       # fresh week-1 parties, Aprendiz
godot --headless --path . -s tools/playtest_campaign.gd -- --missions 40 --difficulty veterano --start-level 3 --start-ranks 2 --start-gear 2
```

`--missions N` is `--campaigns N --weeks 1` without the per-campaign journal. Each expedition starts from a fresh campaign, and the bot does its normal week-1 hub shopping first. `--route direct`, `--set`, `--party` and `--seed` work as usual. The summary starts with **Mission success** (with a 95% Wilson interval) against doc 06's 55–70% target, then how the other expeditions ended: after a Retirada, after a death, from the map, or wiped / stuck.

Results, Sótanos, route full, seed 1, 40 expeditions each (2026-11-23, after P3-05e):

| Setup | Mission success | Not cleared | Deaths / exp. | Boss won | Time |
|---|---:|---|---:|---:|---:|
| Aprendiz, fresh week-1 party | **95%** (CI 83–99%) | 2 after a Retirada | 0.03 | 95% | 450 s |
| Veterano, level 3, rank 2, 2 gear | **88%** (CI 74–95%) | 5 after a Retirada | 0.07 | 92% | 563 s |

P5-12 (2026-11-24): the owner's target is per tier (Aprendiz 85–90%, Veterano 70–80%, Campeón 55–70%), each measured as it was tuned (Aprendiz on fresh 8-week campaigns: 89.9%; Veterano and Campeón on 24-week campaigns, 12 seeds), so `--missions` (week-1 parties only: Aprendiz 97.5% on 80) reads high and is not the band's measurement. The summary line still prints doc 06's 55–70%. Earlier note: both are above the 55–70% target. The bot is a careful player (it full-clears, camps every time, uses items and retreats early), so a real player will do worse, but the gap is wide. Regular and elite fights are almost never lost; the risk is all in the boss (7–9 rounds on average, the longest 15–16).

The two hero policies:

- **smart:** heals the worst-hurt ally below 40% PV (or Al Borde) and calms anyone at 50+ stress. In round 1 it opens with a self or party buff. Otherwise it uses the attack with the best expected damage, preferring kills and then the weakest enemy in reach.
- **basic:** uses the first usable attack on the front enemy, every turn. It never heals. It plays about like the smoke bot.

A fair player sits between the two.

### Results — Sótanos, Aprendiz, seed 1, 10,000 fights per row (2026-11-12)

The columns are averages per fight:

- **Party stress +** is the stress the four heroes gained together.
- **Top stress** is the highest hero stress when the fight ends.
- **Al Borde** counts heroes who fell Al Borde during the fight.
- **PV lost** is the share of the party's total PV lost in the fight.

Fresh party for every fight:

| Room | Policy | Win % | Rounds | Party stress + | Top stress | Deaths | Fights with a death | Al Borde | PV lost |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Combat (1–3 enemies) | smart | 100.0 | 3.7 | 22.5 | 10.9 | 0.00 | 0.1% | 0.01 | 16% |
| Elite + escorts | smart | 100.0 | 4.4 | 28.9 | 13.0 | 0.00 | 0.1% | 0.02 | 20% |
| Boss + 2 Sirvientes | smart | 100.0 | 6.0 | 33.2 | 15.2 | 0.00 | 0.0% | 0.03 | 25% |
| Combat (1–3 enemies) | basic | 99.9 | 4.3 | 34.8 | 15.7 | 0.02 | 2.0% | 0.07 | 23% |
| Elite + escorts | basic | 99.9 | 5.4 | 47.7 | 20.4 | 0.07 | 5.9% | 0.20 | 33% |
| Boss + 2 Sirvientes | basic | 98.2 | 8.2 | 54.8 | 25.6 | 0.45 | 34.3% | 0.97 | 58% |

By the room's enemy, smart policy (the rest of the squad is random):

| Room enemy | Rounds | Party stress + | PV lost | Fights with a death (basic) |
|---|---:|---:|---:|---:|
| Duende del sótano | 3.8 | 20.0 | 13% | 1.6% |
| Espanto | 3.7 | 30.1 | 17% | 1.9% |
| Mandador en pena | 3.8 | 28.5 | 18% | 4.2% |
| Monaguillo del portón | 3.5 | 21.0 | 16% | 0.8% |
| Murciélago de bodega | 3.6 | 18.8 | 15% | 0.7% |
| Peón penado | 3.9 | 21.8 | 17% | 3.6% |
| Rata de troje | 3.4 | 15.9 | 15% | 1.6% |
| Susurro del aljibe | 3.6 | 24.1 | 13% | 0.5% |
| Vigía del portón | 3.7 | 21.7 | 22% | 3.2% |
| Cadejo negro (elite) | 4.4 | 39.5 | 22% | 6.4% |
| Sombra de cuadrilla (elite) | 4.4 | 18.4 | 19% | 5.5% |

Chains of 3 fights, then the elite, then the boss. PV, stress, deaths and Al Borde rolls carry over, with nothing healed between fights:

| Policy | Fight 1 | Fight 2 | Fight 3 | Elite | Boss | **Boss cleared** | Top stress before the boss |
|---|---:|---:|---:|---:|---:|---:|---:|
| smart (win %) | 100.0 | 100.0 | 100.0 | 99.9 | 99.8 | **99.8%** | 23.7 |
| basic (win %) | 100.0 | 98.0 | 88.8 | 62.8 | 5.1 | **2.8%** | 54.9 |

### What the numbers say

- **Combat alone is easy for a careful player.** Smart play loses about 1 fight in 5,000 and clears 99.8% of the chains. The roadmap's mission target is 55–70% (doc 06). Traps, light, hunger and curios add some risk, but items and the camp take more of it away. The combat side probably needs to be harder for P5-02.
- **Healing outpaces damage.** In smart chains the party ends fights 4–5 and later with more PV than it started with (PV lost −1% and −3%). That comes from Abuela's Sopa Milagrosa (party heal plus Sobado) and Cataplasma, with Aguante and Firewall on top. The heal amounts are the first lever to try.
- **Stress is too low to matter.** In every smart row (about 80,000 fights), Quebrantos and Virtudes average 0.00 per fight. That means fewer than 1 fight in 200 reaches the resolve check at 100 (doc 01 §3.2). The top hero ends a full smart chain at about 28 stress, and at 61 even under basic play. Combat stress alone never brings a hero near the check in one expedition.
- **Without healing, attrition is real.** The basic chain falls from 100% to 2.8%. The boss is the wall: 34% of fresh basic fights at the boss already lose a hero. So difficulty depends on healing and target choice, not on single fights.
- **Outliers:**
  - Cadejo negro gives the most stress, about twice the other elite (39.5 vs 18.4).
  - Vigía del portón and Mandador en pena cost the most PV and deaths among normal enemies.
  - Rata de troje is the softest.
- **Stalls:** 5 smart chains (0.05%) went past 40 rounds, likely healers out-healing a weak last enemy. Not seen with fresh parties.

### Rerun after the Luz tiers (2026-11-12, P1-17)

`--light N` plays every fight at a fixed Luz; without it, fights use the region's starting Luz (100 = Radiante). At full light the results match the tables above within noise, so the shared damage rule (P1-16) didn't change combat.

Chains of 3 fights + elite + boss (5,000 per row):

| Policy | Luz | Boss cleared | Top stress before the boss | Party stress + in fight 1 | Fights with a death (elite / boss) |
|---|---|---:|---:|---:|---:|
| smart | 100 Radiante | 99.8% | 23.9 | 22.9 | 1.1% / 2.1% |
| smart | 40 Penumbra | 99.8% | 27.5 | 25.5 | 1.5% / 2.1% |
| smart | 0 Negro | 99.0% | 36.6 | 33.9 | 2.9% / 4.6% |
| basic | 100 Radiante | 3.1% | 54.6 | 34.9 | 66% / 99% |
| basic | 0 Negro | 0.9% | 75.6 | 52.2 | 78% / 99.5% |

- In the dark, stress per fight is about 50% higher and deaths roughly triple. It now matters to carry candles, which is the point of the tiers.
- Smart play still clears 99% even in Negro. Combat difficulty is still P5-02's job; the Luz tiers are a multiplier on it, not a fix.
- Travel hunger, trap damage and curio curses are not in the sim (P1-15).

With hero accuracy in the dark (owner 2026-11-12: Penumbra −3, Oscuro −6, Negro −10), chains of 3 fights + elite + boss, 5,000 per row:

| Policy | Luz | Boss cleared | Rounds in the boss fight | Top stress before the boss | Fights with a death (elite / boss) |
|---|---|---:|---:|---:|---:|
| smart | 40 Penumbra | 99.6% | 8.3 | 30.9 | 1.4% / 2.5% |
| smart | 0 Negro | 96.9% | 11.6 | 43.8 | 4.3% / 7.3% |
| basic | 0 Negro | 0.0% | 5.0 | 96.8 | 90% / 100% |

- Missing more makes fights longer (boss 7.4 → 11.6 rounds in Negro), so stress and deaths climb. Careful play now actually loses runs in the dark.
- 45 smart chains in Negro stalled past 40 rounds (0.9%): healers out-heal what a blind party can hit. Watch for this in P5-02.

### Rerun with dragging-fight stress (2026-11-14, P5-02b)

`--party a,b,c,d` plays another class mix; `--bring id,id` (P3-17) has each hero bring the listed skills of its class in place of its last slots; `--log-long N` prints the first fight that passes N rounds, which is how the stall below was found. Chains of 3 fights + elite + boss, 10,000 per row, smart policy, Aprendiz:

| Party | Dragging stress | Boss cleared | Rounds in the boss fight | Top stress after the boss | Chains past 40 rounds |
|---|---|---:|---:|---:|---:|
| Starting party | off | 99.8% | 7.4 | 28.3 | 5 |
| Starting party | on | 99.2% | 7.3 | 31.2 | 0 |
| 3 Abuelas + Curandero | on | 97.6% | 12.7 | 70.9 | 0 |
| 3 Campesinos + Abuela | on | 89.2% | 12.5 | 68.0 | 0 |

- The rule costs the starting party almost nothing, because its fights last 4–7 rounds. Slow parties pay for it in stress: about 70 on the top hero after the boss, against 31.
- **Why fights stalled.** The log of a 41-round boss fight showed the same loop every round: a hero collapses at 200 stress and drops to Al Borde, a companion heals them back up, and the next stress collapses them again. Nobody died and nobody attacked. A second Colapso in the same fight is now a death roll (doc 01 §3.4).
- **The smart policy changed too.** Once a fight is about to drag it stops calming, heals only a hero Al Borde or under 25% PV, and attacks. Before that it spent every turn healing and calming while one self-healing enemy was left, which is what a player would not do. With the rule off the policy plays as before.

### Rerun on the P5-02c/f numbers (2026-11-15)

`--level N --ranks R --gear` plays a seasoned party: every hero at that resolve level, every skill at that rank, the dearest weapon and armor. Chains of 3 fights + elite + boss, 10,000 per row, smart policy:

| Party | Difficulty | Boss cleared | Rounds in the boss fight | Top stress after the boss | Boss fights with a death | Chains past 40 rounds |
|---|---|---:|---:|---:|---:|---:|
| Starting party, level 0, rank 1 | Aprendiz | 95.9% | 9.7 | 57.8 | 8.3% | 0 |
| Starting party, level 3, rank 3, weapon and armor | Veterano | 98.7% | 7.7 | 46.8 | 9.8% | 0 |
| Starting party, level 5, rank 4, weapon and armor | Campeón | 92.3% | 10.5 | 65.1 | 22.8% | 0 |
| 3 Abuelas + Curandero, level 0, rank 1 | Aprendiz | 48.2% | 17.4 | 163.1 | 49.1% | 0 |

- **Aprendiz is no longer free.** The starting party cleared 99.2% of chains before; now 95.9%, with the top hero at 58 stress, up from 31.
- **The tiers are in order for a seasoned party**, but the sim's seasoned party is better prepared than most parties that reach a tier in a campaign. In the campaign playtest Veterano on the full route was cleared 64% of the time (doc 09 §6). Use the sim to compare settings, not to predict the clear rate.
- **Damage alone does little.** Raising enemy damage from ×1.25 to ×1.35 on Aprendiz moved the chain clear rate by under a point, because healing absorbs it. Enemy PV (longer fights, so more stress and more dragging) and smaller heals move it more.
- **A healer-only party now loses most chains.** It can't kill fast enough, so the dragging stress gets it. That is the stall penalty doing its job.



## Sound effects (P4-04a, 2026-11-24)

- `Sfx` autoload (`scripts/autoload/sfx.gd`): `Sfx.play(id)` picks one of the id's files at random, pitch 1 ± `pitch_jitter`, on a pool of 10 players. The same id within 45 ms is skipped, so six enemies hit at once sound like one hit. Unknown ids and missing files are silent.
- Data: `data/sfx.json` (50 ids, 109 files). It is generated: `python3 tools/import_sfx.py <packs_dir>` converts the chosen files of five CC0 OpenGameArt packs (artisticdude, Kenney ×2, rubberduck ×2) to mono OGG with a `.metadata.json` each. Credits: `assets/audio/CREDITS.md`. On a fresh checkout (no `*.import`) the OGGs are read straight from disk.
- Buses Master > SFX, UI, Music, Voice (Music and Voice are empty until P4-04b/c). The speaker button in the hub banner and the expedition top bar opens the "Sonido" card: one "Efectos" slider for SFX and UI, and "Silenciar". It is kept in `user://settings.cfg` (`[audio] sfx_volume, sfx_muted`), not in the save; `-s` runs never touch it.
- Where sounds play: every `BaseButton` (click, "no" on a disabled one; hovering is silent and the "Cuadrilla" checkbox is silent, owner 2026-11-25); combat in `battle_unit.gd` (swing or cast, hit or crit, enemy cry, heal or relief, deaths) and `combat_controller.gd` `_sfx` (miss, guard, statuses, stress, Al Borde, Quebranto/Virtud, retreat, victory/defeat, ambush/boss roar; silent with `instant`); expedition (footsteps, door, trap, disarm, curio, camp, eating, candle, loot, items); hub through `_act(sound, call)`, which plays the action's sound only if the hacienda changed, else "no" (buy, sell, equip, upgrades, skills, hires, Clínica, EBAIS), plus building open/close and the new week.
