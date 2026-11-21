# Hacienda Hub Design (One-to-One Mirror)

This spec mirrors core Darkest Dungeon town systems with Costa Rican theming and matching strategic function.

## 1) Hub Structure

- Hub name: `Hacienda del Abuelo`.
- Time unit: 1 week per completed/failed expedition.
- Weekly updates:
  - Recruit pool refresh
  - Market rotation
  - Town events
  - Recovery and treatment resolution

### Town view (P4-17, owner 2026-11-17)

The hub is drawn as a painted town, like the Darkest Dungeon hamlet: one painting of the whole village at night (`assets/town/town_painted.png`, P4-19), made by laying out the buildings from `data/town.json` (cut-outs from `tools/sd_cutout.py`, plus unclickable `filler` houses) and repainting the layout as one scene with `tools/town_paint.py`. Each building is its own crop of that painting, so it can light up on hover.

- **Hover:** the building gets a warm outline and its name plate.
- **Click:** opens that building's window (Esc or "Volver al pueblo" closes it).
- **Closed buildings:** a building closed by the week's town event (`closed_by`) is drawn grey. Partial closures, like the Pulpería not buying, go on the plate (`note_by`).
- **Roster:** on the right, with the alforja under it.
- **Bottom bar:** colones, region, difficulty, Pura Vida and "Salir de expedición".
- **Top-left banner:** the week and the town event.

| Building | Window |
|---|---|
| Pulpería | consumables shop (buy; sell consumables back with sell mode or by dropping them) |
| Terminal de Buses | the week's candidates |
| Iglesia Vieja / Cantina del Centro | the selected hero's week of rest |
| Clínica de Espantos | every hero, with a button to their quirk card |
| Casa Comunal | the selected hero's skill ranks |
| Taller de Herrería y Carretas | the selected hero's equipment slots (drag from the alforja) and the weapon and armor shop, with a filter; buys used weapons and armor back (P4-18; accessories moved to the Feria in P3-05a) |
| Feria Nocturna | this week's accessories (one of each, rerolled weekly), the same equipment slots, and buys used accessories back (P3-05a) |
| Guardabosques del Arenal | the selected hero's camp skills: learn, fix one, swap a shared one (§9) |

The EBAIS stays a button on each roster row. Mejoras de Hacienda has no picture (its rows are on each building's page). The Feria Nocturna (P3-05a) stands at the right of the plaza with a stand-in cut from the *Feria de artesanía* event picture (`assets/town/feria.png`) until P3-05c paints its own and repaints the town. The Guardabosques is the shed by the Cantina, cut from the painted town; `tools/art_manifest.json` `town_guardabosques` is its own art for the next repaint.

## 2) Building Mapping

| Darkest Dungeon | Tico Gothic Equivalent | Primary Function |
|---|---|---|
| Stage Coach | Terminal de Buses de Sarchi | Recruit and roster capacity |
| Guild | Casa Comunal de Oficios | Skill unlocks and rank upgrades |
| Blacksmith | Taller de Herreria y Carretas | Weapon/armor upgrades |
| Sanitarium | Clinica de Espantos | Quirk and disease/curse treatment |
| Abbey | Iglesia Vieja | Stress healing (spiritual track) |
| Tavern | Cantina del Centro | Stress healing (vice/social track) |
| Nomad Wagon | Feria Nocturna | Trinket market |
| Survivalist | Guardabosques del Arenal | Camp skill upgrades |
| Districts | Mejoras de Hacienda | Global account bonuses |

## 3) Terminal de Buses de Sarchi (Recruitment)

**Recruits are free** (owner 2026-11-15, as in Darkest Dungeon's Stage Coach). The weekly candidates cost nothing; the roster cap is the only limit. The exception is the level-6 veteran a town event can offer for colones. Why: a wiped party used to cost about 3,000 ₡ in hires on top of its ranks and equipment, and the playtest campaigns that lost one went bankrupt (doc 09 §6).

### Upgrade Tracks

1. `Rutas Regionales` (Stage Coach Network mirror)
   - Increases weekly recruit offers.
2. `Dormitorios de Cuadrilla` (Barracks mirror)
   - Increases roster cap.
3. `Veteranos Recomendados` (Experienced Recruits mirror)
   - Chance for higher-level recruits with partial kit upgrades.

### Design Intent

- Ensure steady hero replacement due to death, stress lockout, and diseases.
- Encourage bench depth and role redundancy.

## 4) Casa Comunal de Oficios (Skill Training)

### Upgrade Tracks

1. `Maestria de Oficio`
   - Raises maximum skill rank ceiling.
2. `Plan de Formacion`
   - Reduces skill training costs.

### Rules

- Skill rank purchase gated by hero resolve level.
- Skill unlock costs scale by hero tier and skill archetype.

### Built (P3-04, 2026-11-11)

- Rank purchase is in the hub: a row for the selected hero, with ranks 1–5 gated by resolve level and doc 04 §3.3 prices. Rules are in doc 01 §6.3.
- Deferred: skill unlocks (P3-17). Every class has exactly 4 skills, all always available.

### Upgrades built (P3-16, 2026-11-20)

- *Maestría de Oficio*: the max rank starts at 3; two levels raise it to 4 and 5.
- *Plan de Formación*: three levels, -15 / -30 / -50% on rank prices (doc 04 §3.3).
- Bought with Reliquias del Abuelo + colones (§11); data in `data/upgrades.json`, rules in `scripts/domain/building_upgrades.gd`, the "Mejoras" rows at the bottom of the page.

## 5) Taller de Herreria y Carretas (Equipment)

### Upgrade Tracks

1. `Forja de Machetes` (weapon branch)
   - Improves damage and crit scaling.
2. `Chaperia de Armaduras` (armor branch)
   - Improves HP and defensive stats.
3. `Horno Eficiente` (cost branch)
   - Reduces upgrade prices.

### Rules

- Equipment ranks capped by building tier.
- Late gear tiers require infernal currency fragments.

### Built (P3-05d, 2026-11-21)

- **Weapon and armor ranks**, as Darkest Dungeon's blacksmith (doc 04 §3.4): with a hero's equipment fold open, the Taller page shows *Afilar* (weapon slot) and *Reforzar* (armor slot). Rank 1–5; each rank above 1 gives +1 daño / +1 precisión (weapon) or +3% protección / +2 PV máx. (armor) while something is worn in that slot. The rank is the hero's, so it carries over to a new weapon or armor. Rank N needs the same resolve as a skill rank N. Prices 600 / 1300 / 2200 / 3500 ₡, and rank 5 also 1 Reliquia (doc 04's "infernal fragments"). Rules `scripts/domain/gear_ranks.gd`, numbers `balance.json` `taller.*`, hero field `gear_ranks` (save v17).
- **Tracks** (`data/upgrades.json` `taller`): *Forja de Machetes* raises the weapon cap 2 → 3 / 4 / 5, *Chapería de Armaduras* the armor cap the same way (1 R + 500 ₡, 2 R + 1000 ₡, 3 R + 1600 ₡); *Horno Eficiente* takes 15 / 30% off rank prices (1 R + 400 ₡, 2 R + 800 ₡). "Reduces upgrade prices" read as the rank prices, not the building's own tracks.
- The Taller's Mejoras step aside while a hero's fold is open there (the page can't fit both). A town event closing the Taller's buying (`taller_compra`) also stops sharpening and reinforcing.

## 6) Clinica de Espantos (Trait and Disease Management)

### Upgrade Tracks

1. `Archivo de Costumbres`
   - Reduces quirk lock/removal cost.
2. `Equipo Medico-Ritual`
   - Improves disease/curse treatment efficiency.
3. `Sala de Pacientes`
   - Increases concurrent treatment slots.

### Rules

- Each hero can:
  - Remove one negative trait per week.
  - Lock or remove one positive trait per week.
- Disease/curse treatment uses separate slot pipeline.

### Built (P3-06, 2026-11-17)

- **Data:**
  - `data/quirks.json`: 8 positive, 8 negative, 3 diseases (Tico names). Each changes combat stats (`mods`, read by `StatusEffects.stat`) and may `refuse` a building.
    - *Descreído* won't go to the Iglesia.
    - *No le entra el guaro* won't go to the Cantina.
    - This is the owner's 2026-11-16 decision: refusals come with quirks.
  - Numbers in `data/balance.json` `quirks`; rules in `scripts/domain/quirks.gd`.
- **Gaining:**
  - After each expedition, every hero who went and lived rolls a positive (25%), a negative (25%) and a disease (8%).
  - Caps: 5 positive and 5 negative. At the cap, a new one replaces a random unlocked one.
  - Recruits arrive with a positive and a negative at 50% each.
  - The week report says who got what.
- **The Clínica,** for the selected hero (the button under the Iglesia/Cantina panel opens the card):
  - remove a negative quirk (1,500 / 2,100 / 2,700);
  - lock or remove a positive one (7,500 / 10,500 / 13,500);
  - cure a disease (750 / 1,050 / 1,350).
  - Prices are tiered by resolve: levels 0–2, 3–4, 5–6 (doc 04 §3.5).
  - Each hero gets one negative treatment and one positive treatment per week; diseases any time.
  - **The hero stays at the Clínica for the rest of the week** (P3-19, owner 2026-11-17): they leave the cuadrilla, can't rejoin and can't book the Iglesia/Cantina. A hero booked at the Iglesia/Cantina can't be treated, and neither can the last free hero.
- **Town events:** `closed` / `service_pct` accept `clinica`.
- **Save:** v12 (`quirks`, `clinic`).
- **Not yet:** the upgrade tracks above (with the building-upgrade system), treatment slots, "locked negative" quirks, and curio/enemy sources of diseases.

## 7) Iglesia Vieja + Cantina del Centro (Stress Relief Duality)

Each branch has 3 activities with independent slots and upgrade levels.

### Iglesia Vieja Activities

- `Meditacion`
- `Rezo`
- `Penitencia`

### Cantina del Centro Activities

- `Guaro y Conversa`
- `Juegos de Azar`
- `Noche de Fiesta`

### Upgrade Pattern (Both Buildings)

1. Increase stress recovery amount.
2. Reduce cost.
3. Increase slot count.
4. Repeat for higher tiers.

### Side Effects

- Every stress activity has a chance for a side effect:
  - Positive mood trait
  - Temporary debuff
  - Lost gold item
  - Hero unavailable for one extra week

### Built (P3-03, 2026-11-16)

- Data: `data/hub_activities.json` (costs, `relief` [min, max], `slots`, `side_chance`, weighted side effects). Rules: `scripts/domain/hub_activities.gd`; state in `GameState` (`send_to_activity`, `cancel_activity`, `_resolve_hub_activities`).
- In the hub, the selected hero can be sent to one activity (panel under "Iglesia Vieja y Cantina del Centro" in the left column). The hero pays now, takes a slot, leaves the cuadrilla and can't rejoin it. A booking can be cancelled for a full refund until the week ends.
- When the week ends (after the next expedition), the hero loses the rolled stress **and their Quebranto** (Darkest Dungeon rule), then may get one side effect:
  - `buff` / `debuff`: a camp-buff-style modifier for N fights of the hero's next expedition (*En paz*, *Fe renovada*, *Alma limpia*, *Desahogado*, *Fiestero*; *Goma*, *Rodillas peladas*).
  - `lose_colones` / `gain_colones`: the collection plate, paying the round, the chance.
  - `lose_item`: a consumable pawned at dominoes.
  - `extra_week`: busy one more week (no slot held).
  - `stress`: a bad night.
- Guards: a hero with 0 stress is refused; the last free hero can't be booked; if nobody is left free at week end (the lone free hero died), busy heroes come back early.
- Town events: `closed` / `service_pct` accept `cantina` as well as `iglesia`; `relief_pct` scales Iglesia activities only.
- Owner decisions (2026-11-16):
  - The old group "misa rápida" (−10 stress to everyone, nobody busy) is **removed**. It beat every activity on price and cost no week, so nobody would book one. A group blessing, if wanted, comes back only as a one-off town-event offer (`offer.all_stress`).
  - Activities **cure the Quebranto** (Darkest Dungeon rule). This is the main way to clear one.
  - **No refusals by Quebranto.** Restrictions on which activity a hero will take come with quirks (P3-06), as in Darkest Dungeon.
- Upgrades (P3-18, 2026-11-20): each building has three tracks that apply to all three of its activities (the per-activity tracks above would be 18 rows; one set per building keeps the page readable): more relief (+10 / +20 / +30%), cheaper (-10 / -20 / -30%), more slots (+1 / +2). Iglesia: *Bancas de Cedro*, *Cofradía de la Limosna*, *Capilla Lateral*; Cantina: *Marimba de Planta*, *Cuenta al Fiado*, *Corredor Techado*. Data in `data/upgrades.json`.
- Prices by hero level (P3-14, 2026-11-20): activities cost ×1.0 / ×1.4 / ×1.8 for resolve 0–2 / 3–4 / 5–6 (doc 04 §3.2; `balance.json hub.tier_price_mult`), the EBAIS too. The upgrades above bring it back down.
- Mood traits as lasting quirks wait for P3-06.

## 8) Feria Nocturna (Trinkets)

### Upgrade Tracks

1. `Tamano de Puestos`
   - Increases trinkets shown per week.
2. `Cadena de Comerciantes`
   - Reduces trinket prices.

### Rules

- Inventory rotates weekly.
- Stock weighted by game phase and unlocked regions.
- Small chance for cursed trinket with strong upside.

### Built (P3-05a, owner 2026-11-20)

- The Feria sells **all accessories**; the Taller keeps weapons and armor. It buys accessories back at half price (they don't go back on the stall).
- Each week the stall shows `feria.stock_size` (6) different accessories, one of each; buying one takes it off until the next week. Accessories dearer than `feria.cheap_price` (550 ₡) are drawn at `feria.pricey_min_weight` (0.35) of the weight in week 1, rising to full weight by `feria.full_stock_week` (8). Regions don't weigh in yet (only Sótanos is playable). Rules: `scripts/domain/feria.gd`; stock: `GameState.feria_stock` (save v16).
- Its page carries the same equipment fold as the Taller, so a hero can put on an accessory where it was bought. Town events close it (owner 2026-11-21): *Aguacero de octubre* (buying and selling), *Huelga de transportistas* (buying); *La de la feria anda de buenas* (was *El herrero…*) gives the first accessory −80%.
- **Upgrades (P3-05b):** *Tamaño de Puestos* +1/+2/+3 accessories on the stall (the new places fill at once when bought; 1 R + 500 ₡, 2 R + 1000 ₡, 3 R + 1600 ₡); *Cadena de Comerciantes* −10/−20/−30% on Feria prices (1 R + 400 ₡, 2 R + 800 ₡, 3 R + 1400 ₡; selling back still pays half the list price). `data/upgrades.json` `feria`.
- **Cursed trinkets (P3-05b):** five accessories (`cursed: true` in `data/items.json`), each a strong bonus with a real cost, from Costa Rican legends: *Diente de la Segua* (+4 daño, +3 crítico, −15 resist. estrés), *Rosario del Padre sin Cabeza* (+30 resist. estrés, +30 susto, −3 velocidad), *Espuela del Mandador* (+4 velocidad, +3 precisión, −6 PV máx.), *Cascabel de la Tulevieja* (+6 esquiva, weak to oscuridad ×1.5), *Peseta del Diablo* (+8 PV máx., +4 protección, −15 resist. golpe de gracia). 900–1100 ₡. Each week, at `feria.cursed_chance` (0.25), one is added on top of the stall. Never dropped, found in curios or given by events. Icons are tinted stand-ins until the owner's machine paints `item_<id>` (art_manifest).
- Still to do: its own town art (P3-05c).

## 9) Guardabosques del Arenal (Camp Skills)

Built (P3-13, owner 2026-11-19). The ranger's shed next to the Cantina. Prices in `data/balance.json` `camp`; rules in `scripts/domain/camping_system.gd` and `GameState` (`learn_camp_skill`, `fix_camp_skill`, `swap_shared_camp_skill`).

### Rules

- Each class has 6 camp skills of its own; there are 3 shared ones. A hero carries 2 shared skills.
- A new hero knows 3 of their 6 class skills, at random. At every fogata they get their 2 shared skills plus 2 of the class skills they know, at random (`camp_skills.json` `class_skills_per_camp`).
- **Aprender** (500 ₡): teaches one more class skill.
- **Fijar** (300 ₡): one known class skill comes up at every fogata and takes one of the two slots. Letting it go is free; fixing another replaces it.
- **Cambiar** (100 ₡): swaps one of the 2 shared skills for the third.
- Town events reach it like the other buildings (service `guardabosques`): `closed` shuts it for the week, `service_pct` scales all three prices.

### Upgrade Tracks (built P3-21, 2026-11-20; `data/upgrades.json`)

1. `Guia de Supervivencia`
   - More class skills per fogata (3 instead of 2). Later idea: stronger camp skills.
2. `Entrenamiento de Patrulla`
   - Cheaper lessons and fixing: -25 / -50% (the shared swap stays at its price).

## 10) Mejoras de Hacienda (District-Style Meta)

Global structures built from rare relics:

- `Despensa Central`: +provision carry capacity.
- `Capilla del Abuelo`: small global stress resist.
- `Bodega de Trofeos`: extra reward roll on boss clear.
- `Taller Artesanal`: slight global equipment discount.
- `Archivo Familiar`: narrative unlock rate boost.

## 11) Upgrade Material Taxonomy

- `Madera Tallada`
- `Hierro Viejo`
- `Reliquias del Abuelo`
- `Fragmentos Infernales` (late game)

Each building consumes a distinct primary material plus gold equivalent to control pacing.

**Built (P3-16, owner 2026-11-20): one material for now, Reliquias del Abuelo.** A hacienda counter like the colones (not an alforja item), shown next to the colones. Sources: clearing the objective (Aprendiz 1, Veterano 2, Campeón 3: `progression.json difficulties[].reliquias`), an elite fight or a killed roaming mini-boss (`balance.json upgrades.elite_reliquia_chance`), and three curios (*Caja del abuelo*, *Nicho de santos*, *Retrato del abuelo*; outcome `reliquias`). Every building upgrade costs Reliquias plus colones (`data/upgrades.json`). The other materials (Madera Tallada, Hierro Viejo, Fragmentos Infernales) wait for later buildings and regions.

## 12) Weekly Event Framework

- Positive events:
  - Free treatment week
  - One building upgrade cost waived
  - Rare recruit arrivals
- Negative events:
  - Building temporarily locked
  - Stress relief less effective
  - Market inflation spike

Events should create short-term adaptation pressure without hard-locking progress.

### 12.1 Implemented (P3-15, owner request 2026-11-08)

- One Tico version of **every Darkest Dungeon town event**: 56 in `data/town_events.json`, each naming the DD event it mirrors (`dd`), plus 2 Tico extras for the Guardabosques (owner 2026-11-19): *Día de los Parques Nacionales* (half price) and *Quema en el Arenal* (closed). Rules are in `scripts/domain/town_events.gd`, state in `GameState`.
- **When:** the party returns (`main.gd` → `GameState.draw_town_event()` after `end_of_expedition_week`). There's a 60% chance (`chance_pct`) of an event, drawn from a shuffled deck. It respects `min_week`/`max_week`, `once`, and `requires` (graveyard, inventory, quebrantos). The event lasts until the next return.
- **Hub:** an "Evento: …" button in the info row opens the event card automatically the first time. The card shows the text, every effect in plain words, what already happened, and any choices (who to bring back, paid offers). Shop buttons show "X ₡ (antes Y)". Closed services are greyed out.
- **What the events can do,** adapted to the hub we have (no Taller, Cantina, quirks or trinkets yet):

| Group | Effects | DD source |
|---|---|---|
| Shop prices | price_pct, first_buy_pct, sell_rate, blocked_items | Bumper Crop, Supply Run, Lost Shipment, Nomad New Year, Medical Breakthrough, Twinkle in Her Eye, A Bargain…, Empty Kegs |
| Services | closed, service_pct, relief_pct | Abbey/Tavern locks, Caregivers Convention, All Saints Day, Town Fair, A Ray of Sunlight, The Miserable Dark, Maddening Whine, Town is Abuzz |
| Next expedition | mission (region XP/damage, virtue, light, loot, items, firewood, no level limits, tough, treasure, quebranto stress) | region events, Helping Hand, Valiant Spirit, The Dark is Rising, In Radiance, The Lights, Tangible Legacy, Outdoor Enthusiasts, Brigand Incursion, Shrieker's Prize, Heresy in the Blood |
| Heroes | idle stress / quebranto cure, idle class +1 level, recruits by class, +6 recruits, a level-6 hero for hire, a free hero | One Good Week, Mardi Gras, Wellness Program, class events, A Day Long Awaited, Experienced Hero for Hire, A Desert Wind |
| Special | resurrect (Día de los Difuntos), thief (items return on the next completed expedition), offers (Limpia general, Agua de coco), gifts | From Beyond, A Thief in the Night, Crystalline Focii, They Made a Tonic, Cornerstone, Shard Harvest, Labour Force, A Job Well Done, Lost and Found, A Veil Lifted |

- Fallen heroes go to `GameState.graveyard` (last 12) so that Día de los Difuntos can bring one back with their resolve level but no gear.
- Adaptations to systems we don't have yet:
  - Building or weapon/armour upgrades become a gift: colones or a piece of gear.
  - Tavern events use the Iglesia, EBAIS, Terminal and Pulpería.
  - Diseases are replaced by full PV.
  - Shards and heirlooms are replaced by colones and items found.
  - DD's special missions become modifiers on the next expedition.

