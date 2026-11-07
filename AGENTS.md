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
- Data goes in `data/*.json`, not hard-coded in scripts. Rules go in `scripts/domain/` (pure, no nodes). UI goes in `scripts/<screen>/`.
- If the design is unclear or contradicts the code, write the question under **Decisions needed** in your handoff entry. Then pick the smallest reasonable default and keep going.
- Never delete a task. If it is no longer wanted, set it to `cut — <reason>`.

## 3. End of session — the handoff (mandatory)

Do this before you stop for **any** reason: task finished, context running out, blocked, or the user ends the session.

1. **Verify**
   - `python3 tools/validate_data.py` must exit 0.
   - If Godot is installed (see [.cursor/rules/godot-runtime.mdc](.cursor/rules/godot-runtime.mdc); cloud agents may download the official 4.6.2 Linux build into their scratchpad, owner-approved 2026-11-07):
     - `godot --headless --path . --import` (first run / new files; generates `.uid` files — commit them)
     - `godot --headless --path . -s tests/smoke_expedition.gd` plays 3 full expeditions; must print `0 failure(s)` and no `SCRIPT ERROR`
     - `godot --headless --path . -s tests/test_guard.gd`
   - If you could not verify something (for example, no Godot in a cloud container), **say so explicitly** in the handoff.
2. **Update the plan**: set your task's status to `done`, `review` (works but needs a human check), `blocked — <why>`, or leave it `in-progress` with a note. Tick any finished acceptance checkboxes.
3. **Write the handoff entry**: add it at the **top** of [docs/HANDOFF.md](docs/HANDOFF.md) using the template there. The **Next step** line must be specific enough that a fresh agent can act on it without reading the conversation.
4. **Commit and push**: one commit (or more) whose message starts with the task ID, for example `P1-02: multi-enemy squads`. Never leave work uncommitted or unpushed. The container or machine may be gone next time.

## 4. Status vocabulary

| Status | Meaning |
|---|---|
| `todo` | Not started |
| `in-progress (agent, branch, date)` | Claimed; someone is on it or stopped mid-way |
| `review` | Implemented; needs a human playtest or approval |
| `blocked — reason` | Can't continue without a decision or resource |
| `done` | Acceptance criteria met and verified |
| `cut — reason` | Deliberately dropped |

## 5. Repo facts agents keep re-discovering

- Engine: Godot 4.6, GDScript, Forward+. Main scene `scenes/bootstrap/main.tscn`. Autoloads: `GameState`, `SaveService`.
- `GameState` (`scripts/autoload/game_state.gd`) owns all run and campaign state. Save is `user://save.json`, `SAVE_VERSION` in that file. Bump it and add migration in `apply_save_data` when you change the shape.
- Language: in-game text is **Spanish (Costa Rican)**. Code, comments, and docs are English.
- Tone guardrails: [docs/08-content-standards-satire.md](docs/08-content-standards-satire.md). Read it before writing any flavor text.
- Art: follow [.cursor/rules/stable-diffusion-assets.mdc](.cursor/rules/stable-diffusion-assets.mdc). Never call SD from game code. Every PNG needs a `.metadata.json`.
- The Godot path in `.cursor/rules/godot-runtime.mdc` is the owner's Windows machine. Cloud containers usually have no Godot.
