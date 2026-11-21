#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Icon-set guard (stdlib only, CI-safe).

The AppIcon.appiconset PNGs are rendered offline from the original app artwork
(`tools/icon-master.png`, extracted from the decrypted reference IPA) by
`tools/render_icons_local.py` (needs Pillow) and committed to the repo, so CI
does not need an image library.  This script only validates that the committed
set is complete and consistent with its Contents.json; it never rewrites files.
"""
import json
import os
import struct
import sys

SET_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "Resources", "Assets.xcassets", "AppIcon.appiconset")

EXPECTED = [
    ("20x20", "2x", 40), ("20x20", "3x", 60),
    ("29x29", "2x", 58), ("29x29", "3x", 87),
    ("40x40", "2x", 80), ("40x40", "3x", 120),
    ("60x60", "2x", 120), ("60x60", "3x", 180),
    ("1024x1024", "1x", 1024),
]


def png_size(path):
    with open(path, "rb") as fh:
        head = fh.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG: %s" % path)
    return struct.unpack(">II", head[16:24])


def main():
    problems = []
    contents_path = os.path.join(SET_DIR, "Contents.json")
    if not os.path.exists(contents_path):
        problems.append("missing Contents.json")
        contents = {"images": []}
    else:
        with open(contents_path, encoding="utf-8") as fh:
            contents = json.load(fh)

    listed = {im.get("filename"): im for im in contents.get("images", [])}
    for size, scale, px in EXPECTED:
        name = "icon-%s@%s.png" % (size, scale)
        path = os.path.join(SET_DIR, name)
        if name not in listed:
            problems.append("not listed in Contents.json: " + name)
        if not os.path.exists(path):
            problems.append("missing file: " + name)
            continue
        w, h = png_size(path)
        if (w, h) != (px, px):
            problems.append("%s is %dx%d, expected %dx%d" % (name, w, h, px, px))
        else:
            print("ok  %-24s %4dx%-4d %8d bytes" % (name, w, h, os.path.getsize(path)))

    if problems:
        print("\nICON SET INVALID:")
        for p in problems:
            print("  -", p)
        return 1
    print("\nicon set complete: %d files" % len(EXPECTED))
    return 0


if __name__ == "__main__":
    sys.exit(main())
