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
