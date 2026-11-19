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

## 2026-11-19 (8) — Event results in a card dialog
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** UX fix on P2-01/P2-02 events (no new task).
- **Changed:** `expedition_screen.gd`:
  - Curio and trap results (outcome lines, trap disarm or careful pass) show in a dialog styled like the hub's card dialogs: event name as title, the outcome text, then each effect, green ▲ good / red ▼ bad / neutral. `_result_tone` reads stress and Luz the right way round.
  - Exploring waits until "Continuar"; an ambush starts its fight after it.
  - The log still records everything.
  - `results_modal` is off in headless `-s` runs (tests and bots press event buttons themselves); `test_ui` turns it on and checks it ("Event result card").
- **Verified:**
  - `validate_data.py`: 0 errors.
  - Smoke test and all 19 tests: 0 failures.
  - Screenshot at 1080p.
- **Not verified / risks:** camp events and hunger stops still report in the log only (they have their own panels).
- **Decisions needed:** none.
- **Next step:** owner playtest.

---

## 2026-11-19 (7) — Item cards say what every item does; sharper item icons
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** fix on the P4-12/P4-14 item card (no new task).
- **Changed:**
  - `GameState.item_tooltip_parts` now describes every consumable effect: "Cura N PV", "Quita N de estrés", "Daño A–B de <elemento> a un enemigo", stun/status chance on enemies, buffs with their numbers, "Luz +N", the guaro's risk, "Sirve en: <curio>", what the Lentes show, and "Se usa en un aliado / toda la cuadrilla / un enemigo". Before, heal, stress, damage, light and risk were never shown.
  - `validate_data.py` rejects effect keys the card doesn't describe (`ITEM_EFFECT_KEYS`) and usable items with nothing to describe.
  - `test_hub` checks that no card is silent.
  - Item card icon 52 → 84 (the icons are 128 px: about 1:1 at 1080p), with a mipmap filter.
  - `project.godot` `[importer_defaults]` texture mipmaps on (new imports only; `.import` files aren't in git).
- **Verified:**
  - `validate_data.py`: 0 errors.
  - `test_hub`, `test_equipment`, `test_combat_items`, `test_ui`, `test_expedition_systems`, `test_town_events`: 0 failures.
  - Screenshot of 9 cards at 1920×1080.
- **Not verified / risks:** existing imports on the owner's machine keep no mipmaps until reimported. The 1:1 size is what makes the card sharp.
- **Decisions needed:** none.
- **Next step:** owner playtest.

---

## 2026-11-19 (6) — P4-21 — 1080p pass: whole-game scaling, bigger fighters, glow targeting
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P4-21 `review` (owner to play at 1080p).
- **Changed:**
  - `project.godot`: stretch mode `canvas_items`, aspect `expand`. The game is still designed at 1280×720 and scales ×1.5 at 1080p with crisp text; wider windows get extra room.
  - `battle_unit.gd`:
    - heroes in a 160×262 box (was 140×210; the hero row has separation −12 so they overlap a little);
    - enemies keep their portraits as 146×146 framed squares, bottom-aligned with the heroes (owner: don't cut them out);
    - the coloured line under a unit is gone. Instead heroes get an outline shader along their silhouette (the material is set only while glowing) and enemies a glowing frame. Gold = acting, red = enemy target / pickable enemy, green = pickable ally.
  - `combat_controller._refresh_markers` now clears `set_active` on enemies that stopped acting (the old line hid this).
  - Expedition screen: stage taller (bottom panel 250 → 212), portrait 124×180, map column 470 → 390, log 13 pt, skill icons 46 → 52 (9 fit at full size).
  - Tried and dropped: cutting enemies out of their portraits (owner asked to keep the portraits).
- **Verified:**
  - `validate_data.py`: 0 errors.
  - Smoke test and all 19 tests: 0 failures.
  - Screenshots at 1920×1080 of the battle (turn, targeting) and the hub.
- **Not verified / risks:**
  - Other screens (victory, camp, events) were not looked at in 1080p, but they scale the same way.
  - A shader detail: in Godot 4 a canvas shader's `COLOR` already includes the texture. Multiplying the texture in again made sprites faint.
- **Decisions needed:** none.
- **Also (same day):** town roster rows are more compact so the 4 party heroes fit without scrolling.
  - Each row: portrait | name and numbers over a small line (EBAIS, Despedir, Cuadrilla) | ↑↓ stacked on the right.
  - Title "Héroes N/8 · cuadrilla N/4"; the position-order hint is in its tooltip.
  - Tests that dig into rows now use `row.get_child(0).get_child(1).get_child(0)` for the name button.
- **Next step:** owner playtest at 1080p.

---

## 2026-11-19 (5) — P4-20 — Dev menu; bigger alforja
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P4-20 `done`.
- **Changed:**
  - Dev menu, debug builds only: a DEV button in the town banner, or F12.
    - "Plata infinita": `GameState.dev_infinite_money`; the `colones` setter holds `DEV_MONEY` = 999999; not saved.
    - "Pasar a la semana N ya": `dev_skip_week()` = `end_of_expedition_week(false)` + `draw_town_event()`, the same week change as coming back. With no expedition, everyone rests at home and nobody gets expedition quirks.
    - "+1 Resolución" per hero (`dev_add_resolve`, through `ResolveSystemScript.grant_xp` + `recompute_stats`).
  - Town alforja: 6 columns of 56×58 cells (was 8 × 44×48).
  - The `AGENTS.md` repo facts don't mention the dev menu; the plan does (P4-20).
- **Verified:**
  - `validate_data.py`: 0 errors.
  - Smoke test and all 19 tests: 0 failures (`test_hub` has 6 new dev checks).
  - Screenshots.
- **Not verified / risks:** the dev menu is visible whenever the game runs from the editor or a debug export. Release exports hide it.
- **Decisions needed:** none.
- **Next step:** owner playtest.

---

## 2026-11-19 (4) — P4-18 fix — sell mode no longer pushes the roster off-screen; bigger shop tiles; faster tooltips
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P4-18 `review`.
- **Changed:**
  - The owner's sell mode at the Pulpería/Taller widened the right panel off-screen: the alforja title was one long line. It now wraps (`PackTitle` autowrap), with shorter text.
  - Shop tiles 60×72 → 84×100, price 13 pt (`scripts/ui/shop_slot.gd`).
  - Tooltips appear after 0.15 s instead of Godot's 0.5 s (`project.godot` `gui/timers/tooltip_delay_sec`; game-wide).
- **Verified:**
  - `validate_data.py`: 0 errors.
  - `test_hub`, `test_ui`, `test_equipment`, `test_town_events`: 0 failures.
  - Screenshots of both shops in sell mode: right panel inside the window.
- **Not verified / risks:** a 0.15 s delay may make tooltips pop while the mouse just passes over the town and the battle bar.
- **Decisions needed:** none.
- **Also (same day):** scroll bars were invisible game-wide: the theme's styleboxes had no content margin, so the bar had no width. `ui_theme.gd` now draws them 10 px wide (`SCROLL_WIDTH`); the shops (and every other list) show a bar when they overflow.
- **Also (same day):** in the Taller the equipment section (hero strip, help, 4 slots) folds away so the shop has room (owner request).
  - It starts closed, as a "▸ Equipo de X" bar.
  - Clicking a hero on the right opens it for that hero; clicking the same hero again closes it; the bar or its ✕ toggles it.
  - `_equip_open`, `_refresh_equip_fold` in `hacienda_hub.gd`; 5 checks in `test_ui`.
- **Also:** Terminal candidates are card rows with everything in the row (owner: "the info in the row, not in a tooltip"): portrait, name, class, resolve, PV / speed / protection / ideal positions, skill icons (hover: the skill card) with their names, quirk chips, and a "Contratar" button on the right (`_recruit_row`).
- **Next step:** owner playtest.

---

## 2026-11-19 (3) — P5-09 — Long campaigns: Veterano and Campeón sized for the party that arrives
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P5-09 `done`.
- **Changed:**
  - `data/progression.json`: Veterano 1.5/1.4/1.7 → 1.15/1.1/1.3; Campeón 2.0/1.7/2.0 → 1.6/1.4/1.65 (enemy PV / damage / stress).
  - Doc 01 §6.1 table + why; doc 09 §8; `docs/playtests/2026-11-19-p5-09.md`.
  - A bot change (bench heroes at 100 stress) was tried and reverted; see the playtest notes.
- **Verified:**
  - 24-week bot runs, 6 seeds, 18 campaigns: 69% cleared overall, Veterano 70%, Campeón 63%, 0.14 deaths per expedition, money in 4544 / out 4448 a week.
  - `validate_data.py`: 0 errors.
  - Smoke test and all 19 tests: 0 failures.
- **Not verified / risks:**
  - Aprendiz reads 69% across long campaigns because it includes rebuilt parties after a failed promotion (91% for fresh campaigns).
  - Parties started at a tier (P5-08 method) will now find Veterano/Campeón easier than the bands.
  - One campaign banked 56k ₡ by week 24 while farming Campeón: watch Campeón pay (×2.5).
- **Decisions needed:** none.
- **Next step:** owner playtest of all three tiers (this branch). Then pick from P3-05 (Taller upgrades + Feria Nocturna), P4-02 (tooltips) or P4-04 (audio).

---

## 2026-11-19 (2) — P5-08 — All three difficulty tiers in the owner's bands
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P5-08 `done`. New `todo` P5-09: 24-week runs.
- **Changed:**
  - `data/progression.json` enemy PV / damage / stress: Aprendiz 0.8 / 0.8 / 0.95, Veterano 1.5 / 1.4 / 1.7, Campeón 2.0 / 1.7 / 2.0.
  - Doc 01 §6.1 table, doc 09 §8, `docs/playtests/2026-11-19-p5-08.md`.
  - Tests `test_progression` and `test_town_events` compare tiers instead of the old fixed values.
- **Correction to P5-07:** it aimed Aprendiz at 55–70%, copying the task text. The owner's bands are per tier (85–90 / 70–80 / 55–70; doc 09 §6, plan "Clear rate for the careful bot").
- **Verified:**
  - Bot runs: Aprendiz 91% (6 seeds, fresh campaigns), Veterano 80% and Campeón 63% (4 seeds each, tier-start runs as in P5-02f); deaths 0.05–0.18 per expedition.
  - Fresh campaigns: money in 3765 / out 3971 a week, never under 500 ₡.
  - `validate_data.py`: 0 errors.
  - Smoke test and all 19 tests: 0 failures.
- **Not verified / risks:** parties that reach Veterano inside an 8-week campaign cleared 7 of 22 there (fewer ranks and less gear than the tier-start parties); see P5-09.
- **Decisions needed:** should the careful bot (and the hint to players) wait for more ranks or gear before moving up to Veterano?
- **Next step:** owner playtest. Then P5-09: run `tools/playtest_campaign.gd -- --campaigns 3 --weeks 24 --seed 1..6 --telemetry <path>` and look at time spent per tier and clear rate after promotion.

---

## 2026-11-19 — P5-07 — Rebalance after the merge: 26% → 58% cleared
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P5-07 `done`. New `todo` P5-08: Veterano/Campeón.
- **Changed:**
  - `data/progression.json` Aprendiz: `enemy_hp` 1.1 → 1.0, `enemy_dmg` 1.2 → 1.0, `enemy_stress` 1.5 → 1.15.
  - `data/balance.json`: `hub.heal_cost_per_hp` 15 → 12, `hub.idle_stress_relief` 15 → 20.
  - `docs/playtests/2026-11-19-p5-07.md` (method, table, raw seed-1 output); doc 09 §8.
- **Verified:**
  - Bot campaigns, 6 seeds × 3 campaigns × 8 weeks = 144 expeditions per setting. Baseline 26% → final 58% cleared; deaths 0.33 → 0.19 per expedition; money in 2946 / out 3118 a week; weeks under 500 ₡ 31 → 7.
  - `validate_data.py`: 0 errors.
  - Smoke test and all 19 tests: 0 failures.
- **Not verified / risks:**
  - Two-seed runs swing by ±15 points (broke campaigns snowball), so judge balance changes on 6 seeds.
  - Failures are all bot retreats: about half are long Mayordomo fights (two escorts + two summons, 10–17 rounds), half a death in an early fight.
  - Veterano/Campeón are untouched (P5-08).
- **Decisions needed:** none. The rest-at-home question from entry 11 is settled by this pass: it stays, at 20.
- **Also:** `tools/playtest_campaign.gd` now reports the roaming mini-boss as its own fight kind (`roaming`, `R` in the fight list): killed, escaped, party retreated, party fell.
  - Veterano run (4 seeds, `--start-level 3 --start-ranks 2 --start-gear 2`): the Cadejo was met 8 times in 35 Veterano expeditions — killed 4, escaped 2 (it flees when round 5 starts), the party retreated 2.
  - The same run shows Veterano too hard (0–22% cleared): P5-08.
- **Next step:** owner playtest of Aprendiz on the new numbers. Then P5-08: run `tools/playtest_campaign.gd -- --campaigns 3 --weeks 24 --seed 1..6 --telemetry <path>`, pool with a script like the one in the P5-07 notes, and tune the Veterano/Campeón rows of `data/progression.json`.

---

## 2026-11-17 (17) — P4-19 — The town painted as one picture
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P4-19 `review`.
- **Changed:**
  - Owner: the buildings looked like "a collage of splattered images, not a town".
  - `tools/town_paint.py` (new):
    - lays out `data/town.json` (backdrop, dirt ground and road, contact shadows, `filler` houses, buildings);
    - repaints it with SD img2img + ControlNet canny (`lllyasviel/sd-controlnet-canny`, strength 0.7, control 1.0, seed 5300);
    - cuts each building out of the painting with its cut-out's alpha (`assets/town/painted/<id>.png` + `layout.json` rects).
    - `--preview-dir/--strengths` for candidates; `--from` keeps one.
  - Hub: draws `town_painted.png` as `Painting` in the town at design scale and places the crops at their exact rects. Without a painting it falls back to the P4-17 cut-outs.
  - `assets/town/filler/`: 4 unused takes, cut out.
- **Verified:**
  - `validate_data.py`: 0 errors.
  - Smoke test and all 19 tests: 0 failures.
  - Town and hover screenshots.
- **Not verified / risks:**
  - Plain img2img at 0.6 made a lovely village but moved and dropped buildings; ControlNet fixed that.
  - Each building's hover outline follows its old cut-out shape, which may differ slightly from the repainted roofline.
  - Moving a building in `data/town.json` now needs a repaint (~10 min on CPU).
- **Decisions needed:** none.
- **Next step:** owner review of P4-17/18/19. Otherwise P5-07.

---

## 2026-11-17 (16) — P4-18 — Only the Taller buys equipment back
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P4-18 `review`.
- **Changed:** owner answered entry 15's question ("yes"): each shop buys back only what it sells.
  - `sell_item(id, shop = "")`: "" sells at the item's own shop; the Pulpería refuses equipment. The bot's default calls keep working.
  - The hub sells at the open shop's window, else at the item's own shop.
  - Pulpería texts, `AGENTS.md` selling rule, doc 02, `test_hub` updated.
- **Verified:**
  - `validate_data.py`: 0 errors.
  - Smoke test and all 19 tests: 0 failures.
- **Not verified / risks:** not played by hand.
- **Decisions needed:** none.
- **Next step:** owner review of P4-17/P4-18. Otherwise P5-07.

---

## 2026-11-17 (15) — P4-18 — Equipment at the Taller, consumables at the Pulpería
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P4-18 `review`.
- **Changed:**
  - `GameState.shop_of(id)`: `taller` for equipment, `pulperia` for the rest.
  - `buy_block_reason` checks `<shop>_compra`.
  - `sell_item(id, shop = "pulperia")`: the Pulpería still buys anything; the Taller only equipment; closure `<shop>_venta`.
  - Hub: the Taller page has the equipment shop (filters Todo / Armas / Armaduras / Accesorios, Vender, drop to sell) under the equipment slots. The Pulpería shows consumables only. One sell mode shared by both `Vender` buttons; selling from the alforja goes to whichever of the two windows is open.
  - Town events:
    - "La pulpera anda de buenas" (first accessory −80%) is now "El herrero anda de buenas"; the id `guino_de_la_pulpera` is kept for saves.
    - "Corte de luz" also closes `taller_venta`.
    - Price lines say Taller for equipment.
  - Validator accepts `taller_compra` / `taller_venta`.
  - `AGENTS.md` shop rule; doc 02 town table.
- **Verified:**
  - `validate_data.py`: 0 errors.
  - Smoke test and all 19 tests: 0 failures.
  - Screenshots of both shops.
- **Not verified / risks:** the playtest bot buys gear through `GameState.buy_item` (unchanged), so it still works.
- **Decisions needed:** the Pulpería still buys equipment back (the old rule "buys any item"). Should only the Taller buy equipment?
- **Next step:** owner review of P4-17/P4-18. Otherwise P5-07.

---

## 2026-11-17 (14) — P4-17 fix — town art loads before Godot has imported it
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar` (→ `main`)
- **Status after session:** P4-17 `review`.
- **Changed:** `hacienda_hub.gd` `_load_texture`. The owner opened `main` and saw no buildings: `*.import` is in `.gitignore`, so new PNGs are invisible to `ResourceLoader` until the editor imports them. The hub now falls back to `Image.load_from_file` (and warns if a file is missing).
- **Verified:**
  - `validate_data.py`: 0 errors.
  - `test_ui`, `test_hub`, `test_quirks`, `test_hub_activities`, `test_town_events`: 0 failures.
  - Town screenshot with every `.import` removed: all buildings and the backdrop show.
- **Not verified / risks:** an exported build needs the PNGs imported (the editor does this on export).
- **Decisions needed:** see entry 13.
- **Next step:** owner review of P4-17. Otherwise P5-07.

---

## 2026-11-17 (13) — P4-17 — Town view: clickable buildings, Darkest Dungeon style
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P4-17 `review` (owner to look at the screenshots / play the hub).
- **Changed:**
  - `hacienda_hub.tscn`: rebuilt. Painted town (`Town`), top-left banner (week, town event), roster and alforja on the right, bottom bar (colones, region, difficulty, Pura Vida, start, quit), and a building window (`Building`) with one page per building.
  - `hacienda_hub.gd`: new node paths; `_build_town` / `_layout_town` / `_refresh_town`, `open_building` / `close_building` (Esc closes), `_refresh_who` (hero strip on the per-hero pages).
    - Iglesia and Cantina are separate pages (`_relief_boxes`).
    - The Clínica page lists every hero (`_refresh_clinic_page`).
    - Roster rows are two lines.
  - `town_building.gd` (new): picture with alpha hit-test, hover outline shader, name plate, grey when closed.
  - `data/town.json` (new): positions, texts, `closed_by` / `note_by`; checked by `validate_data.py`.
  - Art: `assets/town/` (7 buildings + `town_bg`), new manifest entries.
  - `tools/sd_cutout.py` (new): UperNet scene parsing, built into transformers. BiRefNet was dropped because it needs `trust_remote_code`.
  - Tests updated (`test_ui` "Town view", `test_hub_activities`, `test_quirks`); `tools/screens/town_screenshot.gd` (new); `clinic_screenshot.gd` adapted.
  - `docs/02` §1 town view; `AGENTS.md` UI note.
- **Verified:**
  - `validate_data.py`: 0 errors.
  - Smoke test and all 19 tests: 0 failures (`test_ui` 3 runs in a row).
  - Screenshots: town, hover, and the 7 windows.
- **Not verified / risks:**
  - Not played by hand in a window.
  - The art is SD output: the terminal bus lost its lamppost in the cutout, and the Taller keeps a dark edge on its right.
  - Feria Nocturna, Guardabosques and Mejoras have no building (not built yet).
  - Other `tools/screens/*` hub tools (relief, skills, tooltip) still run but were made for the old two-column layout.
- **Decisions needed:**
  - The EBAIS stays a button on each roster row rather than a building. OK?
  - The Taller is where heroes are equipped (no upgrades exist yet). OK?
- **Next step:** owner review of P4-17. Otherwise P5-07 (see entry 11).

---

## 2026-11-17 (12) — P4-16 — Skill tooltips stay up during a fight
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P4-16 done. P4-17 (town view) claimed, `in-progress`.
- **Changed:**
  - `expedition_screen.gd`: the combat action bar is no longer freed and rebuilt each turn. `_bar_button` refills the same SkillButtons in place, and `_lock_skills` disables them after a hero acts instead of clearing them. A hovered button stays alive, so its tooltip doesn't close when another unit acts.
  - `skill_button.gd`: `setup` can be called again (it replaces the icon and pips); `action` is the click callable and is ignored while the button is disabled.
- **Verified:**
  - `validate_data.py`: 0 errors.
  - Smoke test and all 19 tests: 0 failures.
  - `test_ui` has a new "Combat bar" section (same nodes after acting, locked, reused next turn); it passed 15 runs in a row.
- **Not verified / risks:** not hovered by hand in a windowed game. A tooltip that is open when the next hero's turn starts shows the old skill until the mouse moves.
- **Decisions needed:** none.
- **Next step:** P4-17 (town view), see the plan.

---

## 2026-11-17 (11) — Merge measured; main updated
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar` (= `main`)
- **Status after session:**
  - `main` holds both lines of work (fast-forward to `132acb2`, then this entry).
  - New `todo` P5-07: rebalance after the merge.
- **Verified:**
  - Smoke test and all 19 tests: 0 failures.
  - Bot measurement on the merged game (48 expeditions, seeds 1 and 2), success / retreats / deaths:
    - first run: 19%, 39 retreats, 0.38 deaths;
    - after the bot books heroes at 60+ stress into the Iglesia/Cantina before picking the party (free recruits fill the gaps): **29%**, 34 retreats, 0.29 deaths.
  - Party stress at departure is 35–57.
  - Money: about 2.0k in and 2.4k out a week; some campaigns end at 0–330 ₡.
- **Not done:**
  - **Deleting the merged remote branches:** this session's GitHub access returns 403 on branch deletion. Every `betomm/*` branch has 0 commits outside `main`. The owner can delete them with `git push origin --delete betomm/amazing-clarke-lv3whd betomm/happy-faraday-5yrmcr betomm/sleepy-ramanujan-78dwh9 betomm/tender-brown-x04ghq betomm/vigilant-babbage-jovigc`, and later `claude/p3-03-followup-48gkar`.
  - **Rebalancing:** see P5-07.
- **Decisions needed:** "rest at home" (15/week) stays pending.
- **Next step:** P5-07. Start from `data/progression.json` (Aprendiz `enemy_stress` 1.5) and the support skills' `stress_relief` in `data/skills.json`. Measure with `tools/playtest_campaign.gd -- --campaigns 3 --weeks 8 --seed 1/2 --telemetry <path>` and `tools/telemetry_report.py`.

---

## 2026-11-17 (10) — Merge — happy-faraday (P5-02a–f, P5-04, P5-05) + this branch into main
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar` → `main`
- **Status after session:** both lines of work are on `main`. P2-11 is `cut` (done as P5-04). My P5-02 pass is superseded (plan note; doc 09 §7).
- **What happened:**
  - The owner asked to merge pending work to `main`.
  - `betomm/happy-faraday-5yrmcr` (22 commits, 14–15 Nov) and this branch (32 commits, 16–17 Nov) had grown from the same `main`. They conflicted in 15 files.
  - The owner chose "merge both, reconciled".
- **Reconciliation:**
  - **Kept from happy-faraday:**
    - the P5-02a–f numbers: difficulty table with `enemy_stress`, lower relief on support skills, dragging-fight stress (`combat.drag_*`);
    - P5-04 retreat from a fight (`combat.retreat_*`, `tests/test_retreat.gd`);
    - free recruits (owner 2026-11-15), the Darkest Dungeon XP curve, two provision kits;
    - its campaign bot and `sim_policy.gd`.
  - **Kept from this branch:**
    - Iglesia/Cantina, quirks and the Clínica (week-long stay), enemy gimmicks and bosses, 36 room events, choice-event conditions;
    - telemetry, the UI theme and cards, lone-survivor rule, `hub.idle_stress_relief`.
  - **Dropped:**
    - my `combat.enemy_stress_pct` and `combat.long_fight_*` (their per-difficulty stress and drag rule do the same);
    - my difficulty numbers;
    - the EBAIS back at 15 ₡/PV.
  - **Adapted:**
    - the campaign bot books the Iglesia/Cantina instead of misas (the group misa has been gone since 2026-11-16) and skips busy heroes; `--telemetry` added back;
    - the provisions card shows both kits;
    - recruit card buttons show "gratis";
    - enemies get `stress_mult` in `make_enemy`.
  - **Save version 12:** v10 now also covers their XP-curve floor. All migrations are "fill missing fields", so any older save loads.
  - **Tests:** `test_retreat` now measures retreat stress from the hero's turn (bigger squads let enemies act first). `test_ui` updated for the new provisions dialog.
- **Verified:**
  - `validate_data.py`: 0 errors.
  - Smoke test and all 19 tests (AGENTS list + `test_retreat`): 0 failures, no `SCRIPT ERROR`.
  - Post-merge bot measurement: see the next entry or the commit.
- **Not verified / risks:**
  - No human play of the merged game.
  - happy-faraday's numbers were tuned with misas available; resting at home and the Iglesia/Cantina replace them, so their stress balance may have shifted. See the measurement.
- **Decisions needed:**
  - "Rest at home" (15 stress a week, free): keep?
  - The open items in happy-faraday's last handoff (P5-06 blocked; Veterano/Campeón bands) still stand.
- **Next step:** owner plays a campaign on `main`. Then P5-06 (see happy-faraday's 2026-11-15 (4) entry below) or P3-05 (Taller + Feria).

---

## 2026-11-17 (9) — P5-02 — First balance pass
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P5-02 `review` (first pass; deaths still above target). New `todo` P2-11 (retreat from a fight).
- **Changed:** full write-up with the 8 iterations in doc 09 §6.
  - **`balance.json`:**
    - new `combat.enemy_stress_pct` 35;
    - new `combat.long_fight_from` 14 / `long_fight_stress` 3 (code in `combat_controller.gd`);
    - `hub.heal_cost_per_hp` 15 → 20;
    - new `hub.idle_stress_relief` 15: `end_of_expedition_week` takes 15 stress off anyone home all week without a booking.
  - **`progression.json`:** Veterano enemy HP ×1.15 and damage ×1.06 (were 1.22/1.12); Campeón ×1.35 / ×1.15 (were 1.46/1.24). Sótanos rewards end where they started.
  - **Bots:**
    - `playtest_campaign.gd` retreats a breaking party (2 Quebrantos or a hero at `RETREAT_STRESS` 150) and leaves frayed heroes home;
    - `sim_policy.gd` finishes the last or a weak enemy before support and calms at 70 (it used to calm forever while a boss sat at 10 PV).
  - **Validator:** new keys added.
- **Verified:**
  - `validate_data.py`: 0 errors.
  - Smoke test and all 18 tests in the AGENTS list: 0 failures, no `SCRIPT ERROR` (`test_progression` was updated for the new Veterano HP).
  - 8 measurement runs (24 or 48 expeditions each). The final numbers are iteration 6's, 48 expeditions:
    - success 71% (Aprendiz 91%, Veterano 31%);
    - deaths 0.52 per mission;
    - about 1 Quebranto/Virtud per mission;
    - about 3.5k ₡ in and 3.6k ₡ out per week.
  - Combat sim on the final data: boss cleared 97.3%, 0 stalls.
- **Not verified / risks:**
  - The bot is not a human: it ignores gear and town-event offers.
  - The system has strong feedback loops: 5–10% changes swing success by 15–30 points.
  - Iteration 6's exact numbers weren't re-run after the iteration 7 revert. The data now matches iteration 6.
- **Decisions needed:**
  - Approve "rest at home" (15 stress per week without paying). It's new: Darkest Dungeon has no such thing. It was added to stop broke campaigns spiralling.
  - Accept fights that drag (round 14+) costing stress to everyone?
  - The Aprendiz → Veterano jump (91% → 31%): soften a seasoned hero's refusal of easy runs, or keep it?
- **Next step:** P2-11 (retreat from a fight). Add a "Retirarse" action in `scripts/combat/combat_controller.gd` and the expedition action bar, then re-measure deaths with `tools/playtest_campaign.gd -- --campaigns 3 --weeks 8 --seed 1/2 --telemetry <path>`.

---

## 2026-11-17 (8) — P3-19 + P4-15 — Clínica keeps the hero home; menus in the item-card style
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P3-19 `done`; P4-15 `review` (owner to look at the screens).
- **Changed:**
  - **P3-19** (owner: "yes, like the Iglesia and Cantina"):
    - A Clínica treatment keeps the hero home for the rest of the week (`GameState.in_clinic`, `hero_busy`, `busy_place`; `clinic["stay"]`): out of the cuadrilla, can't rejoin or book the Iglesia/Cantina.
    - A hero booked at the Iglesia/Cantina can't be treated, nor can the last free hero.
    - The hub and the bot use `hero_busy`; tests in `test_quirks`.
  - **P4-15 menus** (owner: "make all menus better, including the Clínica, similar to the item tooltips"):
    - `scripts/ui/ui_theme.gd`: one theme in the card palette for buttons (warm wood, gold hover and press), dialogs (opaque card, gold title bar, shadow), dropdown lists, check boxes and scroll bars. `TooltipStyler` puts it on the root window, so every screen gets it.
    - `tooltip_card.gd` gains `chip`, `picture`, `section` and `is_bad_line`. Bullets are red when a line is bad, including "+X% estrés recibido" and "no va a…".
    - `scripts/ui/hero_card.gd` (portrait, resolve and Quebranto/Virtud chips, stats, skills, quirk chips) and `scripts/ui/card_button.gd` (a button with a card on hover).
    - **Hub:**
      - the Clínica is a card: hero header, quirks grouped by kind with coloured edges, tags, effects and priced buttons, the reason under a disabled button, scrolling when long;
      - the town-event card: kind chip, text, "Esta semana" bullets, revive buttons with hero cards;
      - the provisions card: item pictures, prices, total;
      - the dismiss card: hero header, red warning;
      - hover cards on the 6 Iglesia/Cantina activities, the Terminal's candidates and the roster heroes.
    - **Victory screen:** section bars in the card palette.
  - **Tests and tools:** `tests/test_ui.gd` (8 checks: theme, every hover card, every dialog, all 56 town-event cards). `tools/screens/clinic_screenshot.gd` also saves the hover cards and the dismiss card.
  - **Docs:** AGENTS (UI style note, test list), doc 02 §6.
- **Verified:** `validate_data.py` 0 errors; smoke test and all 18 tests in the AGENTS list: 0 failures, no `SCRIPT ERROR`. Screenshots at 1280×720 checked: hub, Clínica, town event, provisions, dismiss, hover cards, trap, camp, victory.
- **Not verified / risks:**
  - No human look yet. Godot only shows tooltips after a hover delay, which the screenshots fake with a mouse event.
  - Expedition-screen panels (trap, curio, camp, hunger) keep their scene cards; they only got the new buttons.
- **Decisions needed:** none.
- **Next step:** owner looks at the hub, then P5-02 (balance to 55–70%). Run `tools/playtest_campaign.gd -- --campaigns 3 --weeks 8 --telemetry <path>` and `tools/telemetry_report.py <path>` for the baseline.

---

## 2026-11-17 (7) — P3-06 — Quirks, diseases and the Clínica de Espantos
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P3-06 `review`.
- **Changed:** details in doc 02 §6 "Built".
  - **`data/quirks.json`** (new): 8 positive, 8 negative, 3 diseases. Each changes combat stats.
    - *Descreído* refuses the Iglesia; *No le entra el guaro* refuses the Cantina (owner 2026-11-16).
  - **`data/balance.json` `quirks`:** gain chances 25/25/8%, caps 5/5, recruit chances 50/50%, Clínica prices by resolve tier (doc 04 §3.5).
  - **`scripts/domain/quirks.gd`** (new): catalog, `mod`, `refusal`, `gain` (replaces an unlocked one at the cap), `roll_after_expedition`, `roll_recruit`, prices and weekly limits.
  - **`StatusEffects.stat`** adds quirk mods.
  - **`GameState`:** quirks rolled at week end for everyone who went (week report lines); recruits roll quirks; refusals in `activity_block_reason`; `clinic_options` / `clinic_treat`; save v12.
  - **Hub:** a "Clínica de Espantos — rasgos de X (n)" button under the Iglesia/Cantina panel opens a card listing each quirk with Quitar / Fijar / Curar and its price. Disabled buttons give the reason in their tooltip. The roster tooltip lists quirks.
  - **Town events:** `clinica` is a service (`closed`, `service_pct`).
  - **Validator:** checks quirks (kinds, stats, refuses; a positive must help and a negative must hurt), the balance keys and the price tables.
  - **Tests:** `tests/test_quirks.gd` (23 checks). `tests/test_hub_activities.gd` now expects the Clínica button in the panel.
  - **Screenshot tool:** `tools/screens/clinic_screenshot.gd`.
  - **Docs:** doc 02 §6, doc 13 (save v12), AGENTS test list.
- **Verified:**
  - `validate_data.py`: 0 errors.
  - Smoke test and all 17 tests in the AGENTS list: 0 failures, no `SCRIPT ERROR`.
  - Screenshot at 1280×720: the card is readable (colors by kind; a locked quirk's Quitar is disabled).
  - Bot run, 2 × 8 weeks with telemetry: 15 of 16 expeditions won; fights won: regular 100%, elite 100%, boss 94%; no `SCRIPT ERROR`.
- **Not verified / risks:**
  - No human play-test.
  - The bot never uses the Clínica.
  - Quirk names and descriptions were checked against doc 08 by the agent only. *Delicadito* and *Desjaretado* are teasing but about behaviour.
  - Treatment is immediate (DD makes the hero busy for the week) and has no slots yet.
- **Decisions needed:**
  - Should Clínica treatments take the hero out for the week, like the Iglesia/Cantina (DD style)?
  - Are the gain chances (25% / 25% / 8% per expedition) right?
- **Next step:** owner play-test of the hub (Clínica, Iglesia/Cantina) and a Veterano run. Then P5-02 (balance to 55–70% success): run `tools/playtest_campaign.gd -- --campaigns 3 --weeks 8 --telemetry <path>` and `tools/telemetry_report.py <path>` for the baseline.

---

## 2026-11-17 (6) — P5-01 — Local telemetry log
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P5-01 `done`.
- **Changed:**
  - **New `Telemetry` autoload** (`scripts/autoload/telemetry.gd`, registered in `project.godot`). It appends JSON lines to `user://telemetry.jsonl`.
    - Every line has `kind`, `t` and `week`.
    - It is off during `-s` runs and rotates to `.1` past 2 MB.
  - **Events:**
    - `session`: the game starts.
    - `mission_end`: logged by the expedition screen via `GameState.log_mission_end`: result, region, difficulty, rooms, ledger, each hero.
    - `stress_spike`: StressSystem `spike_hook` (Quebranto or Virtud at 100, collapse).
    - `week`: `end_of_expedition_week`: colones, in, out, roster, fallen, busy.
  - **Money in and out:** a setter on `GameState.colones` counts every change into `week_colones_in/out`. Save v11 keeps them; loading or starting a campaign resets them.
  - **Bot:** `tools/playtest_campaign.gd -- --telemetry <path>`.
  - **Report:** `tools/telemetry_report.py [path]` prints success by difficulty, heroes lost, stress spikes and a weekly money table. It finds Godot's user folder by itself.
  - **Tests:** `tests/test_telemetry.gd` (11 checks).
  - **Docs:** AGENTS (autoloads, test list, telemetry note), doc 13 (layer table, save v11).
- **Verified:**
  - `validate_data.py`: 0 errors.
  - Smoke test and all 16 tests in the AGENTS list: 0 failures, no `SCRIPT ERROR`.
  - Bot run, 2 × 6 weeks with `--telemetry`, then the report: 27 events.
    - Success 92% (Aprendiz 100%, Veterano 67%), 0.42 heroes lost per mission.
    - 3 stress spikes; the weekly money table filled in.
- **Not verified / risks:**
  - The real game writing the log on the owner's Windows machine was not run (no desktop here); the user-folder path in the report is Godot's documented default.
  - Two campaigns in one file make the week column repeat; the report doesn't separate campaigns.
- **Decisions needed:** none.
- **Next step:** P3-06 (Clínica de Espantos + quirks), as the owner asked. Spec: doc 02 §6 and doc 04 §3.5 (prices).

---

## 2026-11-17 (5) — P2-10 — Conditions for choice events
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P2-10 `done`.
- **Changed:**
  - **`data/curios.json`:** a curio may have `requires` {`after_fight`, `max_light`, `min_light`}, a `fallback` curio and `missing_text`.
    - *Mercado clandestino* needs the room right after a won fight (fallback: Carreta pintada).
    - *Visión del abuelo* needs Luz ≤ 50 (fallback: Retrato del abuelo).
  - **`GameState`:** `rooms_since_fight` (+1 per move, 0 on a won fight via `note_fight_won`), `curio_ready`, `room_curio()`. When the moment has passed, the room becomes the fallback for good, and its label changes.
  - **Expedition screen:** `_open_curio` uses `room_curio()` and narrates `missing_text`; a win calls `note_fight_won()`.
  - **Validator:** checks `requires`; the fallback must exist and have no `requires`; `missing_text` is required.
  - **Tests:** `tests/test_expedition_systems.gd` gets 5 checks. I also fixed a flaky P2-04 check: a curio ambush that rolls a Rata brings its pair, so up to 3 enemies.
  - Doc 07 §5.
- **Verified:** `validate_data.py` 0 errors; smoke test and all 15 tests in the AGENTS list: 0 failures, no `SCRIPT ERROR`.
- **Not verified / risks:** no human play-test. The map shows the event's name before entering, so a player can see *Mercado clandestino* on the map and then find the Carreta.
- **Decisions needed:** none.
- **Next step:** P5-01 (local telemetry log), then P3-06 (Clínica de Espantos + quirks), as the owner asked on 2026-11-17.

---

## 2026-11-17 (4) — P1-09 — Phase 1 signed off
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P1-09 `done`. **Current phase is now P2.** The owner signed off Phase 1 on 2026-11-17.
- **Changed:** `docs/12-phase-plan.md` only (current phase, P1-09).
- **Verified:** docs only; `validate_data.py` 0 errors.
- **Not verified / risks:** P1 tasks still open move along as they are: P1-01 (single test runner, `in-progress`), P1-15 (expedition sim, `todo`), P1-20 (smoke frame-cap flake, `todo`).
- **Decisions needed:** none.
- **Next step:** P2-10 (conditions for choice events), the only `todo` in P2. Open `data/curios.json` and `GameState.curio_options`. Every other P2 task is in `review`, waiting for the owner's play-test.

---

## 2026-11-17 (3) — P1-21 — The last one standing ignores use_ranks
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P1-21 `done`.
- **Changed:**
  - `FormationScript.can_use`: when the user is the only living unit on its side, `use_ranks` is not checked. `target_ranks` still is.
    - It covers heroes (skill bar, sim, bot) and enemies.
    - The validator already guarantees every class has an attack that reaches enemy position 1, so a lone hero can always act.
  - `tests/test_formation.gd`: 3 checks.
  - Doc 01 §2.1 rule.
- **Verified:**
  - `validate_data.py`: 0 errors.
  - Smoke test and all 15 tests in the AGENTS list: 0 failures, no `SCRIPT ERROR`.
  - `sim_combat --runs 300 --chain 3`, seeds 1–3: boss cleared 98.3% / 99.0% / 99.7%; stalls 1 / 0 / 0.
  - The one stall left is not a stuck hero. A lone Abuela at Luz 0 heals herself and keeps hitting a half-dead Mayordomo, who keeps hitting back, until the sim's 40-round cutoff. That's attrition, for balance (P5-02).
- **Not verified / risks:** no human play-test.
- **Decisions needed:** none. The owner confirmed (2026-11-17) that a lone survivor may use any of their skills; recorded in AGENTS.md §4 (Formation) and doc 01 §2.1.
- **Next step:** owner play-tests a Veterano Sótanos run (P2-02, P2-04, P2-05 in review). Otherwise sign off Phase 1 (P1-09) and start P5-02 balance; doc 09 §5 and the 2026-11-17 handoffs list the open numbers.

---

## 2026-11-17 (2) — P2-05 — Mayordomo mechanics and the roaming Cadejo
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P2-05 `review`. New `todo` P1-21 (a lone hero stuck where none of their skills work).
- **Changed:**
  - **Mayordomo** (`data/enemies.json`):
    - `summon`: rings for a Sirviente ahogado on rounds 4 and 7, while fewer than 2 stand, at most 2 per fight;
    - `cycle`: *Pulso de oscuridad* every 4th round;
    - *Golpe al escudo* `vs_guard_pct 50`: targets and punishes a guarding hero.
  - **Cadejo Negro:**
    - `flee_after 4`;
    - `generator.roaming` in `sotanos.json`: 0/50/75% by difficulty, starts in a fight, empty, curio or trap room, moves every 3 party moves (never onto the party), bounty 600–900 ₡ × difficulty reward + one equipment;
    - out of the elite pool (Mandador en pena took its place).
  - **Code:**
    - `CombatController._boss_round_start` (summons and fleeing), the cycle in `_pick_enemy_skill`, anti-guard targeting and damage;
    - `GameState` roaming (`_place_roaming`, `roaming_tick` in `move_to_node`, `build_roaming_context`, `finish_roaming`, `roaming_clears_room`);
    - expedition screen: the encounter, the bounty, and a curio or trap room keeps its event after the fight;
    - `map_view.gd`: a red dot and a tooltip on the Cadejo's room.
  - **Validator:** `summon` (now needs `max_total`), `cycle`, `flee_after`, `vs_guard_pct`, `generator.roaming`.
  - **Tests:** `tests/test_enemies.gd`, +19 checks: summon timing and cap, beat, anti-guard, spawn chance, movement, fight, fleeing, bounty, and the real screen.
  - **`tools/sim_policy.gd`:** a shoved hero with nothing to hit now steps back toward its class's positions. Before, it buffed forever and the fight stalled.
  - **Docs:** doc 05 §3.1 and §3.2 "Built", doc 13.
- **Verified:**
  - `validate_data.py`: 0 errors.
  - Smoke test and all 15 tests in the AGENTS list: 0 failures, no `SCRIPT ERROR`.
  - `sim_combat --runs 300 --chain 3`, seeds 1 and 2:
    - boss cleared 97.3–98.0%, 0–1 stalls, boss fights about 10 rounds;
    - first version, with uncapped summons and a pulse every 3 rounds: 77% and 48 stalls.
  - Bot run, 2 campaigns × 8 weeks: no `SCRIPT ERROR`.
    - 13 of 16 expeditions won.
    - Fights won: regular 98%, elite 94%, boss 85%.
    - Average rounds: regular 8.2, boss 18.2.
- **Not verified / risks:**
  - No human play-test. The map's red dot was not checked visually.
  - Campaign 1 lost weeks 6–8 in a row:
    - After a wipe, the bot kept going to Veterano with fresh level-0 recruits, because a surviving level-3 hero refuses easier runs.
    - The week-8 loss was a 48-round stall with a healer-heavy party (the doc 09 issue).
  - The game is clearly harder now, which is closer to P5-02's 55–70% target, but nobody has tuned it.
  - Infernal shards (doc 05 §3.2 drops) wait for materials (doc 02 §11).
- **Decisions needed:**
  - Is the Cadejo's 50% / 75% chance and its 4-round flee right?
  - The bot campaign's death spiral after a wipe: should a hero's refusal to take easy runs be softer (P5-02)?
- **Next step:** owner play-tests P2-02, P2-04 and P2-05 in a Veterano Sótanos run. Otherwise P1-21 (lone hero stuck; start in `scripts/combat/combat_controller.gd` `skill_usable`), or sign off Phase 1 (P1-09) and start P5-02 balance.

---

## 2026-11-17 — P2-04 — Sótanos enemy gimmicks and authored squads
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P2-04 `review` (the owner asked for it; the plan's current phase is still P1).
- **Changed:** every doc 05 §2.6 gimmick that was missing. The table is in doc 05 §2.6 "Built".
  - **Sombra:** strikes back while marked.
  - **Peón:** grudge against healers, +15% per heal (max 3), and it goes for the healer.
  - **Mandador:** new *Embargo*, which applies the new status *Embargado* (no healing).
  - **Ratas:** come in pairs.
  - **Murciélago:** −3 Luz per hit.
  - **Monaguillo:** new *Bendición torcida* (Chiva on the two in front, `target: allies`).
  - **Vigía:** *Pedrada* marks; alive at round 3, it calls one reinforcement.
  - **Duende:** stolen colones come back when it dies.
  - **Squads:** 4 authored squads in the Sótanos generator, used for 50% of regular fights.
  - **Code:**
    - `GameState.make_enemy` / `expand_packs` (the squad builder now uses them);
    - `CombatController.spawn_enemy` + `enemy_spawner` (screen: `_spawn_enemy_unit`; sim: `SimUnit`), ready for the Mayordomo's summons in P2-05.
  - **Validator:** checks the new enemy fields, `allies` skills and `squads`.
  - **Tests:** `tests/test_enemies.gd` (31 checks, including a reinforcement on the real stage row). `tests/test_formation.gd` now expects the rat pair.
  - **Docs:** doc 05 §2.6, doc 13, AGENTS test list.
- **Verified:**
  - `validate_data.py`: 0 errors.
  - Smoke test and all 15 tests in the AGENTS list: 0 failures, no `SCRIPT ERROR`.
  - `sim_combat --runs 300 --chain 3`: boss cleared 99.7%, 0.07 heroes lost per clear (before: 100%, 0.03).
  - Bot run, 2 campaigns × 6 weeks: 12 of 12 expeditions won, no `SCRIPT ERROR`.
- **Not verified / risks:**
  - No human play-test, and the reinforcement unit was not checked visually (only its place in the row).
  - Fights got longer in the bot run:
    - regular fights average 6.0 rounds (was 4.9);
    - boss fights average 13.2 rounds (was 8.6), the longest 34. This is the Mayordomo without his P2-05 mechanics, plus the Embargo and grudge slowing healer-heavy parties.
  - Watch this in P5-02.
- **Decisions needed:** none new. The Phase 1 sign-off and the doc 09 §5 balance questions are still open.
- **Next step:** P2-05 (the Mayordomo's 3 mechanics + the Cadejo as a roaming mini-boss). Open `scripts/combat/combat_controller.gd` and summon `sirviente_ahogado` with `spawn_enemy()`.

---

## 2026-11-16 (3) — P2-02 — 36 Sótanos room events
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P2-02 `review` (the owner asked for it; the plan's current phase is still P1). New `todo` P2-10 (conditions for choice events).
- **Changed:**
  - `data/curios.json`: 15 new curios (blind table, 8 with a key item) and 7 choice events. Choice events: Caminante perdido, Mercado clandestino, Visión del abuelo, Mesa de dominó, Llanto en el pasillo (La Llorona), Duendes juguetones, Procesión de ánimas.
  - `data/traps.json`: 5 new Sótanos traps (bahareque, corriente negra, cepo, barriles, vapor de cava).
  - `data/regions/sotanos.json`: pools now hold 27 curios + 9 traps = 36. The region pool is the "tag"; there is no `data/events.json` (the plan's Files line predated P2-01).
  - `GameState`:
    - `curio_options` / `pick_curio_option` / `curio_can_leave` (the logic moved out of the screen, so it can be tested);
    - new outcome keys `light` (Luz ±, clamped) and `stress_random` (one hero).
  - `expedition_screen.gd` `_open_curio`: shows the options. Disabled choices carry a tooltip reason. Choice events have no "Dejarlo".
  - `tools/validate_data.py`:
    - choice schema: each curio has a blind table or choices, ≥2 choices, one of them free;
    - every outcome has text;
    - curio ids unique;
    - new keys allowed;
    - Sótanos pools must hold ≥30 events.
  - `tests/test_expedition_systems.gd` `_test_room_events`: all 99 Sótanos outcomes apply; light clamps; stress_random; item and colones costs; key item only when carried; the screen lists the choices without Dejarlo.
  - Docs: doc 07 §5 and §5.1 (the pool), doc 13 (curio flow).
- **Verified:**
  - `validate_data.py`: 0 errors.
  - Smoke test and the whole AGENTS test list: 0 failures, no `SCRIPT ERROR`. The new `_test_room_events` has 13 checks.
  - Bot run, 2 campaigns × 6 weeks: no `SCRIPT ERROR` and no stuck room.
    - 11 of 12 expeditions won.
    - The one loss was a 74-round fight at Veterano with a healer-heavy party (2 Abuelas), the stall already noted in doc 09 §5, not a room event.
- **Not verified / risks:**
  - No owner read of the Spanish text. I checked it against doc 08: folklore figures (Llorona, duendes, ánimas) are treated as characters with rules, and the jokes are about situations. Robbing the peón costs stress.
  - Balance is a first guess. Blind outcomes are roughly 50/50 good and bad, as before.
  - The bot presses the first choice of a choice event.
- **Decisions needed:** Should doc 07 §5's conditions (mercado after a fight, visión in low light) be enforced (P2-10), or are the events fine anywhere?
- **Next step:** the owner reads the new rooms in `data/curios.json` / `data/traps.json` (or plays a Sótanos expedition) and marks P2-02 done. Otherwise sign off Phase 1 (P1-09) and take P2-04 (Sótanos enemies to ~12).

---

## 2026-11-16 (2) — P3-03 — Owner decisions: misa rápida removed, Quebranto cure kept
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P3-03 `review` (unchanged; the owner answered the 3 questions from the entry below).
- **Changed:**
  - The group "misa rápida" is gone:
    - `GameState.iglesia_cost/iglesia_relief/iglesia_misa_rapida` removed;
    - the hub's `BtnIglesia` became the `ReliefTitle` label;
    - `hub.iglesia_*` removed from `balance.json` and `BALANCE_KEYS`.
  - `data/town_events.json`: the event texts that said "la misa" now talk about the Iglesia Vieja. The effects are unchanged; `service_pct.iglesia` and `relief_pct` already apply to the activities. `town_events.gd` effect line reads "La Iglesia Vieja alivia …".
  - `tests/test_town_events.gd`: the misa checks now test activity cost and relief and the closed Iglesia.
  - `tools/playtest_campaign.gd`: heroes left at home with stress ≥ 30 or a Quebranto book the cheapest free activity; busy heroes are not picked for the party.
  - Docs: doc 02 §7 records the decisions (activities cure the Quebranto; no refusals by Quebranto; refusals come with quirks). P3-06 has the quirk note. Doc 04 points to `hub_activities.json`.
- **Verified:** see the commit; `validate_data.py` 0 errors; full test list + smoke 0 failures; a 1-campaign × 8-week bot run finished without `SCRIPT ERROR`.
- **Not verified / risks:** no human play-test. Older doc 09 §5 playtest notes still mention the misa (historic record, left as is).
- **Decisions needed:** none new.
- **Next step:** owner play-tests P3-03 in the hub. Otherwise the next `todo` in the current phase (P1-20 smoke frame-cap flake).

---

## 2026-11-16 — P3-03 — Iglesia Vieja + Cantina del Centro (stress activities)
- **Agent / branch:** Claude Code (cloud) / `claude/p3-03-followup-48gkar`
- **Status after session:** P3-03 `review`. New `todo` P3-18 (Iglesia/Cantina upgrade tracks).
- **Changed:**
  - `data/hub_activities.json` (new): 2 buildings × 3 activities (Meditación, Rezo, Penitencia; Guaro y Conversa, Juegos de Azar, Noche de Fiesta). Each has a cost, a relief range, slots, a side-effect chance and weighted side effects.
  - `scripts/domain/hub_activities.gd` (new): pure rules (catalog, slots, cost, relief and side-effect rolls).
  - `scripts/autoload/game_state.gd`:
    - `send_to_activity` / `cancel_activity` (full refund) / `activity_block_reason`;
    - `_resolve_hub_activities` runs inside `end_of_expedition_week`: relief, Quebranto cured, one side effect;
    - side-effect kinds: buff/debuff, lose/gain colones, lose a consumable, extra week, stress;
    - a busy hero can't join the party;
    - `town_buffs` become camp buffs at mission start;
    - save v10 (`busy`, `town_buffs` sanitized; busy heroes never loaded into the party).
  - `scripts/hacienda/hacienda_hub.gd`: a panel under the misa button for the selected hero (3 buttons per building with price and slots, or Cancel). The roster row shows "En Cantina del Centro (…)" and the Cuadrilla box is locked.
  - `scripts/domain/town_events.gd` + validator: `cantina` is a service (`closed`, `service_pct`). `relief_pct` scales Iglesia activities only.
  - `tools/validate_data.py` checks `hub_activities.json`: shape, ranges, kinds, placeholders, and that buff mods help and debuff mods hurt.
  - New: `tests/test_hub_activities.gd` (29 checks) and `tools/screens/relief_screenshot.gd`.
  - Docs: doc 02 §7 "Built", doc 13 (save v10), the plan, and the AGENTS.md test list.
- **Verified:**
  - Godot 4.7.2 Linux was downloaded into the scratchpad. `--import` ran clean.
  - `validate_data.py`: 0 errors, 1 known warning (Amarrado icon).
  - Smoke test and every test in the AGENTS list, plus the new test: 0 failures, no `SCRIPT ERROR`.
  - Screenshot at 1280×720: the panel fits under the misa button in both states (free, booked).
- **Not verified / risks:**
  - No human play-test.
  - Prices (900–1500 ₡) and relief (25–65) are first guesses. Doc 09 §5 says the economy isn't tight and stress rarely reaches 100, so these may matter little until P5-02 balance.
  - `tools/playtest_campaign.gd` still uses only the misa rápida, not the new activities.
- **Decisions needed:**
  - Keep the old group "misa rápida" (−10 to everyone, no busy week) now that real activities exist? It undercuts the duality. Kept for now, because town events mention "la misa".
  - Should activities cure the Quebranto (DD rule; implemented) or only lower stress?
  - DD-style activity restrictions by Quebranto (e.g. a hero who refuses the church) are not implemented. Do we want them?
- **Next step:** owner play-tests P3-03 in the hub (select a stressed hero → panel under "Iglesia Vieja: misa rápida"). Otherwise take the next `todo` in the current phase (P1: P1-20 smoke frame-cap flake), or teach `tools/playtest_campaign.gd` to book stressed idle heroes into `GameState.send_to_activity`.
## 2026-11-15 (4) — P5-05 — Bots that retreat; P5-06 blocked
- **Agent / branch:** Claude Code (cloud container) / `betomm/happy-faraday-5yrmcr`
- **Status after session:** P5-05 `review`. P5-06 `blocked` (needs P3-03 and bigger samples). Nothing `in-progress` from this branch.
- **Changed (tools and docs only; no game data):**
  - `tools/sim_policy.gd`: `_should_retreat` (a death in this fight, two heroes Al Borde, or a dragging fight with someone at 150+ stress), `retreats` switch.
  - `tools/sim_combat.gd`: `--no-retreat`; retreats counted.
  - `tools/playtest_campaign.gd`: goes home after a Retirada or one death; up to three misas a week (`MISAS_MAX`); "Retreats" line and ↩ marks in the report.
  - Doc 09 §6 (table and findings), `docs/playtests/2026-11-15-retreat-{full,direct}.md`, phase plan.
- **Verified:**
  - `validate_data.py`: 0 errors, 1 warning (the known Amarrado icon).
  - Smoke expedition `0 failure(s)`; all 13 test scripts pass, no `SCRIPT ERROR` (run after the last tool change).
  - Playtest 3 × 24 weeks per route, data unchanged: heroes lost per expedition 0.18 full / 0.06 direct (were 0.76 / 0.25); direct route 94% / 96% / 55% cleared by tier; full route 28 of 72 cleared.
- **Not verified / risks:**
  - The saved reference was run before the bot paid for more than one misa a week; with three misas the totals differ (see doc 09 §6).
  - Run-to-run noise is large. On the direct route Veterano was 96%, 76% and 68% in three runs that differed only in the Iglesia's relief (10, 20, 30), where more relief should not hurt.
  - The combat sim's headline number changed meaning: the starting party now clears about 84% of Aprendiz chains and retreats from 16% (it was 96% fighting to the end). Use `--no-retreat` to compare with older tables in doc 10.
- **Decisions needed:**
  1. The full route can't be balanced until the hacienda can take off real stress. P3-03 (Iglesia Vieja + Cantina) is the task for that; should it come next, ahead of the P2 content tasks?
  2. A retreat costs 10 stress and nothing else (no Luz, no hunger move). Enough?
- **Next step:** P3-03 if the owner agrees (spec: doc 02 and doc 04 §3.2; first file `scripts/autoload/game_state.gd` `iglesia_misa_rapida`, which is still a stub). Then P5-06 with `tools/playtest_campaign.gd -- --campaigns 10 --weeks 24` per route and setting. Without a decision: P1-20 (smoke frame-cap flake) or P2-02.

---

## 2026-11-15 (3) — P5-04 — Retreat from a fight ("Retirada")
- **Agent / branch:** Claude Code (cloud container) / `betomm/happy-faraday-5yrmcr`
- **Status after session:** P5-04 `review`. New `todo` tasks P5-05 (a bot that retreats) and P5-06 (retune Veterano and Campeón).
- **Owner decisions (2026-11-15), answering the last handoff:** make failing cheaper than dying, then bring the later tiers into their bands; keep the economy tight; the event veteran stays at 6,000 ₡; bosses keep dragging from round 12; top hero's stress was not asked and stays as it is.
- **Changed:**
  - `data/balance.json` `combat.retreat_chance` 0.75, `combat.retreat_stress` 10; `BALANCE_KEYS`.
  - `scripts/domain/combat_resolver.gd` `roll_retreat`; `scripts/combat/combat_controller.gd` `can_retreat`, `retreat`, signal `combat_fled`, `_close_fight` (split out of `_finish`).
  - `scripts/autoload/game_state.gd` `previous_node_id`, `retreat_to_previous_room`.
  - `scripts/expedition/expedition_screen.gd`: "Retirada" on the action row, `_on_combat_fled`, honest text for "Abandonar expedición", smaller icons when the row holds nine.
  - `scripts/ui/skill_icon.gd`: a retreat glyph.
  - `tests/test_retreat.gd` (new, 13 checks); `tools/screens/battle_screenshot.gd` also saves `battle_actions.png`.
  - Docs: 01 §5.3, 13, AGENTS.md §3 and §4.
- **Verified:**
  - `validate_data.py`: 0 errors, 1 warning (the known Amarrado icon).
  - Smoke expedition `0 failure(s)`; all 13 test scripts pass, no `SCRIPT ERROR`.
  - Screenshot under xvfb: the row of nine icons fits and the retreat icon draws. The first try overflowed the bottom panel; that is why the icons shrink.
- **Not verified / risks:**
  - The bots don't retreat yet, so no playtest numbers changed. That is P5-05.
  - What I found before building this: retreating on the map already kept all colones and items; the old text ("con las manos vacías") was wrong. So "retreat keeps loot" needed no rule change, only a way out of a fight.
  - A retreat costs no Luz and no hunger move. A player could walk in, look at the squad and retreat for 10 stress each; say if that should cost more.
- **Decisions needed:** none.
- **Next step:** P5-05: in `tools/sim_policy.gd` `act()`, call `cc.retreat()` when `cc.can_retreat()` and a hero died in this fight, or two are Al Borde, or the fight drags with someone at 150+ stress; in `tools/playtest_campaign.gd` listen to `screen._combat.combat_fled` and then press "Abandonar expedición" (`screen._on_flee_pressed()`), and abandon on the map after one death. Then rerun 3 × 24 weeks on both routes and compare with `docs/playtests/2026-11-15-final-*.md`.

---

## 2026-11-15 (2) — P5-02c, P5-02f — Stress and difficulty numbers; recruits are free
- **Agent / branch:** Claude Code (cloud container) / `betomm/happy-faraday-5yrmcr`
- **Status after session:** P5-02c `review`, P5-02f `review`. All of P5-02a–f is now in `review`; nothing is `in-progress` from this branch.
- **Changed:**
  - `data/skills.json`: `stress_relief` on *No Me Tumban* 2, *Círculo de Tiza* 3, *Humo de Hierbas* 3, *Regaño Santo* 8, *Rezo de Nicoya* 2; *Sopa Milagrosa* heals 1–3.
  - `data/progression.json` difficulties, PV / damage / stress: Aprendiz 1.1 / 1.2 / 1.5, Veterano 1.75 / 1.6 / 2.0, Campeón 2.4 / 2.0 / 2.25.
  - Recruits are free (owner 2026-11-15): `hire_cost` removed from `data/heroes.json`; `GameState.hire_cost`; the hub button says "gratis"; `tests/test_hub.gd`; AGENTS.md §4, doc 02 §3, doc 13.
  - `tests/test_progression.gd`: the Veterano check follows the new multipliers.
  - Tools: `tools/sim_combat.gd --level --ranks --gear`; `tools/playtest_campaign.gd --start-level --start-ranks --start-gear --start-colones`, a core-team party pick (`REST_AT` 60) and two free spares (`SPARE_ROSTER` 6).
  - Docs: 01 §6.1 (difficulty table), 09 §6 (final table, targets, what the tuning showed), 10 (sim rerun); `docs/playtests/2026-11-15-final-{full,direct}.md`.
- **Verified:**
  - `validate_data.py`: 0 errors, 1 warning (the known Amarrado icon).
  - Smoke expedition `0 failure(s)`; all 12 test scripts pass, no `SCRIPT ERROR`, on the final data.
  - Sim, 10,000 chains each: Aprendiz 95.9% (fresh party), Veterano 98.7% and Campeón 92.3% (seasoned parties), 0 chains past 40 rounds.
  - Playtest 3 × 24 weeks per route: 128 of 144 cleared; Aprendiz 91%, Veterano 86%, Campeón 4 of 5; all 12 campaigns solvent in week 24. It ran on a copy of the project with the same data values (checked key by key) and the bot as committed.
- **Not verified / risks:**
  - The final numbers rest on one pair of runs; an earlier pair with the same Aprendiz numbers but paid recruits gave very different totals. Three campaigns per route can tell "fine" from "broken", not 85% from 90%.
  - Campeón: 5 expeditions in the final runs. Its multipliers come from tier-start runs with a prepared party (58 of 58 cleared at ×2.2 / ×1.9; 33 of 36 at ×2.6 / ×2.1).
  - The first six weeks of a campaign are never lost (36 of 36); the Aprendiz losses come from parties rebuilt after a wipe.
  - Nothing here was played by a person. The hub's "gratis" recruit buttons were checked in a screenshot (`tools/screens/expedition_events_screenshot.gd` under xvfb); the new difficulty tooltip (with "x… estrés") was not.
- **Decisions needed:**
  1. **Clear rate or hero deaths?** The bands (85–90 / 70–80 / 55–70) and doc 04 §4 (a death every 5–8 missions) can't both hold while a failed expedition is a wipe. Veterano on the full route is at 64% cleared and 1.5 heroes lost per expedition. Options: a retreat that keeps part of the loot, so failing is cheaper than dying; or accept higher clear rates on the later tiers. I stopped at the softer side.
  2. **The economy is tight now** (bank 4–8k, was planned at 8–15k after week 8). Raise rewards, or keep it tight?
  3. The level-6 veteran from a town event still costs 6,000 ₡. Free too?
  4. Top hero's stress on the full route is 83 (target 60–80). Leave it, or give back a little relief (for example *Regaño Santo* 10)?
  5. Still open from P5-02b: should bosses start dragging at round 8 instead of 12?
- **Next step:** owner playtest of P5-02a–f (a direct run and a full run on Aprendiz, then one on Veterano), then the decisions above. For an agent with no decision yet: P1-20 (smoke frame-cap flake, `tests/smoke_expedition.gd`) or the first `todo` in P2 (P2-02, 30–40 Sótanos event variants). If decision 1 goes to "retreat keeps loot", add it as a new task in P5 and rerun `tools/playtest_campaign.gd -- --campaigns 3 --weeks 24` on both routes against `docs/playtests/2026-11-15-final-*.md`.

---

## 2026-11-15 — P5-02d, P5-02e — Darkest Dungeon XP curve; two provision kits; reference run for the tuning
- **Agent / branch:** Claude Code (cloud container) / `betomm/happy-faraday-5yrmcr`
- **Status after session:** P5-02d `review`, P5-02e `review`. P5-02c (stress) is `in-progress`: the lever is in, the numbers are not set. P5-02f `todo`.
- **Changed:**
  - P5-02d: `data/progression.json` thresholds `[0, 2, 10, 24, 48, 84, 132]` (Pura Vida `[0, 2, 8, 19, 38, 67, 106]`); `SAVE_VERSION` 10 and the XP floor on load in `game_state.gd`; validator check for the Pura Vida curve; tests; doc 01 §6.1, doc 13.
  - P5-02e: both region JSONs; `missing_provisions` / `buy_missing_provisions` take a kit; the hub prompt (`hacienda_hub.gd` `_confirm_provisions`); validator; `tests/test_expedition_systems.gd`; doc 01 §4.6, doc 04 §3.1, AGENTS.md §4; `tools/screens/expedition_events_screenshot.gd` call updated.
  - P5-02c so far: `enemy_stress` per difficulty in `progression.json` (all 1.0), read in `game_state.gd` (`stress_mult`) and `combat_controller.gd`; shown in the hub's difficulty tooltip; validator.
  - Tools: the bot steps back into position (`tools/sim_policy.gd` `_step_to_attack`) and plans its party per difficulty (`tools/playtest_campaign.gd` `_plan_party`).
  - Doc 09 §6: table for these two tasks. `docs/playtests/2026-11-15-xp-kits-{full,direct}.md`.
- **Why the order changed:** the first stress try (relief on four skills cut) did nothing on the direct route and far too much on the full one, because half the full route's hunger stops were short of food. So the kits and the curve went in before the stress numbers.
- **Verified:**
  - `validate_data.py`: 0 errors, 1 warning (the known Amarrado icon).
  - Smoke expedition `0 failure(s)`; all 12 test scripts pass, no `SCRIPT ERROR` (run on commit `3495406` plus the bot change; no game code changed after).
  - The provisions prompt rendered under xvfb (`tools/screens/expedition_events_screenshot.gd`): both kits and both buttons show.
  - Playtest 3 × 24 weeks per route: Veterano in week 7–9, Campeón in week 15–17; 3 of 152 full-route hunger stops short of food; 144 of 144 cleared.
- **Not verified / risks:**
  - The game is now far too easy for the bot (no expedition lost, stress back at 12–16). That is the starting point for P5-02c and P5-02f, not a regression.
  - Bosque's kits are a guess; the region is not playable in the slice.
  - A v9 save was only tested through `apply_save_data` in the test, not by loading a real save file from the owner's machine.
- **Decisions needed:** none new. (Still open from P5-02b: should bosses start dragging at round 8 instead of 12?)
- **Next step:** P5-02c and P5-02f together. Copies of the project with data edits live in the scratchpad (`tools/variant.py`; recreate it if the container is new: it copies the repo and edits `data/skills.json` / `data/progression.json`). Compare 3 × 24-week runs on both routes with `docs/playtests/2026-11-15-xp-kits-*.md`. Levers tried so far in the sim: enemy damage alone barely moves the clear rate, because in-combat healing absorbs it; enemy PV and smaller heals move it more. Targets: stress back at the hub 30–50 with a resolve check in about 1 of 3 expeditions; clear rate 85–90% Aprendiz, 70–80% Veterano, 55–70% Campeón.

---

## 2026-11-14 (2) — P5-02b — Dragging-fight stress; a second Colapso in a fight is a death roll
- **Agent / branch:** Claude Code (cloud container) / `betomm/happy-faraday-5yrmcr`
- **Status after session:** P5-02b `review`. P5-02c (stress pass) is next.
- **Changed:**
  - `data/balance.json` `combat.drag_round` 8, `drag_round_boss` 12, `drag_stress` 4, `drag_stress_step` 2; `BALANCE_KEYS` in the validator.
  - `scripts/domain/stress_system.gd`: `drag_stress`, `apply_drag`; `_apply_colapso` marks `collapsed_this_fight`, and a second Colapso in the fight is a death roll.
  - `scripts/combat/combat_controller.gd`: `_apply_drag_stress()` in `_start_round()` (log lines and "+N estrés" over the heroes); the mark is cleared at the start and end of a fight.
  - `tests/test_balance.gd`: 10 new checks.
  - Tools: the smart bot plays to finish a dragging fight (`tools/sim_policy.gd`); `tools/sim_combat.gd` has `--party` and `--log-long N`; the campaign bot retreats after losing two heroes on the expedition.
  - Docs: 01 §3.1 and §3.4, 09 §6, 10, AGENTS.md §4 and §6; `docs/playtests/2026-11-14-drag-{full,direct}.md`.
- **Verified:**
  - `validate_data.py`: 0 errors, 1 warning (the known Amarrado icon).
  - Smoke expedition `0 failure(s)`; all 12 test scripts pass, no `SCRIPT ERROR`.
  - Sim, 10,000 chains each: 0 chains past 40 rounds for the starting party (99.2% cleared, was 99.8%), 3 Abuelas + Curandero (97.6%) and 3 Campesinos + Abuela (89.2%).
  - Playtest, 3 × 16 weeks per route: 96 of 96 cleared, longest fight 23 rounds (was 58). Forced stall-prone parties: longest 13 and 12.
- **Not verified / risks:**
  - The two saved playtest runs were made before the second-Colapso rule. It only matters in fights past about 30 rounds, and none got there, so I did not rerun them.
  - The second-Colapso rule also applies outside dragging fights: a hero who collapses, is healed up and reaches 200 again in the same fight now rolls for death. That was almost impossible to reach before.
  - How the warning and the stress numbers feel in a real fight needs the owner.
- **Decisions needed:**
  - The plan said one threshold; I added a later one for bosses (round 12), because boss fights average 7–10 rounds. Say if bosses should use round 8 too.
- **Next step:** P5-02c: lower `stress_relief` on *No Me Tumban*, *Círculo de Tiza*, *Humo de Hierbas* and *Regaño Santo* in `data/skills.json`, rerun `tools/playtest_campaign.gd -- --campaigns 3 --weeks 16` on both routes and compare with `docs/playtests/2026-11-14-drag-*.md`. Targets: top stress at the end 60–80, a resolve check in about 1 of 3 expeditions, party average back at the hub 30–50.

---

## 2026-11-14 — P5-02a — Balance pass planned; playtest bot spends like a player; 16-week baselines
- **Agent / branch:** Claude Code (cloud container) / `betomm/happy-faraday-5yrmcr`
- **Status after session:** P5-02a `review`. P5-02 is split into P5-02a–f (plan and owner decisions in the phase plan); P5-02b is next.
- **Changed:**
  - `docs/12-phase-plan.md`: P5-02 split into six tasks, with the owner's four decisions of 2026-11-14.
  - `tools/playtest_campaign.gd`:
    - `--set path=value` and `--party id,id,id,id`;
    - the bot takes at most one dedicated healer, and buys skill ranks, equipment and stress items;
    - the report adds stress on returning to the hub, a clear-rate table per difficulty, food, and colones by sink.
  - `docs/playtests/2026-11-14-baseline-{full,direct}.md`: 3 campaigns × 16 weeks per route.
  - Doc 09 §6: the baseline table and what it changes. AGENTS.md §6: the tool's new options.
- **Verified:**
  - `validate_data.py`: 0 errors, 1 warning (the known Amarrado icon).
  - Godot 4.7.2 Linux (downloaded into the scratchpad): all 12 test scripts print `0 failure(s)`, no `SCRIPT ERROR`.
  - Both baseline runs finished with no `SCRIPT ERROR` and no stuck expedition (675 s and 421 s, run in parallel).
- **Findings (doc 09 §6):**
  - With a spending bot the bank stays at 5–12k through week 16. The economy was not loose; the old bot just didn't buy anything.
  - Still too easy: 93 of 96 cleared, Aprendiz and Veterano never lost.
  - Stress is held under 50 by free relief skills; 5 of 96 expeditions had a resolve check.
  - The two longest fights (51 and 58 rounds) had Campesinos healing with *Aguante de Campo*, so stalls are not only a healer-party problem.
- **Not verified / risks:**
  - `tests/smoke_expedition.gd` failed 2 of 6 runs with the P1-20 flake ("expedition ended () after 4 moves"). No game code changed in this task, and the baselines were running on the same CPU.
  - The bot buys the dearest equipment it can afford, not the best for the class; a human would choose better.
- **Decisions needed:** none.
- **Next step:** P5-02b: add `combat.drag_round` / `drag_stress` / `drag_stress_step` to `data/balance.json` and `BALANCE_KEYS`, write the rule in `scripts/domain/stress_system.gd`, call it from `_start_round()` in `scripts/combat/combat_controller.gd`, then rerun the playtest with `--party campesino,campesino,campesino,abuela` and `--party abuela,abuela,abuela,curandero`.

---

## 2026-11-12 (night, 6) — P1-09 — Headless campaign playtest
- **Agent / branch:** Claude Code (Opus 5.5, owner's Windows machine) / `main`
- **Status after session:** P1-09 `review`. The owner reads doc 09 §5 and decides whether Phase 1's exit criteria are met.
- **Changed:**
  - `tools/sim_policy.gd` (new): the sim's smart/basic hero policy, shared. It adds `use_items` (a healing item for an ally Al Borde) and per-class action counts.
  - `tools/sim_combat.gd` uses it (same results: 200 chains, 100.0% cleared, 0.02 heroes lost, as before).
  - `tools/playtest_campaign.gd` (new):
    - plays whole campaigns through the real expedition screen with a careful-player bot (hub services, provisions, ranks, difficulty step-up, exploration, items, events, camp, smart combat);
    - prints per-week tables and a summary.
  - `docs/playtests/2026-11-12-campaign-{full,direct}.md`: raw output of 2 × 3 campaigns × 8 weeks.
  - Doc 09 §5: playtest notes, the doc 09 success criteria, the Phase 1 exit criteria and 5 balance questions for P5-02.
  - AGENTS.md §6 mentions the tool.
- **Verified:**
  - `validate_data.py`: 0 errors.
  - Both playtest runs finished with no `SCRIPT ERROR` and no stuck expedition (544 s and 254 s). They ran in parallel, which P1-19 makes safe.
  - Only tools and docs changed, so the test suite was not rerun.
- **Findings (details in doc 09 §5):**
  - 46 of 48 expeditions cleared.
  - The economy isn't tight: colones grow to 21–41k by week 8.
  - Stress rarely reaches 100.
  - Full exploration needs about 16 gallo pinto, not 10.
  - Healer-heavy parties stall.
  - Heroes reach Veterano by week 4–6.
- **Decisions needed:**
  - Phase 1 sign-off (set **Current phase** to P2?).
  - The 5 balance questions at the end of doc 09 §5.
- **Next step:** if the owner signs off Phase 1, set **Current phase** to P2 in the plan and continue with the first `todo` P2 task. Otherwise, P1-20 (smoke frame-cap flake) or P1-15 (expedition sim; `tools/playtest_campaign.gd` already covers much of it, so consider cutting or narrowing P1-15).

---

## 2026-11-12 (night, 5) — P1-08 — Technical architecture doc
- **Agent / branch:** Claude Code (Opus 5.5, owner's Windows machine) / `main`
- **Status after session:** P1-08 `done`.
- **Changed:**
  - `docs/13-architecture.md` (new), checked against the code:
    - layers and autoloads;
    - save system: file, when it's written, P1-19 safety, schema, v3→v9 history, how to bump;
    - encounter flow: `start_mission`, map generator, room loop, building a fight, the combat controller's rounds, turns, damage and end, back to the hub;
    - status engine: storage, apply, tick, `stat`, lifetime;
    - data files: what each holds and who loads it, the outcome vocabulary;
    - tests and tools.
  - `docs/README.md` index links it.
- **Verified:** `validate_data.py`: 0 errors, 1 warning (the known Amarrado icon). Docs only; no code changed.
- **Not verified / risks:** the doc describes the code as of `e93a3b7`; it will drift. Update it when the save shape, the flow or the status engine change.
- **Decisions needed:** none.
- **Next step:** P1-09 (paper/headless playtest + Phase 1 sign-off) if its dependencies are done; otherwise P1-20 (smoke frame-cap flake) or P1-15 (expedition sim).

---

## 2026-11-12 (night, 4) — P1-19 — Tests and tools no longer touch the real save
- **Agent / branch:** Claude Code (Opus 5.5, owner's Windows machine) / `main`
- **Status after session:** P1-19 `done`. New `todo` P1-20 (smoke expedition sometimes runs out of frames).
- **Changed:**
  - `scripts/autoload/save_service.gd`:
    - `is_script_run()` (`-s`/`--script` on the command line, or the main loop has a script) turns saving off: tests, the sim and screenshot tools start from `reset_party_from_catalog()` and never read or write `user://save.json`.
    - `save_to()` writes `save.json.tmp`, reads it back, moves the previous good save to `save.json.bak`, then renames the temp file into place.
    - `load_from()` copies an unreadable save to `save.broken-<unix time>.json` and loads the `.bak` instead; a broken save never becomes the backup.
    - `save_path` is a var so tests can use a scratch folder; JSON is parsed with `JSON.parse()` (no engine error spam on a broken file).
  - `tests/test_save.gd` (new, 17 checks).
  - AGENTS.md (verify list, §6 save note), README save line.
- **Verified:**
  - `validate_data.py`: 0 errors, 1 warning (the known Amarrado icon).
  - Godot 4.7.2: all 13 test scripts 0 failures, no `SCRIPT ERROR`; the real save's md5 was the same before and after the suite, the sim and 8 more smoke runs.
  - One normal headless game start loaded the owner's save, wrote it back and left `save.json.bak` (same campaign: week 1, 5,000 ₡; only hero defaults filled in by `apply_save_data`).
- **Not verified / risks:**
  - The smoke expedition failed once in 27 runs: one fight outlasted the bot's 3000-frame cap (P1-20). It isn't from this change; both before and after, the bot played the catalog party.
  - Tests used to start from whatever was in the owner's save; they now start from a fresh catalog party. All of them pass that way.
- **Decisions needed:** none.
- **Next step:** P1-08 (architecture doc), or P1-20 if the smoke flake gets in the way.

---

## 2026-11-12 (night, 3) — P1-17, P1-18 — Accuracy in the dark, provision prices
- **Agent / branch:** Claude Code (Opus 5.5, owner's Windows machine) / `main`
- **Status after session:** P1-17 and P1-18 still `review`. New `todo` P1-19 (tests must not touch the real save).
- **Owner decisions (2026-11-12):**
  - Heroes lose accuracy in the dark.
  - The agent picks the provision prices.
- **Changed:**
  - **Accuracy:** `light.tiers` gains `hero_accuracy` (Penumbra −3, Oscuro −6, Negro −10; 2% to hit per point). `combat_controller._resolve_hero_attack` reads it from the live Luz; the HUD tooltip lists it; the sim's policy uses it; the validator requires the key.
  - **Prices (`data/items.json`):** gallo pinto 150 → 75, candela de sebo 200 → 100, fósforos 120 → 60. The full Sótanos kit is 1,050 ₡, about 30% of an Aprendiz run (≈3,500 ₡), which is DD's ratio and fits doc 04 §3.1's 1,200–2,200 ₡ loadout once healing items are added. Topping up the starter kit costs 550 ₡.
  - **Tests:** `test_town_events` computes the Huelga price from data; `test_expedition_systems` checks the tier values and that a −100-accuracy hero misses (49 checks).
  - **Docs:** doc 01 §4.5 table and §4.6 prices, doc 04 §3.1, doc 10 sim results, AGENTS.md §4.
- **Verified:**
  - `validate_data.py`: 0 errors, 1 warning (the known Amarrado icon).
  - Godot 4.7.2: all 12 test scripts 0 failures, no `SCRIPT ERROR`.
  - Sim chains (5,000 each): smart play clears 99.6% in Penumbra and 96.9% in Negro (was 99.0%). Boss fights in Negro last 11.6 rounds instead of 7.4.
- **Not verified / risks:**
  - **The owner's dev save was reset** (now week 1, 5,000 ₡). Running several Godot instances at once raced on `user://save.json`. One failed to read it, started a new game and saved it (see P1-19). There was no backup.
  - In Negro, 0.9% of smart chains stall past 40 rounds (healers out-heal a blind party).
- **Decisions needed:** none.
- **Next step:** P1-19. In `scripts/autoload/save_service.gd`, skip load/save when Godot runs a `-s` script, and write saves through a temp file + `.bak`. Then P1-08 (architecture doc).

---

## 2026-11-12 (late night, 2) — P1-16, P1-17, P1-18, P2-01, P2-09 — Expedition systems, DD-style
- **Agent / branch:** Claude Code (Opus 5.5, owner's Windows machine) / `main`
- **Status after session:** P1-16 done. P1-17, P1-18, P2-01 and P2-09 are in review (the owner should play a run).
- **Owner decisions (2026-11-12):**
  - Damage outside combat uses the combat rule (heroes can die).
  - Travel hunger every 6 moves, −10% PV (floor 1) and +10 stress.
  - Full DD-style Luz tiers.
- **Changed:**
  - **P1-16 (the bug):** `scripts/domain/hero_damage.gd` now holds the PV rule: Al Borde, then Golpe de gracia. Combat, traps and curios all use it. Before, trap and curio damage left heroes at 0 PV without Al Borde. A wipe outside combat ends the expedition.
  - **P1-17 Luz:**
    - `data/balance.json` `light.tiers` and `scripts/domain/light_system.gd`.
    - Effects: enemy damage and crit, hero stress taken (live in combat), loot, the surprise roll (`combat_context.surprise`; heroes or enemies act first in round 1), trap disarm, and stress per move in Oscuro/Negro.
    - Decay is 8 per move. New "Apagar la candela" button; the tier and a tooltip on the HUD.
    - Camp resets Luz to `light_max()`. The ambush counts low light as Penumbra or darker and gets doc 07's exhausted +4%.
    - The region `low_light_*` fields are gone.
  - **P1-18 Hunger:**
    - A hunger stop before the room resolves: eat, share what there is, or go hungry. Short of food, the most hurt eat first.
    - A camp meal resets the count. The dead `mission_food` is gone.
    - Regions list `provisions`. The hub warns before leaving short and can buy what is missing.
  - **P2-01 Traps:**
    - `data/traps.json` and `scripts/domain/trap_rules.gd`.
    - Disarm works as in DD: best *trampa* + Luz bonus − difficulty. The plain base chance was dropped, because the starting Tecnólogo's trampa 60 made every trap trivial.
    - Pasar con cuidado costs 10 Luz and still springs 30% of the time.
    - The generator sets `trap_id`. The Bosque gets Raíces traicioneras.
  - **P2-09 Curios:**
    - Doc 07's bad outcomes: curse, mimic ambush, Susto, Fiebre (stands in for disease), noise ambush.
    - `GameState.apply_curio_outcome` became `apply_event_outcome`, with `damage_party`, `applies`, `buff`/`debuff`, `ambush`.
    - Curses show red with their source. Thrown items respect Santiguado.
  - **Validator:** checks the Luz tiers, hunger keys, camp ambush keys, provisions, traps, every curio/trap outcome and the region references.
  - **Tests:** new `tests/test_expedition_systems.gd` (47 checks). `test_progression` uses the new ambush signature.
  - **Sim:** `tools/sim_combat.gd` rolls surprise and has `--light N`. The results are in doc 10.
  - **Screenshots:** `tools/screens/expedition_events_screenshot.gd` (hunger, trap, Luz tooltip, provisions).
  - **Docs:** doc 01 §4.4–4.7, doc 07 §3/§4/§6, doc 10 (Luz, sim rerun), AGENTS.md §4.
- **Verified:**
  - `validate_data.py`: 0 errors, 1 warning (the known Amarrado icon).
  - Godot 4.7.2: all 12 test scripts 0 failures, no `SCRIPT ERROR`. The smoke bot passes hunger stops and traps.
  - The 4 screenshots were checked by eye.
  - Sim at full light matches P1-07 within noise. In Negro, stress is about 50% higher and deaths about 3×.
- **Not verified / risks:**
  - Nobody has played a full run yet. The new numbers (tiers, hunger, trap difficulty) are first guesses.
  - The provisions purchase was only tested through `GameState.buy_missing_provisions`, not by clicking the dialog.
  - Surprise in the dark can now give enemies the first round in any normal fight.
  - Statuses from traps (Sangrado, Amarrado) wait for the next fight to tick.
- **Decisions needed:**
  - (1) The Sótanos provisions (10 gallo pinto + 3 candelas, about 1,650 ₡ when starting from the starter kit). Is that too expensive at 150 ₡ a gallo pinto?
  - (2) Should Penumbra and darker also lower hero accuracy (DD does)? It's left out for now.
- **Next step:** P1-08 (technical architecture doc): create `docs/13-architecture.md` (save schema and versioning, hub → map → combat flow, status engine, data file schemas, now including traps/light/hunger) and link it from `docs/README.md`. Alternatively, P1-15 can now model hunger, traps and curios in the sim's chain mode.

---

## 2026-11-12 (late night) — P1-07 — Combat Monte Carlo sim
- **Agent / branch:** Claude Code (Opus 5.5, owner's Windows machine) / `main`
- **Status after session:** P1-07 done. New follow-up task P1-15 (expedition sim with camp, items and room events).
- **Changed:**
  - **`tools/sim_combat.gd` (new):** a headless Godot sim, not the Python mirror the plan named. It drives the real combat controller with stub stage units, so it can't drift from the rules.
    - Options: `--runs`, `--node combat|elite|boss|all`, `--policy smart|basic`, `--chain N` (N fights + elite + boss, carried over, no recovery), `--set path=value` (Balance overrides), `--difficulty`, `--seed`, `--log`.
    - Prints markdown tables: per room kind, per room leader, per chain step.
    - About 100 fights a second.
  - **`combat_controller.gd`:** new `instant` flag. The seven animation timers go through `_pause()`, which returns at once when `instant` is set. With the flag off (the game and the tests), behaviour is unchanged.
  - **`docs/10-implementation-notes.md`:** "Combat sim (P1-07)" section with how to run it, the Sótanos results (10k per row) and the findings.
  - **`AGENTS.md` §6:** a line on how to run the sim.
  - **Plan:** P1-07 done; P1-15 added.
- **Verified:**
  - `validate_data.py`: 0 errors, 1 warning (the known Amarrado icon).
  - Godot 4.7.2: all 11 test scripts 0 failures, no `SCRIPT ERROR`.
  - Four 10k sim runs (fresh and chain × smart and basic) finished with no errors.
- **Not verified / risks:**
  - The hero policies are heuristics. `smart` is close to an upper bound and `basic` to a lower bound for a real player.
  - The chain mode leaves out camp, items, traps, curios, light and hunger (that is P1-15).
- **Decisions needed:**
  - (1) Is the headless GDScript sim acceptable in place of the planned `tools/sim_combat.py`? The default taken: yes, because a Python mirror of about 1,000 lines of controller rules would drift.
  - (2) Findings for P5-02 (doc 10): smart play wins every fresh fight (100.0% rounded) and 99.8% of 5-fight chains with no recovery. Healing outpaces damage (Abuela's Sopa Milagrosa and Cataplasma). Quebrantos almost never happen from combat alone. Cadejo negro gives about twice the stress of the other elite. Should combat be tuned harder now, or wait for P5-02 as planned?
- **Next step:** P1-08 (technical architecture doc). Create `docs/13-architecture.md` covering save schema and versioning (`GameState` `SAVE_VERSION`/`apply_save_data`), the encounter flow (hub → map → combat → map, `expedition_screen.gd` `_start_combat`), the status engine (`status_effects.gd` + `data/statuses.json`) and the data file schemas. Link it from `docs/README.md`.

---

## 2026-11-12 (night) — P1-06 — Balance constants to data/balance.json
- **Agent / branch:** Claude Code (Opus 5.5, owner's Windows machine) / `main`
- **Status after session:** P1-06 review. Owner 2026-11-12: the tunable limits moved too; party size 4 stays in code.
- **Changed:**
  - **`data/balance.json` (new):**
    - `combat`: hit band, initiative, crit cap/mult, prot cap, Guard, miss stress, Encarrerado turns, enemy base crit.
    - `crits`; `death`; `stress` (thresholds and resist caps); `afflictions` (all Quebranto/Virtud numbers).
    - `enemies`: boss/elite HP, squad scale. `hub`: starting colones, sell rate, EBAIS, Iglesia and its backfire. `limits`: roster, inventory, recruits, graveyard. `light.max`.
    - Same values as before.
  - **`scripts/domain/balance.gd` (new):**
    - `num` / `int_of` / `arr` getters are strict (`push_error` on a missing key).
    - `req(dict, key)` for required keys in other data files.
    - `override` / `reset` for tests.
  - **Domain scripts:**
    - `combat_resolver` and `stress_system` constants were removed.
    - `status_effects`, `camping_system`, `resolve_system`, `skill_ranks`, `town_events` and `map_generator` lost their duplicate numeric fallbacks.
    - The map shape numbers went to the `sotanos.json` generator block (`branch_newest_chance`, `max_exits`).
  - **`GameState`:**
    - Prices, starting colones, stress/light/resist caps come from data; one `leader_hp_mult` replaces the duplicated 1.45 / 1.25.
    - The limits are now functions (`inventory_slots()`, `roster_cap()`, `recruit_pool_size()`, `graveyard_cap()`, `light_max()`). Callers in the hub, the expedition screen and the tests are updated.
  - **`combat_controller.gd`:** miss stress, Ira ciega self-stress, Encarrerado turns, Guard, prot cap, light max and crit numbers come from `Balance`.
  - **`tools/validate_data.py`:**
    - `BALANCE_KEYS` checks the type and range of every balance key, and every path the scripts read must be listed there.
    - The magic-number scan rejects numeric consts and `.get(…, N)` fallbacks in `scripts/domain/` unless marked `# structural`.
  - **Tests:**
    - `tests/test_balance.gd` (new, 12 checks: values match the data, overrides change behaviour, reset).
    - `test_hub` / `test_town_events` read prices from `Balance`.
    - The `test_formation` Patada check no longer flakes on the 95% hit cap (it forces the hit through `override`).
  - **Docs:** 04 §0 "Where the numbers live", AGENTS.md §2/§4 and the verify list.
- **Verified:**
  - `validate_data.py` 0 errors, 1 warning (the known Amarrado icon).
  - Godot 4.7.2: all 11 test scripts 0 failures, no errors or `push_error` lines; `test_formation` passed 3 runs in a row.
  - Hub screenshot shows 4/8 heroes, 4/24 slots, Iglesia 800 ₡ / −10.
- **Not verified / risks:**
  - The behaviour should be identical. The smoke bot lost 3/3 in one run, which is noise on top of P1-05's deadlier rules: the values are unchanged and the numeric tests all pass.
  - Trap/curio chances, the camp ambush roll and the Light reset in `expedition_screen.gd` are still in code. They belong to P2-01 (data-driven events).
- **Decisions needed:** none.
- **Next step:** P1-07 (combat Monte Carlo sim). Write a headless script that runs N fights of the starting party vs each Sótanos squad, using `Balance.override` to compare settings, and reports win rate, hero deaths and stress per fight. Start from the `tests/test_formation.gd` fight setup.

---

## 2026-11-12 (later) — P1-03b — Push, pull, shuffle, Amarrado, and fixing the formation between fights
- **Agent / branch:** Claude Code (Opus 5.5, owner's Windows machine) / `main`
- **Status after session:** P1-03b review. P1-03 is now fully built (a and b both in review).
- **Changed:**
  - `scripts/domain/formation.gd`: `can_move` (alive and not Amarrado), plus `move_by` / `move_to`. These insert rather than swap, so the others shift, and the dead stay at the back.
  - `combat_controller.gd`:
    - Hits queue their forced moves (`_queue_move`). `_apply_queued_moves` runs after the hit animations, because the snapshots are index-based.
    - `_force_move` handles Amarrado, the Empujones roll, the log and the popup. `_reorder_side` keeps data, units and stage rows aligned.
    - `move_options` and `_enemy_reposition` respect Amarrado.
  - Data:
    - `statuses.json`: Amarrado status (`resist: "movimiento"` alias) and an Empujones (`movimiento`) resist category.
    - Empujones values for every class and enemy.
    - Retén (reaches 2–3, pulls 1), Patada de Corral (pushes 1), Cadenazo (pulls a hero 1), Travesura (shuffle), Sombra que pesa (+50% Amarrado 2 turns). Descriptions and `_doc` strings updated.
  - `status_effects.gd`: the `resist` alias in `resist_chance`.
  - UI:
    - Skill tooltips: "Lo empuja / Lo jala / Lo revuelve".
    - Enemy info: reach and moves.
    - Hero card: "← Adelante / Atrás →" outside combat (`_reorder_party`).
  - `tools/validate_data.py`: `move_target` / `shuffle_target` rules, `resist` aliases, and enemy resist keys may be categories.
  - `tools/art_manifest.json`: `status_amarrado` queued, not generated. The validator warns about it, and an "M" letter badge shows until then.
  - Tests: `test_formation.gd` (now 56 checks), with screenshots in `formation_screenshot.gd`.
  - Docs: 01 §2.1, §2.5; 03; AGENTS.md §4.
- **Verified:**
  - `validate_data.py` 0 errors, 1 warning (the icon above).
  - Godot 4.7.2: all 10 test scripts 0 failures, no errors.
  - Screenshots checked: the push popup and log, the enemies re-laid out, the Amarrado badge, and the reorder buttons on the hero card.
- **Not verified / risks:**
  - Balance of the push/pull content and of the Empujones values.
  - The smoke bot won 1/3 this run (deadlier since P1-05).
  - The Amarrado icon needs `python tools/sd_local.py --only status_amarrado` on a machine with the SD model.
- **Decisions needed:** none.
- **Next step:** P1-06 (balance constants to data, now unblocked by P1-05). Create `data/balance.json` and move `CombatResolver` and `StressSystem` constants into it. The numbers to move are listed at the top of `scripts/domain/combat_resolver.gd`.

---

## 2026-11-12 — P1-05 — Spec-accurate Al Borde and crit stress
- **Agent / branch:** Claude Code (Opus 5.5, owner's Windows machine) / `main`
- **Status after session:** P1-05 review. Owner decisions 2026-11-11: surviving the death roll stays Al Borde at 0 PV; crits work as in Darkest Dungeon.
- **Changed:**
  - `scripts/domain/combat_resolver.gd`:
    - `death_save_chance(hero, collapse)`: Golpe de gracia %, −8 per earlier roll this expedition, −10/−20 at 100/150 stress, −30 on a Colapso.
    - `final_damage(raw, atk%, prot%, element, crit)`, `crit_chance`.
    - Constants (move to data in P1-06).
  - `combat_controller.gd`:
    - Surviving keeps the hero Al Borde at 0 PV, and the log shows the %.
    - A hero's crit relieves 3 stress for the party (it used to add +5 to the critter).
    - Enemies crit: 5% base, `crit` in data. A crit deals ×1.5 damage and +10 stress, with a "¡Crítico!" popup and log line.
    - Enemy `prot` goes through `final_damage`; hero protection uses it too.
  - `stress_system.gd` Colapso: uses the −30 roll; surviving stays Al Borde with stress 170.
  - `expedition_screen.gd`: an Al Borde hero's info panel shows the survival %.
  - `data/enemies.json`: `crit: 8` on the Mayordomo, the Cadejo and the Segua; `_doc`.
  - Tests:
    - `test_status.gd`: 17 checks (odds, cap, survive, die, Colapso, damage formula, party relief).
    - `test_formation.gd`: enemy crits in a real fight.
    - `formation_screenshot.gd`: enemy crit + Al Borde panel shots.
  - Docs: 01 §2.3, §2.4, §3.4; AGENTS.md §4.
- **Verified:**
  - `validate_data.py` 0 errors.
  - Godot 4.7.2: all 10 test scripts 0 failures, no errors.
  - Screenshots checked: crit popup −11 / +12 stress; the info panel shows 54% for a Montador with one earlier roll and 110 stress.
- **Not verified / risks:**
  - Deadlier, as intended: the smoke bot won 2/6 expeditions (it was about half after P1-03a).
  - Balance pass is P5-02; the numbers are in `CombatResolver` until P1-06.
- **Decisions needed:** none.
- **Next step:** P1-03b (push/pull/shuffle, Amarrado, reorder between fights). The plan is in this session's plan file and in `docs/12-phase-plan.md` P1-03b. Start in `scripts/domain/formation.gd` (`move_by`, `move_to`, `can_move`).

---

## 2026-11-11 (late night) — P1-03a — Battlefield positions 1–4 and "Moverse"
- **Agent / branch:** Claude Code (Opus 5.5, owner's Windows machine) / `main`
- **Status after session:** P1-03a review. P1-03 split into P1-03a (this) and P1-03b (push/pull/shuffle, todo); the owner picked "formation + a Move action" first.
- **Changed:**
  - Data:
    - `heroes.json` `ranks` per class (doc 03).
    - `skills.json` `use_ranks` on every hero skill, plus `target_ranks` on enemy-target skills.
    - `enemies.json` `ranks` per enemy (doc 05 §2.6) and `target_ranks` on single-target skills.
    - `_doc` strings updated.
  - `scripts/domain/formation.gd` (new, pure): positions count only the living, `at_positions`, `valid_targets`, `can_use`, `neighbours`, `step_toward`, `collapse_order`, `sort_squad`, `ranks_text`. JSON floats are converted to ints.
  - `combat_controller.gd`:
    - `current_target(skill)`, `targets_for`, `skill_usable`, `position_of`.
    - `move_options` / `move_hero` (Moverse).
    - The enemy AI filters skills by reach and picks targets in reach; with nothing in reach it calls `_enemy_reposition` ("se reacomoda").
    - `_collapse_ranks` runs at the start and between turns. `_swap_units` and `_sync_rows` keep the data arrays, unit arrays and stage rows in the same order.
  - `expedition_screen.gd`:
    - Greyed-out skills, a "Moverse" button, and a turn-label note ("Desde la posición N, X habilidades no alcanzan").
    - Target picking follows reach, and Moverse offers only neighbours.
    - The hero card shows "Posición N (ideal …)".
  - `skill_button.gd`: buttons are now 46 px (8 buttons didn't fit at 52 and pushed the map off-screen); the tooltip line reads "Desde posición …, alcanza …". `skill_icon.gd` has a `move` glyph.
  - `GameState`:
    - Squads are sorted by enemy `ranks` (`build_combat_context_for_node`, which ambushes also use).
    - The starting party is now Campesino, Montador, Abuela, Tecnólogo, so every hero starts in their class's positions.
  - Hub: "⚠ fuera de posición (ideal …)" on party rows, plus a positions line in the tooltip.
  - `tools/validate_data.py`: position fields, plus the two no-stall invariants (every class reaches enemy position 1, every enemy reaches hero position 1 from anywhere).
  - Tests:
    - `tests/test_formation.gd` (new, 34 checks).
    - Smoke bot presses only enabled buttons, moves when nothing is in reach or every 11th turn, and checks that it moved.
    - Two class-specific party lookups in `test_progression` / `progression_screenshot` now find heroes by id.
  - `tools/screens/formation_screenshot.gd` (new). Docs: 01 §2.1, 03, 05 §2.6, AGENTS.md §1 (verify list) and §4 (Formation rule).
- **Verified:**
  - `python3 tools/validate_data.py` 0 errors / 0 warnings.
  - Godot 4.7.2 headless: all 10 test scripts 0 failures, no errors.
  - Screenshots checked: hub warning, greyed-out bar + tooltips, Moverse prompt (only the neighbour highlighted), collapse (fallen Peón moved to the back).
- **Not verified / risks:**
  - Balance: the smoke bot won 2/3, 1/3 and 2/3 across three runs after the change, vs about 2/3 before. The bot plays badly and nobody has played a fight by hand.
  - The tooltip on a greyed-out button shows only sometimes. The turn label always says how many skills don't reach.
  - Enemy skills can be used from any position (only their reach is limited). That is deliberate: back-line enemies collapse forward and would otherwise stall.
- **Decisions needed:**
  - Are the per-skill positions right? The table is in this session's plan and in `data/skills.json`. For example, the Médica's Bisturí reaches 1–2 from 2–4, and Corrientazo reaches 1–4.
  - DD keeps enemy corpses in place; we collapse them (doc 01 says "collapse"). OK?
- **Next step:** P1-05 (spec-accurate Al Borde and crit stress, no deps): read doc 01 §2.4, then `combat_controller._apply_damage_to_hero`. P1-03b (push/pull) can wait until the owner has played P1-03a.

---

## 2026-11-11 (night) — P2-08 — Each class has its own basic attack
- **Agent / branch:** Claude Code (Opus 5.5, owner's Windows machine) / `main`
- **Status after session:** P2-08 review. This answers the Machetazo question in the entry below: the owner wants one basic attack per class.
- **Changed:**
  - `data/skills.json` + `data/heroes.json`: three new attacks, each the class's first skill and themed on its sprite's weapon. Campesino keeps Machetazo.
    - Abuela: **Cucharonazo** (wooden ladle): 2–6, +2 accuracy, 20% Atarantado.
    - Tecnólogo: **Corrientazo** (drone with a stripped charger cable): 3–6, +1 accuracy, +25% damage vs Fichado (pairs with Dron Casero's mark).
    - Montador: **Mecatazo** (lasso rope): 4–8, +1 accuracy, 30% Salado (−5 dodge, 2 turns).
  - `tools/validate_data.py`: no skill may be shared by two classes, and every class's first skill must be an attack.
  - `GameState`, save v9: a hero's `skill_ids` always follow the class on load (no mechanic changes them). A rank bought in a replaced skill moves to the new skill in the same slot, so an old Abuela's rank 3 Machetazo becomes rank 3 Cucharonazo.
  - `scripts/ui/skill_icon.gd`: new `ladle` and `lasso` glyphs; Corrientazo uses `bolt`.
  - `tests/test_progression.gd`: 11 checks (own first attack for all 8 classes, v8 save migration). `skills_screenshot.gd` also captures each party hero's hub row.
  - Docs: AGENTS.md §4 Heroes rule; doc 03 lists the basic attacks; plan P2-08.
- **Verified:** `python3 tools/validate_data.py` 0 errors / 0 warnings (32 skills). Godot 4.7.2 headless: all 9 test scripts 0 failures, no errors. Hub rows for the Abuela, Tecnólogo and Montador checked by screenshot.
- **Not verified / risks:**
  - Balance of the three attacks; nobody has played them.
  - The lasso glyph reads a little like a magnifying glass at 52 px.
  - The attack sprites were drawn before these skills existed. They hold the right weapons (ladle, drone, lasso), but nobody has checked them against the new names.
- **Decisions needed:** none.
- **Next step:** P1-03 battlefield ranks 1–4 (see the next entry's Next step).

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
