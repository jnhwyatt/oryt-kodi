#!/usr/bin/env python3
"""Generate Oryt addon icon + fanart. Run: python tools/gen_artwork.py"""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(HERE, '..', 'plugin.video.oryttv', 'resources', 'media')
BG = (10, 10, 15)        # #0a0a0f
CYAN = (0, 240, 255)     # #00f0ff
WHITE = (255, 255, 255)

FONT_CANDIDATES = [
    'C:/Windows/Fonts/arialbd.ttf',
    'C:/Windows/Fonts/segoeuib.ttf',
    'C:/Windows/Fonts/arial.ttf',
]

def load_font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()

def draw_logo(draw, center, size):
    font = load_font(size)
    text, dot = 'oryt', '.'
    tw = draw.textlength(text, font=font)
    dw = draw.textlength(dot, font=font)
    total = tw + dw
    x = center[0] - total / 2
    # vertically center using bbox of the text part
    bbox = font.getbbox(text)
    y = center[1] - (bbox[3] - bbox[1]) / 2 - bbox[1]
    draw.text((x, y), text, font=font, fill=WHITE)
    draw.text((x + tw, y), dot, font=font, fill=CYAN)

def main():
    os.makedirs(MEDIA, exist_ok=True)

    icon = Image.new('RGB', (512, 512), BG)
    d = ImageDraw.Draw(icon)
    draw_logo(d, (256, 256), 160)
    icon.save(os.path.join(MEDIA, 'icon.png'))

    fanart = Image.new('RGB', (1920, 1080), BG)
    d = ImageDraw.Draw(fanart)
    # subtle cyan baseline accent
    d.rectangle([0, 1076, 1920, 1080], fill=CYAN)
    draw_logo(d, (960, 540), 300)
    fanart.save(os.path.join(MEDIA, 'fanart.png'))
    print('Wrote icon.png + fanart.png to', os.path.normpath(MEDIA))

if __name__ == '__main__':
    main()
