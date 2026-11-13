# Darkest Tico

Costa Rican gothic roguelike (Darkest Dungeon–style loop). **Design specs** live in [docs/](docs/).

**Picking up work?** Read [AGENTS.md](AGENTS.md), then the top of [docs/HANDOFF.md](docs/HANDOFF.md), then [docs/12-phase-plan.md](docs/12-phase-plan.md).

## Requirements

- Godot **4.7.x** (or any **4.x** with Forward+). Download: [godotengine.org](https://godotengine.org/download).

## Run

### From the editor

1. Start Godot and **Import** or **Open** this folder (select `project.godot`).
2. Press **F5** or click **Run** (main scene: `scenes/bootstrap/main.tscn`).

### Windows: your install path

If Godot is installed at `C:\Godot\Godot_v4.7.2-stable_win64.exe`, you can open this project from a terminal:

```text
"C:\Godot\Godot_v4.7.2-stable_win64.exe" --path "C:\Code\darkest-tico"
```

Or double-click **`launch-editor.bat`** in this folder (edit the `GODOT` line inside if your path changes).

## Project layout

| Path | Purpose |
|------|---------|
| `project.godot` | Godot project; autoloads `GameState`, `SaveService` |
| `data/` | JSON heroes/skills (authoring) |
| `scenes/bootstrap/main.tscn` | Main scene: swaps hub and combat |
| `scenes/hacienda/hacienda_hub.tscn` | Hub UI |
| `scenes/combat/combat_scene.tscn` | Combat vertical slice |
| `scripts/` | Autoloads, `DataLoader`, `CombatResolver`, UI controllers |
| `docs/` | GDD and specs (not loaded by the game) |
| `tools/validate_data.py` | Data cross-reference check (no Godot needed) |

## Vertical slice

- **Hacienda hub**: roster summary, **Iniciar expedición** → point-to-point **map** (luz, comida, nodos).
- **Expedición**: region JSON under `data/regions/`; trap/curio/camp/objective stubs; combat hands off to combat scene with per-node enemies.
- **Combat**: 4v1, initiative per round, HP/stress, **Al Borde** at 0 HP; rewards during expeditions come from node JSON (hub-only “arcade” combat removed when not on mission).
- **Save**: `user://save.json` (colones, week, party), previous save kept as `save.json.bak`. Mid-expedition state is **not** persisted (abandon on load). Headless `-s` scripts (tests, tools) never read or write it.

## Art

- Hub background: procedural color if `assets/ui_bg/hub_bg.png` is missing; drop a valid PNG there (e.g. from [tools/sd_export.py](tools/sd_export.py) or your SD UI) to override. See [docs/11-stable-diffusion-pipeline.md](docs/11-stable-diffusion-pipeline.md).

## License

All rights reserved unless you add a license file.
