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

Data: `data/curios.json` (P2-09). The bad outcomes match this table.

| Curio | Safe default | With item | Bad blind |
|-------|--------------|-----------|------------|
| `altar_roto` | Reveal nearby rooms | Agua bendita: −15 stress, reveal | +8 stress, *Maldición del altar* on the party (−5 precisión, +10% estrés recibido, 3 fights) |
| `caja_abuelo` | Small colones | Llave: colones + random equipment | *¡La caja tenía dueño!* An ambush by 1–2 region monsters |
| `pozo_seco` | +2 stress | Mecate: heal the party | One hero falls (damage) + stress + Susto |
| `arbol_amarillo` | Stress −5 | Ruda: −10 stress, heal, *Limpia de ruda* (−10% estrés recibido, 3 fights) | Damage + *Fiebre del árbol* (−2 velocidad, −5 esquiva, 4 fights; stands in for disease until P3-06) |
| `radio_vieja` | Reveal nearby rooms | Batería: reveal the map | Noise ambush (1–2 monsters) + stress |

## 4) Trap table

Data: `data/traps.json` (P2-01). Every trap triggers when the party enters its room. Mitigation: *Desarmar* (best trampa + Luz bonus − difficulty) or *Pasar con cuidado* (−10 Luz, 30% it still springs). See doc 01 §4.7.

| Trap | Difficulty | On fail |
|------|-----------:|---------|
| `vigas_inestables` (caída de vigas) | 15 | One hero 6 damage, party +5 stress |
| `alambre_de_pua` | 5 | One hero 3 damage + Sangrado |
| `escalera_resbalosa` | 0 | One hero 4 damage + Salado (−5 esquiva) |
| `piso_hundido` | 10 | One hero 5 damage + Amarrado |
| `raices_traicioneras` (Bosque) | 5 | One hero 3 damage + Amarrado |
| `humo_infernal` | — | Mid-combat stress spike; needs combat environment hooks (later) |

## 5) Non-combat event table (exploration)

| Event | Condition | Options | Outcomes |
|-------|-----------|---------|----------|
| `caminante_perdido` | Any path | Help / Ignore / Rob | Stress±, colones, ambush |
| `mercado_clandestino` | After combat | Buy / Steal / Leave | Gold, trinket, fight |
| `vision_abuelo` | Low light | Resist / Embrace | Virtud chance / stress |

## 6) Ambush rules

- Base ambush chance at camp: 12% (`data/camp_skills.json` `ambush`).
- Modifiers: low light (Penumbra or darker) +6%, exhausted party (average stress 50+) +4%, a watch skill → 0%. A scouting buff (−8%) waits for scouting skills.
- Ambush resolves as `combat` with surprise round for enemies.
- Outside camp, curios can also cause an ambush, and in the dark a normal fight may open with the party surprised (doc 01 §4.5).

## 7) Biome flavor tags

Attach tags to nodes for generator weighting: `infernal`, `bosque`, `culto`, `bestia`, `pueblo`, `volcan`.
