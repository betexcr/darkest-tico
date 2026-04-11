# Stable Diffusion art pipeline (local)

Target generator: **http://127.0.0.1:7860/** (typical **Automatic1111 Web UI** default port).

## 1) Confirm API mode

- **Automatic1111:** enable the API (often launch with `--api` or enable in settings). The REST endpoint is usually:
  - `POST http://127.0.0.1:7860/sdapi/v1/txt2img`
- **ComfyUI** and other UIs use **different** URLs and payloads. This repo’s `tools/sd_export.py` is written for the A1111-style JSON body.

## 2) Folder layout in the game repo

| Folder | Use |
|--------|-----|
| `assets/portraits/` | Hero / NPC busts (~512–768 square PNG) |
| `assets/enemies/` | Enemy sprites or portraits |
| `assets/ui_bg/` | Hub / combat backgrounds (e.g. 1280×720 or 1920×1080) |
| `assets/map_nodes/` | Optional icons for map nodes |

Naming examples: `hero_campesino_portrait.png`, `enemy_espanto_01.png`, `hub_bg.png`.

The hub scene references `res://assets/ui_bg/hub_bg.png`. Replace that file with your SD output and re-run Godot (or reimport).

## 3) Style line (prompt bible)

Use one **global style suffix** on every generation so the game reads as one art direction:

> dark fantasy illustration, Darkest Dungeon inspired, high contrast, hand-painted texture, not photorealistic, muted colors, subtle fog, Costa Rican hacienda and cloud-forest horror, game asset, centered composition

**Negative prompt (baseline):**

> photorealistic, 3d render, glossy, anime, watermark, signature, text, logo, modern UI, lowres, blurry

Per asset, prepend a **subject line** (character, creature, environment). Keep tone aligned with [08-content-standards-satire.md](08-content-standards-satire.md): avoid harmful caricature in prompts.

## 4) Suggested sizes

- Portraits / icons: **512×512** or **768×768**
- Hub background: **1920×1080** or **1280×720** (match or exceed window size; TextureRect can scale)

Export **PNG**; power-of-two dimensions are convenient for GPUs.

## 5) Automation

See [tools/sd_export.py](../tools/sd_export.py): optional stdlib-only `urllib` call to `txt2img`, decode base64, write into `assets/`. Requires Python 3 and a running API-enabled UI.

## 6) Placeholder without SD

The hub loads `assets/ui_bg/hub_bg.png` with `Image.load()` if present; otherwise it uses a **procedural** dark texture in code. A stdlib PNG writer in `tools/make_placeholder_png.py` may not match Godot’s importer; prefer exporting PNG from SD or from an image editor, or rely on the built-in procedural fallback.
