# Expedition Map: Node Taxonomy and Event Tables

Companion to [01-core-systems-spec.md](01-core-systems-spec.md). Use these tables for content authoring and balancing.

## 1) Node taxonomy

| Node ID | Display name | Resolves as | Typical risk | Loot bias |
|---------|--------------|-------------|--------------|-----------|
| `combat` | Encuentro | Battle | Medium | Standard |
| `combat_elite` | Encuentro duro | Elite battle | High | Relics, trinkets |
| `curio` | Lugar extraño | Curio interaction | Variable | Story, consumables |
| `trap` | Trampa / Trocha mala | Skill check or damage | Low–medium | None (avoid tax) |
| `camp` | Fogata de Trocha | Camp phase | Safe if no ambush | Recovery |
| `boss` | Jefe regional | Boss | Very high | Apex rewards |
| `safe` | Refugio | Minor heal/stress relief | Low | Small |
| `objective` | Objetivo de misión | Objective gate | High | Mission complete flag |

## 2) Edge and graph rules

- Every mission has at least one path from start to `objective`.
- `boss` appears only when mission type requires it (boss hunt, finale).
- `camp` count: short 0–1, medium 1, long 1–2 (tuning).
- Dead-end branches may attach `curio` + `trap` pairs for risk/reward.

## 3) Curio table (starter set)

Roll or place by biome. Format: `id` — interaction — outcomes (weighted).

| Curio | Safe default | With item | Bad blind |
|-------|--------------|-----------|------------|
| `altar_roto` | Scouting next node | Holy water: remove curse stack | +stress, curse |
| `caja_abuelo` | Small colones | Key: relic roll | Mimic combat |
| `pozo_seco` | Nothing | Rope: large heal | Trap damage + fear |
| `arbol_amarillo` | Stress -5 | Herb: resist buff | Disease chance |
| `radio_vieja` | Lore fragment | Battery: map reveal | Noise ambush |

## 4) Trap table

| Trap | Trigger | Mitigation | On fail |
|------|---------|------------|---------|
| `caida_vigas` | Enter node | Scout / disarm | HP + stress |
| `alambre_pincho` | Leave node | Specialist bonus | Bleed |
| `humo_infernal` | Mid-combat env | Mask consumable | Stress spike |

## 5) Non-combat event table (exploration)

| Event | Condition | Options | Outcomes |
|-------|-----------|---------|----------|
| `caminante_perdido` | Any path | Help / Ignore / Rob | Stress±, colones, ambush |
| `mercado_clandestino` | After combat | Buy / Steal / Leave | Gold, trinket, fight |
| `vision_abuelo` | Low light | Resist / Embrace | Virtud chance / stress |

## 6) Ambush rules

- Base ambush chance at camp: 12%.
- Modifiers: scouting buff -8%, low light +6%, exhausted party +4%.
- Ambush resolves as `combat` with surprise round for enemies.

## 7) Biome flavor tags

Attach tags to nodes for generator weighting: `infernal`, `bosque`, `culto`, `bestia`, `pueblo`, `volcan`.
