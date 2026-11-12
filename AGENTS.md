# Agent Rules — Darkest Tico

These rules apply to every agent (Claude Code, Cursor, Codex, a human) working in this repo. The goal: **any agent can stop at any point, and the next one can pick up without asking anyone.**

## 1. Start of session (always, in this order)

1. Read the **top entry** of [docs/HANDOFF.md](docs/HANDOFF.md). It says what the last agent did and the exact next step.
2. Open [docs/12-phase-plan.md](docs/12-phase-plan.md) and find the current phase.
3. Pick a task:
   - If the user named one, do that.
   - Else continue any task marked `in-progress` from the last handoff.
   - Else take the first `todo` task in the current phase whose dependencies are all `done`.
4. **Claim it**: set the task's status to `in-progress (<agent>, <branch>, <YYYY-MM-DD>)` in the plan.
5. Read only the design docs the task lists under **Spec**. Do not re-derive design from scratch; the docs in `docs/01`–`docs/09` are the source of truth.

## 2. While working

- Work on **one task at a time**. If you find more work, add it to the plan as a new `todo` task (next free ID in that phase) instead of doing it unasked.
- Stay inside the task's scope and file list. Touching other files is fine when needed. Say so in the handoff.
- Data goes in `data/*.json`, not hard-coded in scripts. Balance numbers (hit band, crits, death roll, stress, hub prices, limits) go in `data/balance.json` and are read with `Balance.num("section.key")` (`scripts/domain/balance.gd`). New keys must be added to `BALANCE_KEYS` in `tools/validate_data.py`, which also rejects numeric consts and numeric `.get(…, N)` fallbacks in `scripts/domain/` (mark real structural numbers `# structural`). Rules go in `scripts/domain/` (pure, no nodes). UI goes in `scripts/<screen>/`.
- If the design is unclear or contradicts the code, write the question under **Decisions needed** in your handoff entry. Then pick the smallest reasonable default and keep going.
- Never delete a task. If it is no longer wanted, set it to `cut — <reason>`.

## 3. End of session — the handoff (mandatory)

Do this before you stop for **any** reason: task finished, context running out, blocked, or the user ends the session.

1. **Verify**
   - `python3 tools/validate_data.py` must exit 0.
   - If Godot is installed (see [.cursor/rules/godot-runtime.mdc](.cursor/rules/godot-runtime.mdc); cloud agents may download the official 4.7.2 Linux build into their scratchpad, owner-approved 2026-11-07):
     - `godot --headless --path . --import` (first run / new files; generates `.uid` files — commit them)
     - `godot --headless --path . -s tests/smoke_expedition.gd` plays 3 full expeditions; must print `0 failure(s)` and no `SCRIPT ERROR`
     - `godot --headless --path . -s tests/test_guard.gd`, `tests/test_status.gd`, `tests/test_hub.gd`, `tests/test_equipment.gd`, `tests/test_feedback.gd`, `tests/test_combat_items.gd`, `tests/test_progression.gd`, `tests/test_town_events.gd`, `tests/test_formation.gd`, `tests/test_balance.gd`
   - If you could not verify something (for example, no Godot in a cloud container), **say so explicitly** in the handoff.
2. **Update the plan**: set your task's status to `done`, `review` (works but needs a human check), `blocked — <why>`, or leave it `in-progress` with a note. Tick any finished acceptance checkboxes.
3. **Write the handoff entry**: add it at the **top** of [docs/HANDOFF.md](docs/HANDOFF.md) using the template there. The **Next step** line must be specific enough that a fresh agent can act on it without reading the conversation.
4. **Commit and push**: one commit (or more) whose message starts with the task ID, for example `P1-02: multi-enemy squads`. Never leave work uncommitted or unpushed. The container or machine may be gone next time.

## 4. Content rules (owner decisions — `tools/validate_data.py` enforces them)

- **Heroes:** every class has at least one skill that helps **one ally or the whole party** (`target: ally | party`). Every class has **its own basic attack** as its first skill (kind `attack`, fitting the weapon its sprite holds), and no skill is shared by two classes (owner 2026-11-11). Skills use doc 03 names.
- **Enemies:** exactly **one basic attack** (`basic: true`) plus **1–3 special abilities**. At least one special is **magical** (`type: magical`, goes through Guard) or **inflicts a negative status** (`applies`, any negative id in `data/statuses.json`).
- **Names:** every ability has a **Costa Rican (Tico) name that fits that specific monster or class**, written in Spanish, within the tone rules of doc 08 (e.g. Mandador en pena → *Latigazo*, *Libreta de deudas*; Cadejo → *Aullido de medianoche*).
- **Guard:** halves physical damage until the hero's next turn; magical attacks and `ignores_guard` skills go through it.
- **Selling:** the Pulpería buys any item back at **half its price** (`data/balance.json` `hub.sell_rate`). Equipped items must be unequipped first.
- **Items:** outside combat, each hero can use each item `uses_per_node` times per room (per character, not per team). Using an item in combat spends the hero's turn.
- **Elements** (classic RPG set): fuego, hielo, rayo, agua, tierra, viento, sagrado, oscuridad. **Every enemy has elemental affinities** (`elements`: >1 weak, <1 resists, 0 immune) that fit the monster; enemy magic skills carry an `element`.
- **Equipment:** each hero wears **1 weapon, 1 armor, 2 accessories**, all Tico-themed. Bonuses: damage, accuracy, crit, dodge, speed, HP, protection %, stress resistance %; weapons may be typed (`element`), armor/accessories may resist elements or grant ailment immunity. Sold at the Pulpería; equipped by dragging from the inventory onto a hero slot or a hero on the stage; locked during fights.
- **Status effects** (owner 2026-11-08: every Darkest Dungeon status, Tico names) are data in `data/statuses.json`, rules in `scripts/domain/status_effects.gd`: Sangrado (bleed), Envenenado (blight), Atarantado (stun) → Espabilado (stun resist), Salado (debuff), Fichado (mark), Susto (horror), Chiva (buff), Encarrerado (crit buff), Al cuido / Cuidando (guard an ally), Respondón (riposte), Sobado (restoration), Santiguado (aegis), Agazapado (stealth), plus the hero states Al Borde (Death's Door) and Convaleciente (Death's Door recovery). Skills/items use `applies` / `self_applies` ({status, chance, turns, value, mods}), `cure`, `vs_marked_pct`, `guard_ally`; enemies may have `status_resist`. Amarrado (root) blocks every kind of move; it is resisted with Empujones (`movimiento`).
- **Formation** (P1-03a, owner 2026-11-11): each side has positions 1–4 (1 = front, nearest the middle); positions count only the living, and the fallen move to the back. In-game text says **posición** ("rango" is the Casa Comunal skill level). Hero skills need `use_ranks`; enemy-target skills also `target_ranks`. Classes and enemies have preferred `ranks` (docs 03 and 05). Enemy single-target skills need `target_ranks`; they may be used from anywhere unless `use_ranks` says otherwise. The validator requires that every class can hit enemy position 1 from one of its own positions, and that every enemy can hit hero position 1 (or the whole party) from anywhere, so no fight can stall. "Moverse" swaps the acting hero with a neighbour (spends the turn); an enemy with nothing in reach steps toward its preferred positions. Party order in the hub is the starting formation; it carries over between fights, and the hero card has "← Adelante / Atrás →" outside combat. Single-target skills may push/pull (`move_target`, negative = toward the front) or shuffle (`shuffle_target`), resisted with `status_resist.movimiento` (Empujones).
- **Al Borde and crits** (P1-05, owner 2026-11-11): a hero hit while Al Borde rolls to survive (Golpe de gracia %, −8 per earlier roll this expedition, −10/−20 at 100/150 stress, −30 on a Colapso); surviving keeps them Al Borde at 0 PV. A hero's crit relieves 3 stress for the party; enemies crit (5% base, `crit` in data) for ×1.5 damage and +10 stress on the hero hit. The numbers are in `data/balance.json` (`death.*`, `crits.*`, `combat.enemy_base_crit`).
- **Battle sprites:** a character looks identical in all poses (same outfit and weapon); only the pose changes. The attack pose uses that character's weapon, held in the **right arm**. The party stands on the **right** of the battle stage facing **left**, enemies on the left (owner 2026-11-08), so sprites are generated facing left and enemies are mirrored. Sprites must **look like the character's portrait** (same face, hair, clothes, colors): `tools/sd_sprites.py` feeds the portrait in as an IP-Adapter image prompt, and each `look` in `tools/art_manifest.json` describes what the portrait shows.

## 5. Status vocabulary

| Status | Meaning |
|---|---|
| `todo` | Not started |
| `in-progress (agent, branch, date)` | Claimed; someone is on it or stopped mid-way |
| `review` | Implemented; needs a human playtest or approval |
| `blocked — reason` | Can't continue without a decision or resource |
| `done` | Acceptance criteria met and verified |
| `cut — reason` | Deliberately dropped |

## 6. Repo facts agents keep re-discovering

- Engine: Godot 4.7 (moved from 4.6 on 2026-11-11), GDScript, Forward+. Main scene `scenes/bootstrap/main.tscn`. Autoloads: `GameState`, `SaveService`, `TooltipStyler`.
- `GameState` (`scripts/autoload/game_state.gd`) owns all run and campaign state. Save is `user://save.json`, `SAVE_VERSION` in that file. Bump it and add migration in `apply_save_data` when you change the shape.
- Language: in-game text is **Spanish (Costa Rican)**. Code, comments, and docs are English.
- Tone guardrails: [docs/08-content-standards-satire.md](docs/08-content-standards-satire.md). Read it before writing any flavor text.
- Tooltips: just set `tooltip_text` ("Title\nbody" or "Title — body"); the `TooltipStyler` autoload draws it as the shared card (`scripts/ui/tooltip_card.gd`). Custom tooltips call `TooltipCard.clear_frame(self)` and return a card from `_make_custom_tooltip`.
- Art: follow [.cursor/rules/stable-diffusion-assets.mdc](.cursor/rules/stable-diffusion-assets.mdc). Never call SD from game code. Every PNG needs a `.metadata.json`.
- Balance experiments: `godot --headless --path . -s tools/sim_combat.gd -- --runs 10000 [--chain 3] [--set path=value]` plays the real combat controller headless (doc 10 "Combat sim"). Rerun it after changing combat numbers.
- The Godot path in `.cursor/rules/godot-runtime.mdc` is the owner's Windows machine. Cloud containers usually have no Godot.
