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
- Chains skip traps, curios, light and hunger.

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
