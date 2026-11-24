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

- Skills to learn at the Casa Comunal (P3-17, owner 2026-11-23; the hero brings 4 of 7):
  - `Chapea Rápida`: Machete bajito, como chapeando potrero: llega hasta la posición 3 y deja sangrando.
  - `Tamal de Reserva`: Saca el tamal que traía guardado en la alforja: se cura y se calma.
  - `Grito de Montaña`: Un grito de peón que retumba en la loma: poco daño, pero lo deja salado (menos precisión y daño).

## 2) Montador de Toros

- Role: Vanguard / Counter
- Ranks: `[1,2]`
- Core identity: momentum tank with retaliatory style.
- Signature skills:
  - `Mecatazo` (basic attack): lash with the lasso rope; may tangle (Salado, less dodge).
  - `Entrada Brava`: taunt + prot buff.
  - `Monta Firme`: gains riposte when hit.
  - `Patada de Corral`: push and stun chance. (Built, P1-03b: `move_target: 1`.)
  - `No Me Tumban`: death-save buff.

- Skills to learn at the Casa Comunal (P3-17, owner 2026-11-23; the hero brings 4 of 7):
  - `Lazo al Cuello`: Enlaza al que se esconde atrás y lo jala dos posiciones hacia adelante. Puede quedar enredado (menos esquiva).
  - `Rodeo`: Arranca la monta como en las fiestas de Zapote: toda la cuadrilla queda chiva, +3 velocidad por 3 turnos.
  - `Corneta de Corral`: Toca la corneta y señala al animal más bravo: casi nunca falla y lo deja fichado.

## 3) Guachiman Jubilado

- Role: Vanguard / Protector
- Ranks: `[1,2,3]`
- Core identity: guard, interrupt, order control.
- Signature skills:
  - `Silbatazo`: enemy accuracy down.
  - `Escudo de Barrio`: guard + block stacks.
  - `Ronda Nocturna`: reveals stealth and marks.
  - `Reten`: pull enemy forward. (Built, P1-03b: reaches enemy positions 2–3, `move_target: -1`.)

- Skills to learn at the Casa Comunal (P3-17, owner 2026-11-23; the hero brings 4 of 7):
  - `Linterna en la Cara`: ¿Y usted quién es? Linternazo directo a los ojos: puede dejarlo atarantado.
  - `Libreta de Reportes`: Anota placa, hora y apellido, y después cobra: +75% de daño a fichados.
  - `Cafecito de Turno`: Un cafecito de termo para aguantar el turno: queda en guardia y se calma.

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

- Skills to learn at the Casa Comunal (P3-17, owner 2026-11-23; the hero brings 4 of 7):
  - `Chancletazo`: La chancleta voladora que todo nieto conoce: poco daño, pero puede dejarlo atarantado.
  - `Café con Cuentos`: Café chorreado y cuentos de cuando ella era chiquita: alivia el estrés de toda la cuadrilla.
  - `Bendición de la Abuela`: «Dios me lo acompañe»: el aliado elegido queda encarrerado, con más críticos por 3 turnos.

## 5) Medica Josefina

- Role: Sustain / Precision Healer
- Ranks: `[3,4]`
- Core identity: targeted medicine, emergency stabilization.
- Signature skills:
  - `Triage Urbano`: strong single-target heal.
  - `Desfibrilar`: emergency restore on Al Borde ally.
  - `Antibiotico de Guardia`: disease resist and cleanse.
  - `Protocolo Estricto`: stun heal target + self stress.

- Skills to learn at the Casa Comunal (P3-17, owner 2026-11-23; the hero brings 4 of 7):
  - `Vacuna de Refuerzo`: Pinchazo y a seguir: el aliado elegido queda chiva, +15 protección por 3 turnos.
  - `Suero Oral`: Sobrecitos de suero para todos: cura un poco a toda la cuadrilla.
  - `Receta Ilegible`: Le receta algo que nadie entiende: lo deja salado (menos precisión y velocidad).

## 6) Curandero Nicoyano

- Role: Sustain / Ritualist
- Ranks: `[2,3,4]`
- Core identity: high-variance heal and warding rituals.
- Signature skills:
  - `Rezo de Nicoya`: random heal range + stress reduction.
  - `Humo de Hierbas`: party debuff resist buff.
  - `Limpia de Mal de Ojo`: curse cleanse.
  - `Deuda Espiritual`: delayed big heal with drawback.

- Skills to learn at the Casa Comunal (P3-17, owner 2026-11-23; the hero brings 4 of 7):
  - `Guaro de Hierbas`: Un traguito de guaro curado con hierbas del monte: alivia mucho estrés al aliado elegido.
  - `Sobada de Hueso`: Una sobada como Dios manda: cura un poco y deja al aliado sobado, +3 PV por turno durante 3 turnos.
  - `Maldición del Guácimo`: Una maldición vieja, de las que se hacen debajo de un guácimo: lo envenena. Al curandero le cuesta estrés.

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

- Skills to learn at the Casa Comunal (P3-17, owner 2026-11-23; the hero brings 4 of 7):
  - `Agua Bendita del Tubo`: Agua del tubo, pero bendecida en la parroquia: daño sagrado a cualquier enemigo.
  - `Rosario de Chayote`: Reparte rosarios de semilla de chayote: toda la cuadrilla queda chiva, +10 protección por 2 turnos.
  - `Exorcismo Exprés`: Sin misa ni sermón, directo al grano: daño sagrado, +50% a fichados.

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

- Skills to learn at the Casa Comunal (P3-17, owner 2026-11-23; the hero brings 4 of 7):
  - `Reinicio Forzado`: Lo apaga y lo vuelve a prender: el enemigo queda en una posición al azar.
  - `Wifi del Vecino`: Se pega al wifi del vecino y comparte la señal: toda la cuadrilla queda chiva, +6 precisión por 3 turnos.
  - `Batería de Respaldo`: Un power bank y un cable pelado: cura al aliado elegido y le quita lo atarantado.

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
