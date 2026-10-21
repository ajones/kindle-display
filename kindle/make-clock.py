#!/usr/bin/env python3
"""Pre-render one PNG per minute (HHMM.png, 24h names) for the Kindle to draw
over the dashboard's clock, so the clock can tick without Wi-Fi.

Usage: python3 make-clock.py Roboto.ttf kindle/extensions/hadisplay/clock
Needs Pillow. Roboto: https://github.com/google/fonts/raw/main/ofl/roboto/Roboto%5Bwdth,wght%5D.ttf

Size/position were calibrated against the HA render (1236x1648). If the
dashboard layout changes, re-calibrate SIZE/BASELINE and update CLOCK_X/Y in run.sh.
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

SIZE = 84                # Roboto Bold px, matches the render's h1
BOX = (40, 40, 648, 160)  # area the image covers on screen; run.sh CLOCK_X/Y = BOX[0]/BOX[1]
BASELINE = (51, 129)     # text left/baseline on screen

font_path, out = sys.argv[1], sys.argv[2]
font = ImageFont.truetype(font_path, SIZE)
font.set_variation_by_name("Bold")
os.makedirs(out, exist_ok=True)
w, h = BOX[2] - BOX[0], BOX[3] - BOX[1]
origin = (BASELINE[0] - BOX[0], BASELINE[1] - BOX[1])
for hh in range(24):
    for mm in range(60):
        text = f"{(hh % 12) or 12}:{mm:02d} {'AM' if hh < 12 else 'PM'}"
        im = Image.new("L", (w, h), 255)
        ImageDraw.Draw(im).text(origin, text, font=font, fill=0, anchor="ls")
        assert im.getbbox() is not None
        im.save(f"{out}/{hh:02d}{mm:02d}.png", optimize=True)
