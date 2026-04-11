#!/usr/bin/env python3
"""Write a tiny solid-color PNG to assets/ui_bg/hub_bg.png (stdlib only)."""
import os
import struct
import zlib

W = H = 512
R, G, B = 28, 18, 38  # dark purple hacienda mood


def png_chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(
        ">I", zlib.crc32(tag + data) & 0xFFFFFFFF
    )


def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "assets", "ui_bg", "hub_bg.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    raw = []
    for y in range(H):
        raw.append(0)  # filter None
        for x in range(W):
            raw.extend([R, G, B])
    compressed = zlib.compress(bytes(raw), 9)
    ihdr = struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", ihdr)
        + png_chunk(b"IDAT", compressed)
        + png_chunk(b"IEND", b"")
    )
    with open(out, "wb") as f:
        f.write(png)
    print("Wrote", out)


if __name__ == "__main__":
    main()
