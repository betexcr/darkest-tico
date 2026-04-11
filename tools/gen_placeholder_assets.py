#!/usr/bin/env python3
"""Write simple valid PNGs under assets/ (stdlib only). Use SD output to replace later."""

from __future__ import annotations

import os
import struct
import zlib


def _chunk(tag: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(tag + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)


def write_png_rgb(path: str, w: int, h: int, pixel) -> None:
    """pixel(x, y) -> (r, g, b) each 0-255."""
    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            r, g, b = pixel(x, y)
            raw.extend((r, g, b))
    compressed = zlib.compress(bytes(raw), 9)
    data = sig + _chunk(b"IHDR", ihdr) + _chunk(b"IDAT", compressed) + _chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)


def _lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def gradient_bg(path: str, w: int, h: int, top: tuple, bot: tuple) -> None:
    def pix(x: int, y: int) -> tuple:
        t = y / max(h - 1, 1)
        return (
            _lerp(top[0], bot[0], t),
            _lerp(top[1], bot[1], t),
            _lerp(top[2], bot[2], t),
        )

    write_png_rgb(path, w, h, pix)


def solid_square(path: str, size: int, rgb: tuple, accent: tuple | None = None) -> None:
    def pix(x: int, y: int) -> tuple:
        if accent and (x - size // 2) ** 2 + (y - size // 2) ** 2 < (size // 5) ** 2:
            return accent
        return rgb

    write_png_rgb(path, size, size, pix)


def solid_icon(path: str, size: int, rgb: tuple) -> None:
    write_png_rgb(path, size, size, lambda _x, _y: rgb)


def main() -> int:
    root = os.path.join(os.path.dirname(__file__), "..")
    root = os.path.normpath(root)
    ui = os.path.join(root, "assets", "ui_bg")
    portraits = os.path.join(root, "assets", "portraits")
    enemies = os.path.join(root, "assets", "enemies")
    nodes = os.path.join(root, "assets", "map_nodes")

    # Backgrounds (1280x720 — game window base)
    gradient_bg(os.path.join(ui, "hub_bg.png"), 1280, 720, (35, 22, 48), (12, 8, 18))
    gradient_bg(os.path.join(ui, "expedition_bg.png"), 1280, 720, (18, 42, 28), (8, 22, 14))
    gradient_bg(os.path.join(ui, "combat_bg.png"), 1280, 720, (48, 18, 18), (18, 8, 10))

    # Portraits / enemy (512)
    solid_square(os.path.join(portraits, "campesino.png"), 512, (42, 58, 38), (180, 140, 90))
    for hid, col, acc in [
        ("abuela", (55, 45, 62), (200, 180, 160)),
        ("tecnologo", (40, 50, 70), (90, 200, 220)),
        ("montador", (70, 40, 35), (220, 180, 100)),
    ]:
        solid_square(os.path.join(portraits, f"{hid}.png"), 512, col, acc)

    solid_square(os.path.join(enemies, "espanto.png"), 512, (25, 22, 40), (120, 90, 160))
    for eid, rgb in [
        ("sombra_cuadrilla", (30, 30, 45)),
        ("mayordomo_hundido", (35, 40, 55)),
        ("nuboso_spectre", (50, 70, 80)),
        ("cadejo_negro", (20, 20, 28)),
        ("segua_boss", (80, 40, 60)),
    ]:
        solid_square(os.path.join(enemies, f"{eid}.png"), 512, rgb, (140, 100, 130))

    # Map node icons (64)
    for name, rgb in [
        ("combat", (140, 60, 55)),
        ("curio", (100, 80, 140)),
        ("trap", (160, 120, 50)),
        ("camp", (90, 130, 70)),
        ("objective", (200, 180, 90)),
        ("safe", (70, 90, 110)),
    ]:
        solid_icon(os.path.join(nodes, f"{name}.png"), 64, rgb)

    print("Wrote placeholder PNGs under assets/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
