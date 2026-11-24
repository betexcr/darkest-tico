#!/usr/bin/env python3
"""P4-04a: build the game's sound effects from CC0 packs downloaded from OpenGameArt.

    python3 tools/import_sfx.py <packs_dir>

<packs_dir> holds each pack's zip extracted into its own folder, named as in PACKS below
(download: https://opengameart.org/content/<page>; every pack is CC0, checked on its page).
For every sound id in SOUNDS the chosen files are converted with ffmpeg to mono 44.1 kHz
OGG Vorbis, leading silence trimmed and peak-normalized to -1 dBFS, written to
assets/audio/sfx/<pack>/<name>.ogg with a .metadata.json (source, author, license), and
data/sfx.json is rewritten (id -> files, volume_db, pitch_jitter, bus). Rerunnable.
Only audio files are read from the packs; nothing in them is executed.
"""
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio" / "sfx"

# folder name -> short pack id, OpenGameArt page, author
PACKS = {
    "rpg_sound_pack": ("artisticdude", "rpg-sound-pack", "artisticdude"),
    "RPGsounds_Kenney": ("kenney_rpg", "50-rpg-sound-effects", "Kenney (kenney.nl)"),
    "kenney_interfaceSounds": ("kenney_ui", "interface-sounds", "Kenney (kenney.nl)"),
    "80-CC0-RPG-SFX_0": ("rubberduck_rpg", "80-cc0-rpg-sfx", "rubberduck"),
    "100-CC0-SFX_0": ("rubberduck_100", "100-cc0-sfx", "rubberduck"),
}

UI = "UI"
SFX = "SFX"

# id -> (bus, volume_db, pitch_jitter, [(pack folder, file name), ...])
SOUNDS = {
    # --- UI (every button, dropdown, window) ---
    "ui_click": (UI, -8, 0.05, [("kenney_interfaceSounds", f"click_00{i}.ogg") for i in (1, 2, 3)]),
    "ui_hover": (UI, -24, 0.08, [("kenney_interfaceSounds", "tick_001.ogg"), ("kenney_interfaceSounds", "tick_002.ogg")]),
    "ui_denied": (UI, -10, 0.0, [("kenney_interfaceSounds", "error_004.ogg")]),
    "ui_open": (UI, -10, 0.03, [("kenney_interfaceSounds", "open_001.ogg"), ("kenney_interfaceSounds", "open_002.ogg")]),
    "ui_close": (UI, -10, 0.03, [("kenney_interfaceSounds", "close_001.ogg"), ("kenney_interfaceSounds", "close_002.ogg")]),
    "ui_confirm": (UI, -8, 0.0, [("kenney_interfaceSounds", "confirmation_001.ogg"), ("kenney_interfaceSounds", "confirmation_002.ogg")]),
    "ui_toggle": (UI, -10, 0.03, [("kenney_interfaceSounds", "toggle_001.ogg"), ("kenney_interfaceSounds", "toggle_002.ogg")]),
    "ui_page": (UI, -8, 0.08, [("RPGsounds_Kenney", "bookFlip1.ogg"), ("RPGsounds_Kenney", "bookFlip2.ogg"), ("RPGsounds_Kenney", "bookFlip3.ogg")]),
    # --- Hub ---
    "buy": (SFX, -6, 0.05, [("RPGsounds_Kenney", "handleCoins.ogg"), ("RPGsounds_Kenney", "handleCoins2.ogg")]),
    "sell": (SFX, -6, 0.05, [("80-CC0-RPG-SFX_0", f"item_coins_0{i}.ogg") for i in (1, 2, 3, 4)]),
    "equip": (SFX, -6, 0.06, [("rpg_sound_pack", "armor-light.wav"), ("rpg_sound_pack", "chainmail1.wav"), ("rpg_sound_pack", "cloth-heavy.wav")]),
    "unequip": (SFX, -8, 0.06, [("rpg_sound_pack", "cloth.wav"), ("RPGsounds_Kenney", "dropLeather.ogg")]),
    "upgrade": (SFX, -6, 0.04, [("100-CC0-SFX_0", f"tools_0{i}.ogg") for i in (1, 2, 3)]),
    "skill_learn": (SFX, -6, 0.0, [("RPGsounds_Kenney", "bookOpen.ogg")]),
    "hire": (SFX, -8, 0.03, [("RPGsounds_Kenney", "doorOpen_1.ogg"), ("RPGsounds_Kenney", "doorOpen_2.ogg")]),
    "dismiss": (SFX, -8, 0.03, [("RPGsounds_Kenney", "doorClose_1.ogg"), ("RPGsounds_Kenney", "doorClose_2.ogg")]),
    "week": (SFX, -8, 0.0, [("100-CC0-SFX_0", "bell_01.ogg")]),
    "heal_town": (SFX, -8, 0.04, [("rpg_sound_pack", "bottle.wav")]),
    # --- Combat ---
    "attack": (SFX, -5, 0.08, [("rpg_sound_pack", "swing.wav"), ("rpg_sound_pack", "swing2.wav"), ("rpg_sound_pack", "swing3.wav")]),
    "cast": (SFX, -6, 0.06, [("rpg_sound_pack", "spell.wav"), ("rpg_sound_pack", "magic1.wav"), ("80-CC0-RPG-SFX_0", "spell_01.ogg")]),
    "hit": (SFX, -4, 0.08, [("100-CC0-SFX_0", f"hit_0{i}.ogg") for i in (1, 2, 3, 4)]),
    "crit": (SFX, -3, 0.04, [("100-CC0-SFX_0", "slam_01.ogg"), ("100-CC0-SFX_0", "slam_02.ogg")]),
    "miss": (SFX, -12, 0.1, [("RPGsounds_Kenney", "knifeSlice.ogg"), ("RPGsounds_Kenney", "knifeSlice2.ogg")]),
    "guard": (SFX, -6, 0.05, [("80-CC0-RPG-SFX_0", f"metal_0{i}.ogg") for i in (1, 2, 3)]),
    "heal": (SFX, -7, 0.06, [("rpg_sound_pack", "bubble.wav"), ("rpg_sound_pack", "bubble2.wav"), ("rpg_sound_pack", "bubble3.wav")]),
    "buff": (SFX, -8, 0.05, [("80-CC0-RPG-SFX_0", "item_gem_01.ogg"), ("80-CC0-RPG-SFX_0", "item_gem_02.ogg")]),
    "debuff": (SFX, -8, 0.05, [("80-CC0-RPG-SFX_0", "creature_slime_01.ogg"), ("80-CC0-RPG-SFX_0", "creature_slime_02.ogg")]),
    "stun": (SFX, -8, 0.03, [("rpg_sound_pack", "metal-ringing.wav")]),
    "stress": (SFX, -10, 0.06, [("100-CC0-SFX_0", f"weird_0{i}.ogg") for i in (1, 2, 3)]),
    "stress_relief": (SFX, -10, 0.04, [("100-CC0-SFX_0", "bell_02.ogg")]),
    "al_borde": (SFX, -6, 0.0, [("100-CC0-SFX_0", "gong_01.ogg")]),
    "hero_death": (SFX, -4, 0.0, [("100-CC0-SFX_0", "gong_02.ogg")]),
    "enemy_hurt": (SFX, -9, 0.08, [("rpg_sound_pack", f"shade{i}.wav") for i in (1, 3, 5)] + [("rpg_sound_pack", f"mnstr{i}.wav") for i in (2, 4)]),
    "enemy_death": (SFX, -6, 0.06, [("80-CC0-RPG-SFX_0", "creature_die_01.ogg"), ("rpg_sound_pack", "shade15.wav"), ("rpg_sound_pack", "ogre5.wav")]),
    "quebranto": (SFX, -6, 0.0, [("100-CC0-SFX_0", "weird_04.ogg"), ("100-CC0-SFX_0", "weird_05.ogg")]),
    "virtud": (SFX, -6, 0.0, [("100-CC0-SFX_0", "bell_03.ogg")]),
    "victory": (SFX, -6, 0.0, [("kenney_interfaceSounds", "confirmation_003.ogg")]),
    "defeat": (SFX, -6, 0.0, [("100-CC0-SFX_0", "gong_02.ogg")]),
    "retreat": (SFX, -8, 0.05, [("RPGsounds_Kenney", f"footstep0{i}.ogg") for i in (5, 6, 7)]),
    "ambush": (SFX, -5, 0.04, [("80-CC0-RPG-SFX_0", "creature_roar_01.ogg"), ("80-CC0-RPG-SFX_0", "creature_roar_02.ogg")]),
    # --- Expedition ---
    "footstep": (SFX, -12, 0.1, [("RPGsounds_Kenney", f"footstep0{i}.ogg") for i in range(5)]),
    "door": (SFX, -9, 0.05, [("RPGsounds_Kenney", "creak1.ogg"), ("RPGsounds_Kenney", "creak2.ogg"), ("RPGsounds_Kenney", "creak3.ogg")]),
    "trap": (SFX, -5, 0.04, [("100-CC0-SFX_0", "spring_01.ogg"), ("80-CC0-RPG-SFX_0", "chain_01.ogg")]),
    "disarm": (SFX, -7, 0.04, [("80-CC0-RPG-SFX_0", "lock_01.ogg"), ("RPGsounds_Kenney", "metalClick.ogg")]),
    "curio": (SFX, -8, 0.04, [("100-CC0-SFX_0", "wooded_box_open.ogg"), ("80-CC0-RPG-SFX_0", "item_wood_01.ogg")]),
    "loot": (SFX, -6, 0.05, [("rpg_sound_pack", "coin.wav"), ("rpg_sound_pack", "coin2.wav"), ("rpg_sound_pack", "coin3.wav")]),
    "camp": (SFX, -7, 0.03, [("80-CC0-RPG-SFX_0", "spell_fire_01.ogg"), ("80-CC0-RPG-SFX_0", "spell_fire_03.ogg")]),
    "eat": (SFX, -7, 0.05, [("100-CC0-SFX_0", "dishes_01.ogg"), ("RPGsounds_Kenney", "metalPot1.ogg")]),
    "light": (SFX, -10, 0.04, [("80-CC0-RPG-SFX_0", "spell_fire_02.ogg")]),
    "item_use": (SFX, -8, 0.05, [("rpg_sound_pack", "bottle.wav"), ("RPGsounds_Kenney", "handleSmallLeather.ogg")]),
}


def find(packs: pathlib.Path, folder: str, name: str) -> pathlib.Path:
    hits = [p for p in (packs / folder).rglob(name) if "__MACOSX" not in p.parts]
    if len(hits) != 1:
        sys.exit(f"{folder}/{name}: found {len(hits)} files")
    return hits[0]


def peak_db(src: pathlib.Path) -> float:
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(src), "-af", "volumedetect", "-f", "null", "-"],
                       capture_output=True, text=True)
    m = re.search(r"max_volume: (-?[\d.]+) dB", r.stderr)
    return float(m.group(1)) if m else 0.0


def convert(src: pathlib.Path, dst: pathlib.Path) -> None:
    gain = -1.0 - peak_db(src)
    dst.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(src),
                    "-af", f"silenceremove=start_periods=1:start_threshold=-50dB,volume={gain:.2f}dB",
                    "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", str(dst)], check=True)


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    packs = pathlib.Path(sys.argv[1])
    table = {}
    done = {}
    for sid, (bus, vol, jitter, files) in SOUNDS.items():
        paths = []
        for folder, name in files:
            short, page, author = PACKS[folder]
            rel = f"{short}/{pathlib.Path(name).stem}.ogg"
            if rel not in done:
                src = find(packs, folder, name)
                dst = OUT / rel
                convert(src, dst)
                meta = {"kind": "sound effect", "pack": folder, "original_file": str(src.relative_to(packs / folder)),
                        "author": author, "source": f"https://opengameart.org/content/{page}",
                        "license": "CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/)",
                        "processing": "ffmpeg: mono 44.1 kHz, leading silence trimmed, peak -1 dBFS, OGG Vorbis q5 (tools/import_sfx.py)"}
                (OUT / (rel + ".metadata.json")).write_text(json.dumps(meta, indent=2) + "\n")
                done[rel] = True
            paths.append(f"res://assets/audio/sfx/{rel}")
        table[sid] = {"bus": bus, "volume_db": vol, "pitch_jitter": jitter, "files": paths}
    out = {"_doc": "Sound effects (P4-04a). Sfx.play(id) picks one of files at random, on bus (SFX | UI), at volume_db, pitch 1 ± pitch_jitter. Files and metadata come from CC0 packs via tools/import_sfx.py (credits: assets/audio/CREDITS.md). Unknown ids are silent.",
           "sounds": table}
    (ROOT / "data" / "sfx.json").write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n")
    print(f"{len(table)} sounds, {len(done)} files")


if __name__ == "__main__":
    main()
