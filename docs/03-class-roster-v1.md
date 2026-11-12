# Hireable Class Roster v1 (16 Jobs)

Role model follows DD tactical ranks and FF-style clarity.

## Role Taxonomy

- `Vanguard`: frontline tank/guard/disruption.
- `Sustain`: HP recovery, cleanse, stress support.
- `Control`: stun, pull/push, debuff, mark setup.
- `Striker`: burst damage and finisher execution.
- `Specialist`: scouting, economy, anti-trap, utility.

## Position Notation

- Starting rank preference shown as `[usable ranks]` (battlefield positions, 1 = front). In data: `ranks` per class in `data/heroes.json`, and `use_ranks` / `target_ranks` per skill in `data/skills.json` (P1-03a; rules in doc 01 §2.1).
- Skills listed as short identity anchors, not full balance sheets.
- **Basic attack** (owner 2026-11-11): every class has its own, with the weapon its battle sprite holds. It is the class's first skill in `data/heroes.json`, and no two classes share a skill.

---

## 1) Campesino Machetero

- Role: Vanguard / Bruiser
- Ranks: `[1,2]`
- Core identity: bleed cleave and self-sustain through grit.
- Signature skills:
  - `Machetazo Barrido`: front cleave, bleed.
  - `Trabajo Duro`: self buff (damage + bleed resist).
  - `Golpe de Faena`: bonus vs marked targets.
  - `Aguante de Campo`: guard ally, minor self-heal.

## 2) Montador de Toros

- Role: Vanguard / Counter
- Ranks: `[1,2]`
- Core identity: momentum tank with retaliatory style.
- Signature skills:
  - `Mecatazo` (basic attack): lash with the lasso rope; may tangle (Salado, less dodge).
  - `Entrada Brava`: taunt + prot buff.
  - `Monta Firme`: gains riposte when hit.
  - `Patada de Corral`: push and stun chance.
  - `No Me Tumban`: death-save buff.

## 3) Guachiman Jubilado

- Role: Vanguard / Protector
- Ranks: `[1,2,3]`
- Core identity: guard, interrupt, order control.
- Signature skills:
  - `Silbatazo`: enemy accuracy down.
  - `Escudo de Barrio`: guard + block stacks.
  - `Ronda Nocturna`: reveals stealth and marks.
  - `Reten`: pull enemy forward.

## 4) Abuela Sabia

- Role: Sustain / Stress Support
- Ranks: `[2,3,4]`
- Core identity: healing, comfort, anti-curse kitchen alchemy.
- Signature skills:
  - `Cucharonazo` (basic attack): wooden ladle; weak, accurate, may stun.
  - `Sopa Milagrosa`: party heal over time.
  - `Regaño Santo`: ally stress heal + resolve resist.
  - `Cataplasma Casero`: cure bleed/blight-like effects.
  - `Consejo Viejo`: buff resistances and speed.

## 5) Medica Josefina

- Role: Sustain / Precision Healer
- Ranks: `[3,4]`
- Core identity: targeted medicine, emergency stabilization.
- Signature skills:
  - `Triage Urbano`: strong single-target heal.
  - `Desfibrilar`: emergency restore on Al Borde ally.
  - `Antibiotico de Guardia`: disease resist and cleanse.
  - `Protocolo Estricto`: stun heal target + self stress.

## 6) Curandero Nicoyano

- Role: Sustain / Ritualist
- Ranks: `[2,3,4]`
- Core identity: high-variance heal and warding rituals.
- Signature skills:
  - `Rezo de Nicoya`: random heal range + stress reduction.
  - `Humo de Hierbas`: party debuff resist buff.
  - `Limpia de Mal de Ojo`: curse cleanse.
  - `Deuda Espiritual`: delayed big heal with drawback.

## 7) Shaman Bribri

- Role: Control / Hex
- Ranks: `[2,3,4]`
- Core identity: spirit marks and resistance shredding.
- Signature skills:
  - `Marca del Bosque`: mark + dodge down.
  - `Susurro de Sibú`: stress hit and fear chance.
  - `Raices Vivas`: root/pull.
  - `Llamado Ancestral`: team resist aura.

## 8) Maestra de Escuela Rural

- Role: Control / Support
- Ranks: `[2,3,4]`
- Core identity: discipline-based debuff and focus support.
- Signature skills:
  - `Lista de Asistencia`: speed up ally line.
  - `Regla en Mano`: stun chance vs low resolve enemies.
  - `Tarea Pendiente`: accuracy debuff and stress chip.
  - `Clase de Repaso`: party accuracy buff.

## 9) Exorcista de Barrio

- Role: Control / Anti-Infernal
- Ranks: `[1,2,3]`
- Core identity: anti-demon toolkit and fear control.
- Signature skills:
  - `Sal de Proteccion`: anti-curse ward.
  - `Expulsion`: bonus damage and stun vs infernal.
  - `Circulo de Tiza`: guard zone aura.
  - `Liturgia de Hierro`: stress resist group buff.

## 10) Tecnologo Errante

- Role: Striker / Utility
- Ranks: `[2,3,4]`
- Core identity: gadget burst, trap hacking, mark exploitation.
- Signature skills:
  - `Corrientazo` (basic attack): the drone shocks with a stripped charger cable; bonus vs marked.
  - `Dron Casero`: backline strike + reveal.
  - `Exploit Zero-Day`: heavy bonus vs marked.
  - `Firewall Humano`: temporary block to ally.
  - `Interferencia`: enemy speed and accuracy down.

## 11) Pistero de Motocross

- Role: Striker / Mobile
- Ranks: `[1,2,3]`
- Core identity: rank-shifting combo chain.
- Signature skills:
  - `Derrape`: lunge forward attack.
  - `Patinazo`: retreat strike to back rank.
  - `Punto Ciego`: crit bonus after movement.
  - `Aceleracion`: self speed and dodge buff.

## 12) Cazadora de Cerro

- Role: Striker / Scout
- Ranks: `[2,3,4]`
- Core identity: ranged pressure and ambush setup.
- Signature skills:
  - `Disparo de Sendero`: high accuracy ranged hit.
  - `Marca de Presa`: mark + crit setup.
  - `Trampa de Lazo`: root and bleed.
  - `Vista de Aguila`: scouting chance buff.

## 13) Artesano de Sarchi

- Role: Specialist / Economy
- Ranks: `[2,3,4]`
- Core identity: relic manipulation and team utility.
- Signature skills:
  - `Herramienta Fina`: trap disarm bonus.
  - `Pulido de Reliquia`: temporary trinket efficiency buff.
  - `Mano de Taller`: repair-like armor buff.
  - `Negocio Redondo`: post-fight loot bonus chance.

## 14) Cafetalera

- Role: Specialist / Morale
- Ranks: `[2,3,4]`
- Core identity: stamina and stress tempo support.
- Signature skills:
  - `Cafe Chorreado`: speed and stress resist buff.
  - `Ronda de Termo`: small party stress heal.
  - `Mano Firme`: ally debuff cleanse.
  - `Cosecha Dura`: self buff, then single-target strike.

## 15) Pescador del Pacifico

- Role: Specialist / Control
- Ranks: `[1,2,3]`
- Core identity: hook pulls, nets, attrition bleed.
- Signature skills:
  - `Anzuelo Profundo`: pull and mark.
  - `Red Enredada`: multi-target speed down.
  - `Corte de Escama`: bleed strike.
  - `Aguas Tranquilas`: self-heal on marked enemy kill.

## 16) Sabanero de Guanacaste

- Role: Specialist / Anti-Beast
- Ranks: `[1,2,3]`
- Core identity: rope control, anti-large prey finisher.
- Signature skills:
  - `Lazo de Sabana`: pull + immobilize.
  - `Espuela Corta`: armor pierce strike.
  - `Canto de Arreo`: party damage buff vs beasts.
  - `Domador`: strong bonus against size-2 enemies.

---

## Team Composition Guidelines

- Stable beginner teams:
  - 1 Vanguard + 1 Sustain + 1 Control + 1 Striker
- High-risk greed teams:
  - 1 Vanguard + 1 Sustain + 2 Strikers
- Long mission endurance teams:
  - 1 Vanguard + 2 Sustain/Control hybrids + 1 Specialist

## Unlock and Progression Notes

- 8 classes available at game start.
- Remaining 8 unlocked through:
  - Region quest chains
  - Building upgrade milestones
  - Story beats tied to grandfather's legacy logs
