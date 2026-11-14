#!/usr/bin/env python3
"""Draws the Swifs paper-plane logo in code (no design tool needed).

Writes into app/assets/:
  icon.png             full icon: orange rounded square + plane (legacy launcher)
  icon_foreground.png  transparent plane for the Android adaptive icon
  splash_plane.png     transparent plane for the native splash (no box)

Run: python3 scripts/make_icons.py   (needs: pip install pillow)
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, '..', 'app', 'assets')

ORANGE = (255, 87, 51, 255)      # #FF5733 brand orange
REF = 1254.0                     # reference canvas the plane points come from
CENTER = (631.0, 624.0)          # centre of the plane's bounding box
SS = 4                           # supersampling factor for smooth edges

WHITE = (255, 255, 255, 255)
LIGHT = (255, 184, 166, 255)
FOLD = (253, 143, 122, 255)

PLANE = [
    ([(250, 585), (1012, 358), (422, 657)], WHITE),                      # left wing
    ([(422, 657), (1012, 358), (545, 715), (485, 890)], LIGHT),          # body shadow
    ([(1012, 358), (815, 888), (545, 715)], WHITE),                      # right wing
    ([(545, 715), (485, 890), (645, 785)], FOLD),                        # fold
]


def render(size, scale, background=None, radius_ratio=0.0):
    big = size * SS
    img = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if background is not None:
        draw.rounded_rectangle([0, 0, big - 1, big - 1],
                               radius=big * radius_ratio, fill=background)

    def to_canvas(x, y):
        return ((x - CENTER[0]) / REF * big * scale + big / 2,
                (y - CENTER[1]) / REF * big * scale + big / 2)

    for points, color in PLANE:
        draw.polygon([to_canvas(x, y) for x, y in points], fill=color)
    return img.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(ASSETS, exist_ok=True)
    # Full icon: rounded orange square (~22% corner radius), plane centred
    render(1024, 0.72, background=ORANGE, radius_ratio=0.215).save(
        os.path.join(ASSETS, 'icon.png'))
    # Adaptive foreground: plane only, kept inside the 66% safe circle
    render(1024, 0.72).save(os.path.join(ASSETS, 'icon_foreground.png'))
    # Splash: plane only, kept inside the central circle Android 12 shows
    render(1152, 0.6).save(os.path.join(ASSETS, 'splash_plane.png'))
    print('Wrote icon.png, icon_foreground.png, splash_plane.png to', os.path.abspath(ASSETS))


if __name__ == '__main__':
    main()
