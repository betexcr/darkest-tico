# Handoff Log

Newest entry first. Every agent session ends by adding an entry here (rules: [../AGENTS.md](../AGENTS.md) §3). Backlog and task IDs: [12-phase-plan.md](12-phase-plan.md).

## Template (copy this)

```markdown
## YYYY-MM-DD — <task ID(s)> — <one-line summary>
- **Agent / branch:** <tool + model if known> / `<branch>`
- **Status after session:** <ID: done | review | in-progress | blocked — why>
- **Changed:** <files or areas, one line each>
- **Verified:** <validate_data.py result; Godot smoke/tests result, or "not run — no Godot">
- **Not verified / risks:** <what could be broken>
- **Decisions needed:** <questions for the owner, or "none">
- **Next step:** <one concrete action: task ID + first file to open + what to do>
```

---

## 2026-11-11 (later) — P3-04 — Casa Comunal skill ranks
- **Agent / branch:** Claude Code (Opus 5.5, owner's Windows machine) / `main`
- **Status after session:** P3-04 review (last acceptance box ticked). New todo tasks: P3-16 (Casa Comunal building upgrades), P3-17 (unlockable skills).
- **Changed:**
  - Data:
    - `data/progression.json` `skill_ranks`: ranks 1–5; costs 300/900/1500/2700 (doc 04 §3.3); rank N needs Resolución N−1; generic `per_rank` bonus.
    - `data/skills.json`: Escudo de Barrio gets `rank_bonus` `{status_mods: 5}`, and its description no longer hard-codes +20.
    - `data/town_events.json` `_doc`: `casa_comunal` is a service for `closed` and `service_pct`.
  - `scripts/domain/skill_ranks.gd` (new): rank lookup, `ranked()` copies with bonuses, gates, preview lines, ranks for seasoned heroes.
  - `GameState`:
    - New functions `hero_skill`, `skill_rank_cost`, `skill_rank_block_reason`, `buy_skill_rank`.
    - Heroes get `skill_ranks`. The Veterano event hero arrives with rank 5 skills.
    - Save v8: v7 and older load at rank 1; ranks are clamped and unknown ids dropped.
  - Combat:
    - Hero ripostes use the ranked attack.
    - Crit adds the skill's `skill_crit`.
    - The action bar uses `hero_skill`; title "X (rango N)", rank pips, tooltip shows precision, crit, status chances and mods.
  - UI:
    - `skill_button.gd`: rank pips, plus a shared `body_for(skill)` tooltip builder that `expedition_screen._skill_tooltip` now calls.
    - Hub: Casa Comunal row under the inventory for the selected hero. Icon + pips, then "Rango N — X ₡" or "Rango N: Resolución M". Tooltip shows what the next rank adds. The roster tooltip lists ranks.
  - `tools/validate_data.py`: checks `skill_ranks` and `rank_bonus` keys, and accepts the `casa_comunal` service. `town_events.gd`: service name.
  - `tests/test_progression.gd`: 28 new skill-rank checks. `tools/screens/skills_screenshot.gd` (new).
  - Docs: 01 §6.3 (new), 01 §6.1, 02 §4, plan.
- **Verified:**
  - `python3 tools/validate_data.py`: 0 errors / 0 warnings.
  - Godot 4.7.2 headless: all 9 test scripts 0 failures, no errors.
  - Screenshots (Windows, windowed), checked by eye: hub row for a Resolución 2 hero (gated + buyable buttons, tooltips) and the battle bar with pips (rank 3 Machetazo 6–11, +2 precision, +2% crit).
- **Not verified / risks:**
  - Balance: +1/+1 damage per rank is about +20% on a 4–9 attack at rank 5. Prices are doc 04's. Nobody has played it.
  - The pips are small (5 × 5 px) on the 52 px icons.
  - A disabled Godot button may not show its tooltip, which is why the resolve gate is written on the button. "Not enough colones" only shows as a greyed-out price.
- **Decisions needed:**
  - Are the per-rank numbers right (`progression.json` `skill_ranks.per_rank`)?
  - Should the four starting classes keep sharing Machetazo as their first skill? Today a rank in it is per hero, so this is only a flavour question, but it predates this task.
- **Next step:** P1-03 battlefield ranks 1–4 (first `todo` in P1 with deps done; it's L, so split it first). Read doc 01 §2.1 and doc 03 "Position Notation", then add `use_ranks`/`target_ranks` to `data/skills.json` and a pure `scripts/domain/rank_rules.gd`. Combat rules now live in `scripts/combat/combat_controller.gd` (the plan still says `combat_scene.gd`).

---

## 2026-11-11 — P0-02 — Merged `tender-brown` into `main`; project moved to Godot 4.7
- **Agent / branch:** Claude Code (Opus 5.5, owner's Windows machine) / `main`
- **Status after session:** P0-02 done. P4-12, P4-13, P4-14 are now on `main` (still `review`, owner to look in-game).
- **Changed:**
  - Merged `origin/betomm/tender-brown-x04ghq` into `main` (no conflicts).
  - `project.godot` `config/features` 4.6 → 4.7: the owner's editor (the only install, `C:\Godot\Godot_v4.7.2-stable_win64.exe`) had already made this change.
  - `.cursor/rules/godot-runtime.mdc`, `README.md`, `launch-editor.bat`: 4.7.2 executable path, project root is now `C:\Code\darkest-tico`.
  - `AGENTS.md`: engine 4.7; cloud agents download the official 4.7.2 Linux build.
- **Verified:** `python3 tools/validate_data.py` 0 errors / 0 warnings (Python 3.15 installed with `uv python install --default`, so `python3` is on PATH on the owner's machine). Godot 4.7.2 headless `--import` clean; all 9 test scripts 0 failures, no `SCRIPT ERROR`. Ran `tools/screens/tooltip_screenshot.gd` windowed on 4.7.2: hub and battle tooltips still show the P4-14 card, so the engine's tooltip structure (`TooltipPanel` / `TooltipLabel`) is unchanged.
- **Not verified / risks:** none known. Commits from the owner's machine are now authored as the owner (global git identity set 2026-11-11).
- **Decisions needed:** none
- **Next step:** P3-04 skill ranks (Casa Comunal): open `scripts/hacienda/hacienda_hub.gd`; rank purchase gated by `resolve_level`, costs in doc 04 §3.3.

---

## 2026-11-09 (night) — P4-14 — One tooltip design for the whole game
- **Agent / branch:** Claude Code (cloud) / `betomm/tender-brown-x04ghq`
- **Status after session:** P4-14 review · P4-13 review · P4-12 review (entries below). Owner to look at all three in-game.
- **Changed:**
  - `scripts/ui/tooltip_card.gd` (new): the shared tooltip look (opaque dark card, warm border, gold title, rule, wrapped body, effect bullets, hint colour for "Clic…" lines). `from_text("Title\nbody")` / `"Title — body"` / plain sentence.
  - `scripts/autoload/tooltip_styler.gd` (new autoload `TooltipStyler`, registered in `project.godot`): when Godot's default tooltip popup enters the tree, its label is replaced by the card. So **every** `tooltip_text` in the game is styled with no change at the call site; new tooltips need nothing.
  - `item_tooltip.gd`, `skill_button.gd`, `equip_slot.gd` build on `tooltip_card.gd` (skill effects are one row each).
  - `tests/test_feedback.gd` (+2 checks), `tools/screens/tooltip_screenshot.gd` (new: hovers 9 controls in hub and battle).
- **Verified:** `validate_data.py` 0 errors / 0 warnings. Godot 4.6.2 headless: all 9 test scripts 0 failures, no `SCRIPT ERROR`. Tooltips checked by screenshot with real hovers: hub (sell, Pura Vida, hero row, event), battle (skill, guard, status icon, enemy, map room).
- **Not verified / risks:**
  - `TooltipStyler` relies on how Godot 4.6 builds the default tooltip (a `PopupPanel` "TooltipPanel" with one `Label` "TooltipLabel"). If an engine upgrade changes that, tooltips fall back to Godot's default look; `test_feedback` and `tooltip_screenshot.gd` will show it.
  - Tooltip wording was not changed; some would read better rewritten as "Title\nbody" (P4-02).
- **Decisions needed:** none.
- **Next step:** P3-04 skill ranks (Casa Comunal): open `scripts/hacienda/hacienda_hub.gd`; rank purchase gated by `resolve_level`, costs in doc 04 §3.3.

---

## 2026-11-09 (later) — P4-13 — Defeated enemies can't be selected and lie behind the living
- **Agent / branch:** Claude Code (cloud) / `betomm/tender-brown-x04ghq`
- **Status after session:** P4-13 review · P4-12 review (entry below). Owner to look at both in-game.
- **Changed:**
  - `scripts/combat/battle_unit.gd`: a fallen fighter gets `z_index = DEAD_Z` (-1) so living sprites draw over it. A defeated enemy also sets `mouse_filter = IGNORE` and drops its tooltip, so clicks reach the living enemy it overlaps. `rest()` restores both for a living fighter.
  - `scenes/expedition/expedition_screen.tscn`: `BgTexture` and `Darken` at `z_index = -2`, otherwise the fallen would go behind the background.
  - `scripts/expedition/expedition_screen.gd`: `_on_unit_clicked` ignores defeated enemies (no info panel, no target).
  - `tests/test_feedback.gd` (+2 checks).
- **Verified:** `validate_data.py` 0 errors / 0 warnings. Godot 4.6.2 headless: all 9 test scripts 0 failures, no `SCRIPT ERROR`. Draw order checked by screenshot (a living enemy between two fallen ones).
- **Not verified / risks:**
  - Fallen heroes stay clickable on purpose (the click shows the first living hero, as before).
  - Anything added to the expedition screen below z -1 would hide behind the background.
- **Decisions needed:** none.
- **Next step:** P3-04 skill ranks (Casa Comunal): open `scripts/hacienda/hacienda_hub.gd`; rank purchase gated by `resolve_level`, costs in doc 04 §3.3.

---

## 2026-11-09 — P4-12 — Pulpería shows icon tiles; new opaque item tooltip card
- **Agent / branch:** Claude Code (cloud) / `betomm/tender-brown-x04ghq`
- **Status after session:** P4-12 review (owner to look at it in-game).
- **Changed:**
  - `scripts/ui/shop_slot.gd` (new): a store tile is the item's icon with this week's price under it. Click buys. Price is green/red when a town event changes it, "cerrado" when blocked.
  - `scripts/ui/item_tooltip.gd` (new): the item card (icon, name, category chip, description, one line per effect, where it is used, buy/sell, hint or red warning). Fully opaque. Used by the store, alforja cells (`inventory_slot.gd`, new `tooltip_note`), equipment slots and the combat alforja.
  - `GameState.item_tooltip_parts(id)`: the tooltip facts as a Dictionary; `item_tooltip(id)` builds the same plain text from it.
  - `hacienda_hub.tscn`: `ShopGrid` is now an `HFlowContainer` (tiles wrap to the column width).
  - `tests/test_hub.gd` (+4 checks), `tools/screens/shop_screenshot.gd` (new).
- **Verified:** `validate_data.py` 0 errors / 0 warnings. Godot 4.6.2 headless: `smoke_expedition`, `test_guard`, `test_status`, `test_hub`, `test_equipment`, `test_feedback`, `test_combat_items`, `test_progression`, `test_town_events`: all 0 failures, no `SCRIPT ERROR`. Store and tooltip checked by screenshot (xvfb, real hover).
- **Not verified / risks:**
  - The store area shows about 3 rows of tiles at 1280×720 before scrolling; item names are only in the tooltip now.
  - `item_tooltip.gd` uses the `GameState` autoload, so a `-s` script must `load()` it at run time, not `preload` it.
- **Decisions needed:** none.
- **Next step:** P3-04 skill ranks (Casa Comunal): open `scripts/hacienda/hacienda_hub.gd`; rank purchase gated by `resolve_level`, costs in doc 04 §3.3.

---

## 2026-11-08 (night) — P3-15 — Town events (Tico versions of every DD one), Modo Pura Vida, Mano vuelta
- **Agent / branch:** Claude Code (cloud) / `betomm/amazing-clarke-lv3whd`
- **Status after session:** P3-15 review. The open question from the previous entry is answered: the owner asked what DD does (it blocks), then asked for DD's two exceptions.
- **Changed:**
  - `data/town_events.json` (56 events) + `scripts/domain/town_events.gd`: deck draw (60%, week windows, once, requirements), price/service/relief/mission modifiers, plain-language effect lines.
  - `GameState`:
    - `draw_town_event()`, called from `main.gd` after `end_of_expedition_week`.
    - `item_price`/`buy_block_reason`, event-aware `sell_price`/`heal_cost`/`iglesia_cost`/`iglesia_relief`/`hire_cost`.
    - Mission modifiers in `start_mission`/`complete_mission`: XP, damage buff, virtue chance via `StressSystem.virtue_bonus`, light decay, loot/items, firewood, tough, treasure.
    - Graveyard + `resurrect`, stolen items returned on a completed expedition, paid offers.
    - `radiant_mode` (Modo Pura Vida). Save v7 migrating v6.
  - `resolve_system.gd`: `radiant` (faster curve, +2 to max_level).
  - Hub: event button + card (choices), Pura Vida checkbox, prices "X ₡ (antes Y)", closed services. The EBAIS button now shows whenever PV is missing (free events made the price 0).
  - Expedition info panel labels event buffs "(evento, toda la expedición)". Victory screen shows the botija.
  - Docs: 02 §12.1 (mapping table), 01 §6.1.
- **Verified:** `validate_data.py` 0 errors / 0 warnings. Godot 4.6.2 headless: `test_town_events` (119 checks: every event forced and the hub opened with it), `test_progression`, `smoke_expedition`, `test_hub`, `test_status`, `test_equipment`, `test_feedback`, `test_guard`: all 0 failures. Event card and hub checked by screenshot (`tools/screens/progression_screenshot.gd` → hub_event.png).
- **Not verified / risks:**
  - Balance of event frequency (60%) and of each effect. The −100% consumables event makes combat items free too (as DD's Bumper Crop does for provisions).
  - Texts are first drafts against doc 08 (Ley seca, Huelga en la Caja, OIJ…); owner tone review wanted.
  - Events only draw through `main.gd`; tests call `draw_town_event(id)` directly.
- **Decisions needed:**
  - Event frequency: should it be a player option like DD (currently data, 60%)?
  - Are the adaptations OK where we lack DD systems (upgrades → gifts, tavern → Iglesia/EBAIS/Terminal/Pulpería, special missions → next-expedition modifiers)?
- **Next step:** P3-04 skill ranks (Casa Comunal): open `scripts/hacienda/hacienda_hub.gd`; rank purchase gated by `resolve_level`, costs in doc 04 §3.3.

---

## 2026-11-08 (later) — P1-14, P3-04, P3-07, P4-11 — 7+7 Quebrantos/Virtudes, resolve levels, camping, victory screen
- **Agent / branch:** Claude Code (cloud) / `betomm/amazing-clarke-lv3whd` (based on `betomm/sleepy-ramanujan-78dwh9` at 84b2602, owner request)
- **Status after session:** P1-14 review · P3-04 in-progress (XP/levels/difficulty done; skill ranks todo) · P3-07 review · P4-11 review · new todo: P3-13, P3-14
- **Changed:**
  - **Quebrantos/Virtudes, 7 each** (`stress_system.gd`):
    - Paranoia now refuses heal/buff skills (spec) instead of skipping turns.
    - New afflictions: Bravata (wastes Luz), Desesperanza (spreads stress when hit), Nervios, Fatalismo.
    - New virtues: Valentía, Puntería, Esperanza (calms others each round), Vigor (+1 PV each round), Abnegación (takes hits for a companion).
    - Stat parts are data: `statuses.json` `mental_mods`, read by `StatusEffects.stat()` and `deathblow_chance()`, so they show in the info panel.
  - **Resolve levels** (`data/progression.json`, `resolve_system.gd`):
    - Levels 0–6 using the Darkest Dungeon XP curve (2/8/14/24/36/48). XP only on a completed expedition.
    - +10% Atarantado/Veneno/Sangrado/Salado and +5% Trampas resistance per level (`recompute_stats`).
    - **Difficulty** picker in the hub: Aprendiz/Veterano/Campeón. Heroes above the range refuse to go; heroes below get +20 stress per missing level and +25% stress taken per level. Enemy PV/damage/accuracy and pay scale with difficulty.
    - Hub roster shows level, XP and warnings. Save v6, migrating v5.
  - **Camping** (`data/camp_skills.json`, `camping_system.gd`, `expedition_screen.gd`):
    - 1 leña per expedition. Meal tiers in gallo pinto, 12 respite points, 4 camp skills per hero (2 class + 2 shared, `heroes.json` `camp_skill_ids`), each usable once per camp.
    - Buffs last 4 fights (`hero.camp_buffs`, ticked in `combat_controller._finish`).
    - Night ambush 12% (+6% low light, 0 with a watch skill): 2–3 region monsters who act first in round 1.
    - Luz back to 100. "Seguir sin acampar" keeps the fogata for later.
    - `EventActions` is now an `HFlowContainer` (one row per hero in the respite menu).
  - **Victory screen** (`victory_screen.gd`, `main.gd`): page 1 rewards (encargo, loot colones, item tiles, fights/curios/camps), page 2 per-hero cards (XP, level badge + bar, level-up, new Quebranto/Virtud, fallen). Data from `GameState.mission_ledger` + `complete_mission()`.
  - Validator checks `camp_skills.json`, `progression.json`, `camp_skill_ids` and `mental_mods`. Spec doc 01 §3.3, §4.4, §6.1, §6.2.
- **Verified:** `validate_data.py` 0 errors. Godot 4.6.2 headless: `test_progression` (71 checks), `smoke_expedition` (now camps on the way and checks the victory summary), `test_status`, `test_hub`, `test_equipment`, `test_feedback`, `test_guard`: all 0 failures, no script errors. Screenshots of the camp, both victory pages and the hub checked by eye (`tools/screens/progression_screenshot.gd`).
- **Not verified / risks:**
  - Balance. 6 of 9 smoke runs won vs 5 of 6 on the base branch (small samples; the smoke now detours to the camp). Veterano/Campeón multipliers are first guesses.
  - The smoke bot always eats the Festín.
  - Esperanza/Vigor only start from round 2.
- **Owner decision (same day):** keep the global difficulty picker, and give each dungeon its own scaling level with Sótanos the easiest.
  - Done: `region_level` in region JSONs (Sótanos 0, Bosque 1, more per doc 05 §4), `ResolveSystem.expedition()` combines it with the difficulty, and the hub labels show the combined level.
  - Difficulty enemy multipliers were corrected to doc 05 §4 (Veterano ×1.22 PV / ×1.12 damage / +10% resist; Campeón ×1.46 / ×1.24 / +20%).
  - Bosque stays hidden (P2-07); its level-1 scaling applies once it's back in `PLAYABLE_REGIONS`.
- **Merged into `betomm/sleepy-ramanujan-78dwh9`** (owner request), on top of aef3787 (action bar P4-09, new icons). One conflict in `expedition_screen.gd` (new vars + combat start), kept both sides. After the merge: validate_data 0 errors / 0 warnings; all 7 Godot tests 0 failures, no script errors; camp screen re-checked by screenshot.
- **Decisions needed:** should heroes too seasoned for the expedition block the start (as now, like DD) or just warn? (asked 2026-11-08)
- **Next step:** P3-04 skill ranks: open `scripts/hacienda/hacienda_hub.gd`, add the Casa Comunal (doc 02 §4: rank purchase gated by `resolve_level`, costs in doc 04 §3.3).

## 2026-11-08 (late night) — P1-04 — Effects list, % resistances, gear with resistances/buffs
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** P1-04 review
- **Changed:**
  - Clicking a hero or enemy opens the stage info panel (opposite side of the clicked unit): stats, active effects (icon, turns, stacks, stat changes; hover the name for the description) and resistances as a % table like Darkest Dungeon. Enemy resistances only while someone wears the Lentes del abuelo. `expedition_screen.gd` (`_show_hero_info`, `_effects_bbcode`, `_resist_bbcode`).
  - Resistances (`data/statuses.json` `resist_categories`): Atarantado, Veneno, Sangrado, Salado, Susto, Golpe de gracia (death blow, cap 87), Trampas. Class bases in `heroes.json`, full tables for all enemies, equipment `status_resist`; immunity shows as 100. Death save and traps use them.
  - Items: existing gear got thematic resistances (e.g. botas de hule: trampas/veneno; ojo de venado now resists Salado instead of stun immunity); weapons `on_hit` (machete de Cartago bleed, garrote stun, honda mark); accessories `start_status`; 8 new accessories and 4 new buff consumables (`data/items.json`). Tooltips show all of it.
  - `tools/screens/battle_screenshot.gd`: real screenshots under Xvfb (`xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screens/battle_screenshot.gd -- <dir>`).
- **Verified:** validate_data 0 errors; Godot headless test_equipment, test_status, test_feedback, test_hub, smoke all 0 failures; screenshots checked.
- **Not verified / risks:** Balance (heroes now resist ailments ~30-70%).
- **Decisions needed:** none
- **Later the same night:** 7 more consumables — debuff removers (Puño de sal gruesa: salado+fichado; Agua florida: susto+salado; Café bien cargado: atarantado → espabilado), buffs (Guarapo, Chicharrón de olla, Chilero casero → respondón) and the cure-all **Agua de la Negrita** (`effects.cure_all`, also usable on skills). Tooltips list what each item removes. Tests updated (test_status).
- **Next step:** commit the icons from the running `python tools/sd_local.py` (18 missing item/status icons; rerun it with no arguments if the container restarted — it only makes missing ones); then P4-08 enemy sprites.

## 2026-11-08 (night) — P1-04 — Every Darkest Dungeon status effect, Tico names
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** P1-04 review; P1-13 review; P4-08 in-progress (enemies left)
- **Changed:**
  - `data/statuses.json` (new): 18 statuses — Sangrado, Envenenado, Atarantado → Espabilado, Salado, Fichado, Susto, Chiva, Encarrerado, Al cuido / Cuidando, Respondón, Sobado, Santiguado, Agazapado, En guardia, Al Borde, Convaleciente — with names, descriptions, colours, letters, stacking, defaults.
  - `scripts/domain/status_effects.gd` rewritten: per-application stacks, 3-turn default / 5 on crit DoTs, `status_resist` (+50% stun resist per Espabilado stack), stat changes (`stat()`), Al Borde/Convaleciente penalties, aegis, stealth targeting, marked-target AI pick, guardian lookup.
  - `combat_controller.gd`: initiative/accuracy/dodge/crit/damage/prot/stress use status stats; sobado/susto ticks; Al cuido redirect; ripostes both ways; Santiguado blocks direct hits; stealth breaks on attacking; crit gives Encarrerado; `applies` may be a list; `self_applies`, `guard_ally`, `vs_marked_pct`.
  - Content: hero skills, enemy specials, enemy `status_resist`, té de tilo cures susto, agua bendita cures salado (`data/*.json`). Validator checks all of it. AGENTS.md §4 updated.
  - Icons: data-driven badges + tooltips; 13 new `status_*` art entries queued (letter badges until generated).
- **Verified:** `validate_data.py` 0 errors. Godot headless: test_status (50 checks), smoke (3 expeditions), test_guard, test_hub, test_equipment, test_feedback — all 0 failures, no script errors.
- **Not verified / risks:** Balance of the new effects untested by a human (marks + bonuses, enemy ripostes). Move/Shuffle not done (no formation ranks yet). Escudo de Barrio changed from "ally gets Guard" to "Al cuido" (guachimán takes the hits).
- **Decisions needed:** none
- **Next step:** Check the queued status icons (`assets/status/*.png`), commit them; then P4-08 enemy sprites one by one.

## 2026-11-08 (later) — P4-08, P1-13 — Right-arm attacks (mirrored stage), combat feedback
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** P4-08 in-progress (8 hero attack sprites done; enemies left); P1-13 review
- **Changed:**
  - Owner: the weapon must be in the RIGHT arm. SD 1.5 + OpenPose always raises the arm on the enemy side of the picture, which for a right-facing hero is the left arm (profile, two-handed, back-view, init-from-another-sprite and hand-repaint attempts all failed). Fix: **mirrored the battle stage** — party on the right facing left, enemies on the left (`scenes/expedition/expedition_screen.tscn`, `expedition_screen.gd`, `battle_unit.gd`). Attack skeleton faces left; weapon guide angle 135°, `hand: right`. Rule in AGENTS.md §4.
  - All 8 hero `attack.png` regenerated facing left (seeds in `redo_seeds`); small hand edits recorded in each sprite's metadata `post` (second weapons erased, médica syringe moved to the right hand, curandero smoke). Scripts in `tools/sprite_edits/`.
  - P1-13 combat feedback: floating damage/crit/heal/stress/miss numbers + hit flash; status icons (sangrado, veneno, aturdido, guardia) above fighters with turns + tooltip (`battle_unit.gd`). Art entries `status_*` in the manifest (`assets/status/<id>.png`, 64 px); a coloured letter badge shows until the PNG exists. Test `tests/test_feedback.gd`.
- **Verified:** `validate_data.py` 0 errors. Godot headless: smoke (0 failures), test_guard, test_status, test_hub, test_equipment, test_feedback (0 failures).
- **Not verified / risks:** Nobody has looked at the mirrored stage or the popups in a running game. Hero idle/cast/hurt sprites were made for the old layout (mostly front-facing, so they still work).
- **Decisions needed:** none
- **Next step:** P4-08 enemies one by one: rewrite each enemy `look` from `assets/enemies/<id>.png`, generate facing LEFT like heroes (the game mirrors enemies), `redo_reference: idle`, check for extra weapons. Then commit the `status_*` icons if the queued run produced them (`python tools/sd_local.py --only status_sangrado status_veneno status_aturdido status_guardia`).

## 2026-11-08 — P4-08 — Hero attack poses aimed at the enemy
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** P4-08 in-progress (8 heroes done incl. new attack poses; 15 enemies left)
- **Changed:**
  - Attack pose (owner request): turned toward the enemy (right), lunging, weapon held forward. The pose skeleton alone could not place the weapon (SD 1.5 draws blades hanging down), so attack is redrawn from scratch with a 2nd ControlNet (`lllyasviel/control_v11p_sd15_scribble`, `sprites.weapon_guide`) fed a drawn weapon shape per hero (`weapon_shape`: line / rope / cross / box / bowl).
  - New per-character knobs in `tools/art_manifest.json`: `redo_seeds`, `redo_poses`, `redo_looks`, `redo_ref_scale`, `negative_extra`, `weapon_shape`. Null keypoints allowed in skeletons.
  - `--redo-tries N --preview-dir D` writes PNG + metadata variants; pick one by copying both into `assets/sprites/<id>/attack.*` and setting `redo_seeds`.
  - Medica Josefina: black leggings (her negative no longer contains "stockings", which suppressed leg coverings).
- **Verified:** `validate_data.py` 0 errors. Each attack picked by eye from 2 variants.
- **Not verified / risks:** Fixed later the same day (owner: hats stretched, faces not looking right): attack redraws for campesino, montador, medica, exorcista use the character's own idle sprite as the IP-Adapter reference (`redo_reference: idle`) instead of the portrait close-up, plus 'head in profile facing right'. Campesino attack (seed 5101) had a stray second machete erased by hand (`post` in its metadata). Guachimán attack has a ponytail he lacks elsewhere.
- **Decisions needed:** Owner review of the 8 attack sprites (all now face right).
- **Next step:** P4-08 — start enemies one by one (see previous entry); for their attack poses set `redo_reference: idle` (portrait close-ups distort full-body redraws) and a `weapon_shape`.

## 2026-11-07 (night) — P4-08, P4-10 — Hero sprites that match the portraits; all item icons
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** P4-10 review (all 64 item icons); P4-08 in-progress (8 heroes done, 15 enemies left)
- **Changed:**
  - `tools/sd_sprites.py`: portrait → IP-Adapter reference (portrait cut out on grey, cached in `tools/.sprite_cache/<id>_ref.png`); attack cell redrawn full-size (`sheet.redo_states`); per-character `seed`, `redo_seeds`, `redo_poses`, `skeletons`; `--states attack --force` reuses the cached raw sheet (~3 min); dead sprites keep only the main figure; `--try-seeds N --ref-scales ... --preview-dir` for comparisons.
  - `tools/art_manifest.json`: hero `look`s rewritten from their portraits; sprite prompts/negative kept under CLIP's 77 tokens.
  - `assets/sprites/<hero>/` for all 8 hero classes. AGENTS.md §4 + doc 11: sprites must look like the portrait (owner rule).
- **Verified:** `validate_data.py` 0 errors / 0 warnings. Each hero's sprites reviewed by eye next to the portrait. Godot tests not re-run this session (no code changes in game scripts).
- **Not verified / risks:** Owner still reviewing heroes one by one. Re-rolls landed: montador (seed 5013 + lasso attack redo 5015; leftover: hat in hand on attack, hide behind hurt), medica_josefina (seed 5051, flat boots, knee skirt), exorcista attack (processional cross). Per-character `negative_extra` exists for outfit drift (keep total under 77 CLIP tokens).
- **Decisions needed:** Owner verdict per hero sprite set.
- **Next step:** P4-08 — after owner OK on heroes, run enemies one by one: rewrite each enemy `look` in `tools/art_manifest.json` from `assets/enemies/<id>.png`, then `python tools/sd_sprites.py --only <id> --force` (humanoids ~12 min; beasts rata_de_troje, murcielago_bodega, cadejo_negro use img2img), review next to the portrait, re-roll attack with `--states attack --force` if it has a third hand / no weapon.

## 2026-11-07 (later) — Combat depth, recruiting, equipment, Godot tests
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:**
  - done: P1-02, P1-10, P1-11, P1-12
  - review: P2-03, P3-01, P3-02, P3-09, P3-10, P3-11, P4-09
  - in-progress: P1-01, P1-04, P2-01, P4-08 (sprites), P4-10 (icons)
- **Changed (owner requests, in order):**
  - Per-hero item limit per room
  - Godot 4.6.2 now runs headless in the container, plus tests under `tests/`
  - Guard action; 4 skills per class with ally/party support
  - Enemy abilities (basic + 1–3 specials, Tico names) and ailments (sangrado/veneno/aturdido)
  - Curios with key items (`data/curios.json`)
  - Recruiting at the Terminal de Buses with a roster of 8 and a party of 4; 4 new hireable classes; weekly turnover with permadeath; EBAIS healing; save v5
  - Multi-enemy squads with click-to-target
  - Equipment (25 pieces, 1 weapon / 1 armor / 2 accessories, drag-and-drop) and 8 elements with enemy affinities
  - Content rules in AGENTS.md §4, enforced by `validate_data.py`
- **Verified:** `validate_data.py` 0 errors. Godot 4.6.2 headless: `tests/smoke_expedition.gd` (3 full expeditions with squads, guard, support skills, targeting; 0 failures, no script errors), `test_guard`, `test_status`, `test_hub` (19), `test_equipment` (17) all pass.
- **Not verified / risks:** Visual layout was not seen by a human (headless only), especially the new hub columns, the hero-panel equipment row and drag-and-drop feel. Fights are long (~100 hero turns per expedition in the smoke test), so balance is needed (P5-02).
- **Art in progress:** item icons (37), then the campesino sprite **sheet** (all 6 poses in one image so outfit and weapon match). Then run `python tools/sd_sprites.py` for the other 22 characters (~10 min each on CPU; resumable).
- **Decisions needed:** none open
- **Next step:** Review the campesino sheet. If consistent, run the full sprite batch in ≤2 h chunks. Owner: play in Godot and report layout issues.

---

## 2026-11-07 — P4-05, P2-06, P3-09, P4-07/09, P4-08 — Expedition overhaul + battle sprites
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** P4-05 review · P2-06 review · P3-09 review · P4-07 done (folded into P4-09) · P4-09 review · P4-08 in-progress (sprite batch running)
- **Changed:**
  - Export-safe texture loading + GDScript warning fixes (P4-05)
  - `scripts/domain/map_generator.gd` + `sotanos.json` generator block: random grid dungeons, boss (Mayordomo) in the farthest dead end. `tools/preview_map.py` mirrors it in Python for checks/previews.
  - `data/items.json` (11 Tico items), inventory/save v4 in `GameState`, Pulpería in the hub, `scripts/domain/item_effects.gd`
  - **New `scenes/expedition/expedition_screen.tscn`** replaces `expedition_map` + `combat_scene`. It holds the stage (party + enemies in place), the hero card bottom-left (follows the turn; click a hero to view), the map/inventory bottom-right (tabs, M/I keys, arrows/arrow keys/click to move), and event panels over the stage. Combat rules moved to `scripts/combat/combat_controller.gd` (logic unchanged).
  - `scripts/autoload/game_state.gd`: blank lines inside functions removed (parse tree verified identical)
  - Sprites: `tools/sd_sprites.py` now uses OpenPose skeletons (ControlNet) per state for humanoids; beasts use img2img only. Sprite style drops candlelight.
- **Verified:** `validate_data.py` 0 errors; every `.gd` parses with gdtoolkit (`gdparse`); generator rules checked over 3000 seeds in the Python mirror.
- **Not verified / risks:** **Nothing here was run in Godot** (this container can't download it). Expect small runtime errors on first run; the newest code is the expedition screen. New scripts have no `.uid` files yet; Godot creates them on open, so commit those. If every hero dies, the hub has no way to recruit (P3-02).
- **Decisions needed:** none
- **Next step:** Owner runs the game and sends any red errors from Debugger → Errors. The agent fixes them first. Then continue the sprite batch (`python tools/sd_sprites.py` resumes; see P4-08) and generate item icons (P4-10).

---

## 2026-11-07 — Owner in-game check (no task change)
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** unchanged. P4-03b/c stay `review` until the owner approves the art.
- **Verified by owner in Godot 4.7.2** (not 4.6 as the docs say; project still opens fine):
  - The hub loads, the dropdown shows only Sótanos (P2-07 works), and the new hub background shows
  - The expedition map shows the new background and icons
  - Combat shows the Espanto art and hero portraits (Tecnólogo) correctly
  - Debugger: 0 errors and 13 warnings. They are 4 harmless unused-parameter warnings plus 9 "Loaded resource as image file, this will not work on export".
- **Changed:** `docs/12-phase-plan.md`: new tasks P4-05 (export-safe texture loading + warning cleanup) and P4-06 (map icons too small at 40 px)
- **Decisions needed:** none
- **Next step:** **P4-05** is a quick win (~5 small edits) and prevents a broken export. Then **P1-02** (multi-enemy squads) in `scripts/combat/combat_scene.gd`.

---

## 2026-11-07 — P4-03c — Art fixes
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** P4-03c: review
- **Changed:**
  - `tools/sd_local.py`: `--try-seeds N --preview-dir DIR` writes candidates (seed, seed+1, …) outside `assets/`. There's an optional per-asset `post` (brightness/contrast).
  - `tools/art_manifest.json`: new subjects/seeds for the 6 fixed assets; map icons get `post` brightening
  - `assets/`: segua_boss, rata_de_troje, nuboso_spectre, duende_sotano, campesino, medica_josefina, and all 6 map icons regenerated (metadata updated)
- **Verified:** `python3 tools/validate_data.py` → 0 errors. I picked each image by eye from 3 candidates (6 for rats and campesino).
- **Not verified / risks:** Not checked in Godot. Picked images were copied from previews, so their metadata timestamps are preview times; the seeds match the manifest.
- **Decisions needed:** Owner to look at the art in-game and approve or list further fixes.
- **Next step:** Start **P1-02** (multi-enemy squads): open `scripts/combat/combat_scene.gd` and replace the single `_enemy` dict with an `_enemies` array.

---

## 2026-11-07 — P2-07, P2-04 (roster), P4-03a/b — Bosque hidden, roster approved, slice art generated
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** P2-07: done · P2-04: roster checkbox done (data still todo) · P4-03a: done · P4-03b: review · P2-03: portrait checkbox done
- **Changed:**
  - `scripts/autoload/game_state.gd`, `scripts/hacienda/hacienda_hub.gd`: hub picker reads `GameState.PLAYABLE_REGIONS` (Sótanos only); saves pointing at Bosque fall back to Sótanos
  - `docs/05` §2.6: approved Sótanos roster with data ids
  - `tools/sd_local.py` + `tools/art_manifest.json`: batch art generation with diffusers, model `Lykon/dreamshaper-8` (CreativeML OpenRAIL-M, commercial use OK). Runs on CPU at about 95 s per 512² image.
  - `tools/sd_export.py`, `.cursor/rules/stable-diffusion-assets.mdc`, `docs/11`: one style source (the manifest); prompts no longer name an existing game
  - `assets/`: 32 generated images with `.metadata.json` (8 portraits, 15 enemies, 6 map icons, 3 backgrounds), replacing all placeholders
  - `tools/validate_data.py`: checks the art manifest
- **Verified:** `python3 tools/validate_data.py` → 0 errors, 0 warnings. I reviewed every image by eye through contact sheets.
- **Not verified / risks:** Godot was not run (the binary download was blocked in this container), so the Bosque-hiding GDScript change and the new images are untested in-engine. Risk is low: the change is small, and the images are plain PNGs at the old paths/sizes, except map icons, which are now 128 px instead of 64 (displayed at 40 px).
- **Decisions needed:** Owner to review art (P4-03b). The known misses are listed in P4-03c.
- **Next step:** Start **P1-02** (multi-enemy squads): open `scripts/combat/combat_scene.gd` and replace the single `_enemy` dict with an `_enemies` array. Owner should also open the game once on Windows to confirm the hub still loads (P2-07 change) and to look at the new art.
- **Agent setup for art in a fresh container:** `python3 -m venv <scratch>/sdenv`, then `pip install --index-url https://download.pytorch.org/whl/cpu torch`, then `pip install diffusers transformers accelerate safetensors pillow`, then `python tools/sd_local.py --only <id>`.

---

## 2026-11-06 — P0-01 follow-up — Owner decisions recorded
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** no task status changes
- **Changed:** `docs/12-phase-plan.md` (P2-03, P2-04, P2-05 notes)
- **Verified:** `python3 tools/validate_data.py` → 0 errors (docs-only change)
- **Not verified / risks:** none (no code changed)
- **Decisions made:**
  1. Slice classes 5–8 = Guachimán Jubilado, Médica Josefina, Curandero Nicoyano, Exorcista de Barrio. ✅
  2. El Mayordomo Hundido = Sótanos final boss, fought at objective node `n9`. ✅
- **Decisions needed:**
  1. Bosque region: keep in slice, hide, or debug-only? (P2-07, still open)
  2. Per-region enemy lists don't exist in the docs. Only families (`05` §2) and bosses (§3) do. P2-04 now starts by drafting the Sótanos roster for owner sign-off.
- **Next step:** Unchanged. Start **P1-02** (multi-enemy squads) in `scripts/combat/combat_scene.gd`, or **P1-01** first if Godot is available.

## 2026-11-06 — P0-01 — Handoff protocol + agent-sized phase plan
- **Agent / branch:** Claude Code (cloud) / `betomm/sleepy-ramanujan-78dwh9`
- **Status after session:** P0-01: done
- **Changed:**
  - `AGENTS.md` (+ `CLAUDE.md` import, `.cursor/rules/agent-handoff.mdc`): start/work/end-of-session rules
  - `docs/12-phase-plan.md`: status snapshot plus phases P0–P5 with task IDs, deps, specs, acceptance
  - `docs/HANDOFF.md`: this log
  - `tools/validate_data.py`: JSON cross-reference and reachability checks; warns on PNGs without SD metadata
  - `docs/README.md`, `README.md`: links
- **Verified:** `python3 tools/validate_data.py` → 0 errors, 19 warnings (all placeholder PNGs lack `.metadata.json`)
- **Not verified / risks:** No Godot in this container, so the game was not launched. No game code was changed.
- **Decisions needed:**
  1. Bosque region: keep in slice, hide, or debug-only? (P2-07)
  2. Classes 5–8 for the slice: the proposal in P2-03 is Guachimán, Médica Josefina, Curandero Nicoyano, Exorcista. OK?
  3. The Mayordomo Hundido is a regular fight at Sótanos `n7`, but `05` makes him the Sótanos apex boss. P2-05 assumes the doc wins.
- **Next step:** Start **P1-02** (multi-enemy squads). Open `scripts/combat/combat_scene.gd` and replace the single `_enemy` dict with an `_enemies` array. Do **P1-01** first instead if the session has Godot available, because tests make every later task safer.
