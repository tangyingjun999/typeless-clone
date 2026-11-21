#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate Assets.xcassets/AppIcon.appiconset PNGs (pure stdlib, no PIL).

Deterministic so local and CI output are byte-identical.
Design: blue vertical gradient (#2B6EFF -> #0D3FCC) + white waveform bars.
"""
import json
import os
import struct
import zlib

SS = 4  # supersample factor

SPECS = [
    ("20x20", "2x", 40), ("20x20", "3x", 60),
    ("29x29", "2x", 58), ("29x29", "3x", 87),
    ("40x40", "2x", 80), ("40x40", "3x", 120),
    ("60x60", "2x", 120), ("60x60", "3x", 180),
]

TOP = (0x2B, 0x6E, 0xFF)
BOT = (0x0D, 0x3F, 0xCC)
BARS = [0.30, 0.58, 0.86, 0.55, 0.36]


def render(size):
    S = size * SS
    px = bytearray(S * S * 3)
    # gradient background
    for y in range(S):
        t = y / float(S - 1)
        r = int(TOP[0] + (BOT[0] - TOP[0]) * t)
        g = int(TOP[1] + (BOT[1] - TOP[1]) * t)
        b = int(TOP[2] + (BOT[2] - TOP[2]) * t)
        row = bytes((r, g, b)) * S
        px[y * S * 3:(y + 1) * S * 3] = row

    # waveform bars (white, rounded)
    bw = S * 0.075
    gap = S * 0.045
    total = len(BARS) * bw + (len(BARS) - 1) * gap
    x = (S - total) / 2.0
    cy = S / 2.0
    rects = []
    for h in BARS:
        hh = S * 0.52 * h
        rects.append((x, cy - hh / 2.0, x + bw, cy + hh / 2.0))
        x += bw + gap

    rad = bw / 2.0
    for (x0, y0, x1, y1) in rects:
        iy0 = max(0, int(y0) - 1)
        iy1 = min(S, int(y1) + 2)
        ix0 = max(0, int(x0) - 1)
        ix1 = min(S, int(x1) + 2)
        for yy in range(iy0, iy1):
            fy = yy + 0.5
            for xx in range(ix0, ix1):
                fx = xx + 0.5
                cx = min(max(fx, x0 + rad), x1 - rad)
                cyc = min(max(fy, y0 + rad), y1 - rad)
                dx = fx - cx
                dy = fy - cyc
                if dx * dx + dy * dy <= rad * rad:
                    o = (yy * S + xx) * 3
                    px[o:o + 3] = b"\xff\xff\xff"

    # box downsample
    out = bytearray(size * size * 3)
    n = SS * SS
    for y in range(size):
        for x in range(size):
            r = g = b = 0
            for sy in range(SS):
                base = ((y * SS + sy) * S + x * SS) * 3
                for sx in range(SS):
                    o = base + sx * 3
                    r += px[o]
                    g += px[o + 1]
                    b += px[o + 2]
            o = (y * size + x) * 3
            out[o] = r // n
            out[o + 1] = g // n
            out[o + 2] = b // n
    return bytes(out), size


def write_png(path, rgb, size):
    raw = bytearray()
    stride = size * 3
    for y in range(size):
        raw.append(0)  # filter: none
        raw += rgb[y * stride:(y + 1) * stride]
    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
           + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    res = os.path.join(here, "..", "Resources", "Assets.xcassets")
    icon_set = os.path.join(res, "AppIcon.appiconset")
    os.makedirs(icon_set, exist_ok=True)
    with open(os.path.join(res, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)
    images = []
    for pt, scale, px in SPECS:
        rgb, size = render(px)
        name = "icon-%s@%s.png" % (pt, scale)
        write_png(os.path.join(icon_set, name), rgb, size)
        images.append({"filename": name, "idiom": "iphone", "scale": scale, "size": pt})
        print("wrote", name, size)
    with open(os.path.join(icon_set, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=2)


if __name__ == "__main__":
    main()
