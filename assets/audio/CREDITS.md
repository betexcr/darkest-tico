# Sound credits (P4-04a)

Every sound effect in `assets/audio/sfx/` comes from a CC0 (public domain) pack on OpenGameArt,
converted by `tools/import_sfx.py` (mono 44.1 kHz OGG Vorbis, leading silence trimmed, peak -1 dBFS).
Each file has a `.metadata.json` with its pack, original file name, author, source and license.
CC0 needs no attribution; it is given anyway.

| Folder | Pack | Author | Source | License |
|---|---|---|---|---|
| `sfx/artisticdude/` | RPG Sound Pack | artisticdude | https://opengameart.org/content/rpg-sound-pack | CC0 1.0 |
| `sfx/kenney_rpg/` | 50 RPG sound effects | Kenney (kenney.nl) | https://opengameart.org/content/50-rpg-sound-effects | CC0 1.0 |
| `sfx/kenney_ui/` | Interface Sounds | Kenney (kenney.nl) | https://opengameart.org/content/interface-sounds | CC0 1.0 |
| `sfx/rubberduck_rpg/` | 80 CC0 RPG SFX | rubberduck | https://opengameart.org/content/80-cc0-rpg-sfx | CC0 1.0 |
| `sfx/rubberduck_100/` | 100 CC0 SFX | rubberduck | https://opengameart.org/content/100-cc0-sfx | CC0 1.0 |

To change which file plays for an event, edit `SOUNDS` in `tools/import_sfx.py` and rerun it with the
packs extracted into one folder (each zip into a folder named as in `PACKS`); it rewrites `data/sfx.json`.
