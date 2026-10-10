#!/usr/bin/env python3
"""Supplementary labelled overview; preserve every original screenshot unchanged."""
import math
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageFont

output = Path(sys.argv[1])
frames = sorted(output.glob("*x*/S*.png"))
assert frames, f"No standard screenshots in {output}"
try:
    font = ImageFont.load_default(size=15)
except TypeError:
    font = ImageFont.load_default()
for stale in output.glob("contact-sheet-*.jpg"):
    stale.unlink()
for part, offset in enumerate(range(0, len(frames), 12)):
    group = frames[offset:offset + 12]
    sheet = Image.new("RGB", (1920, math.ceil(len(group) / 4) * 306), "#10191b")
    draw = ImageDraw.Draw(sheet)
    for index, frame in enumerate(group):
        x, y = (index % 4) * 480, (index // 4) * 306
        with Image.open(frame) as original:
            sheet.paste(original.convert("RGB").resize((480, 270), Image.Resampling.LANCZOS), (x, y + 36))
        draw.text((x + 7, y + 3), frame.parent.name + " | " + frame.stem, fill="white", font=font)
        draw.text((x + 7, y + 19), output.name + " | full raw PNG retained separately", fill="#a6c7c9", font=font)
    sheet.save(output / f"contact-sheet-{part + 1:02d}.jpg", quality=95)
print(f"CONTACT_SHEETS_OK images={len(frames)} {output}")
