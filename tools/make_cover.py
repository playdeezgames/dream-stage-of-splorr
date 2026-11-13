#!/usr/bin/env python3
"""Draws the itch.io cover, assets/cover.png (630x500): the title in DINOBYTE over a night sky and a
frame of the game itself (the play scene from src/game/dump_test.odin, rendered natively), doubled.
Run: python3 -I tools/make_cover.py   (needs odin on PATH and Pillow)"""
import os
import subprocess
import tempfile
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
font = Image.open(os.path.join(ROOT, 'tools/data/dbyte_1x.png')).convert('RGBA')
W, H = 630, 500
SKY, WHITE, LIGHT, YELLOW, MID = (26, 28, 44), (244, 244, 244), (148, 176, 194), (255, 205, 117), (86, 108, 134)

with tempfile.TemporaryDirectory() as d:
    ppm = os.path.join(d, 'play.ppm')
    subprocess.run(['odin', 'test', 'src/game', '-collection:tggd=src', '-define:ODIN_TEST_THREADS=1',
                    '-define:DUMP_PLAY=' + ppm, '-define:ODIN_TEST_NAMES=game.dump_play'],
                   cwd=ROOT, check=True, capture_output=True)
    frame = Image.open(ppm).convert('RGB')

img = Image.new('RGB', (W, H), SKY)
for i in range(90):
    img.putpixel(((i * 197 + 31) % W, (i * 113 + 7) % 120), MID if i % 3 else LIGHT)

def text(s, y, scale, color):
    x0 = (W - len(s) * 6 * scale) // 2
    for i, ch in enumerate(s.encode('cp437')):
        cx, cy = (ch % 16) * 6, (ch // 16) * 8
        for gy in range(8):
            for gx in range(6):
                if font.getpixel((cx + gx, cy + gy))[3] > 0:
                    for sy in range(scale):
                        for sx in range(scale):
                            img.putpixel((x0 + (i * 6 + gx) * scale + sx, y + gy * scale + sy), color)

text("COUNTING SHEEP", 22, 5, WHITE)
text("of SPLORR!!", 70, 3, LIGHT)
# The moon, the fold, the fence and the pasture under it, doubled, with the words on the sky (the
# title, the cut label, the pegboard and the hints) painted out.
for box in [(0, 0, 96, 26), (0, 60, 96, 104), (208, 0, 320, 104)]:
    frame.paste(SKY, box)
crop = frame.crop((24, 0, 304, 196)).resize((560, 392), Image.NEAREST)
img.paste(crop, ((W - 560) // 2, 104))
img.save(os.path.join(ROOT, 'assets/cover.png'))
print("assets/cover.png", img.size)
