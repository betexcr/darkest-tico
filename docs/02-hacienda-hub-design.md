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

## 9) Guardabosques del Arenal (Camp Skills)

### Upgrade Tracks

1. `Guia de Supervivencia`
   - Unlocks stronger camp skills.
2. `Entrenamiento de Patrulla`
   - Reduces cost of camp skill upgrades.

### Rules

- Camp skills categorized: recovery, anti-ambush, scouting, offense prep.
- Skills are class-specific with 1-2 shared universal options.

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

- One Tico version of **every Darkest Dungeon town event**: 56 in `data/town_events.json`, each naming the DD event it mirrors (`dd`). Rules are in `scripts/domain/town_events.gd`, state in `GameState`.
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

