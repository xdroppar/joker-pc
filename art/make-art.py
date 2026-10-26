"""Installer art from the game's own icon and an in-game frame.

    python -I art/make-art.py <AppIcon.png> <in-game frame.png>

Writes art/joker.ico (16-256 px), the setup wizard's side panel (art/wizard-*.bmp, one per DPI step) and its small
corner image (art/small-*.bmp), all from the two inputs so a new icon or frame only means running this again.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ONYX = (18, 17, 16)

icon = Image.open(sys.argv[1]).convert('RGBA')
frame = Image.open(sys.argv[2]).convert('RGB')

# The icon file: the chip cut out of its square, so it sits round on the desktop rather than as a dark tile.
w = icon.width
mask = Image.new('L', icon.size, 0)
ImageDraw.Draw(mask).ellipse((w * 0.135, w * 0.135, w * 0.865, w * 0.865), fill=255)
chip = icon.copy()
chip.putalpha(mask.filter(ImageFilter.GaussianBlur(1.5)))
chip = chip.crop((int(w * 0.12), int(w * 0.12), int(w * 0.88), int(w * 0.88)))
chip.save(os.path.join(HERE, 'joker.ico'), sizes=[(s, s) for s in (16, 20, 24, 32, 40, 48, 64, 128, 256)])

# Side panel: a tall slice of the table, darkened toward the bottom, with the chip near the top.
for scale, (pw, ph) in ((100, (164, 314)), (125, (205, 393)), (150, (246, 471)), (200, (328, 628))):
    fw, fh = frame.size
    cw = int(fh * pw / ph)
    left = int(fw * 0.5 - cw * 0.5)
    panel = frame.crop((left, 0, left + cw, fh)).resize((pw, ph), Image.LANCZOS)
    shade = Image.new('L', (pw, ph))
    for y in range(ph):
        t = y / ph
        shade.paste(int(255 * (0.35 + 0.55 * t)), (0, y, pw, y + 1))
    panel = Image.composite(Image.new('RGB', (pw, ph), ONYX), panel, shade)
    size = int(pw * 0.62)
    c = chip.resize((size, size), Image.LANCZOS)
    panel.paste(c, ((pw - size) // 2, int(ph * 0.08)), c)
    panel.save(os.path.join(HERE, f'wizard-{scale}.bmp'))

for scale, px in ((100, 55), (125, 69), (150, 83), (200, 110)):
    small = Image.new('RGB', (px, px), (255, 255, 255))
    c = chip.resize((px - 4, px - 4), Image.LANCZOS)
    small.paste(c, (2, 2), c)
    small.save(os.path.join(HERE, f'small-{scale}.bmp'))

print('art written to', HERE)
