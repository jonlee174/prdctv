"""Composes the App Store product page header and search results art from iPhone screenshots.

Usage: python3 scripts/store_art.py <screenshot folder> <output folder>
The folder holds board.png, tags.png and calendar.png from the 6.9 inch simulator.
"""
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SHOTS, OUT = Path(sys.argv[1]), Path(sys.argv[2])
LOGO_SVG = Path("prdctv/Resources/Assets.xcassets/LogoFull.imageset/LogoFull.svg")
TOP, BOTTOM = (142, 217, 115), (69, 143, 50)  # logo green to the Need green


def gradient(size):
    """Vertical gradient from the logo green to the darker Need green."""
    w, h = size
    column = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        column.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return column.resize(size)


def logo(height, color=(255, 255, 255)):
    """The wordmark from the asset catalog, recolored, at a given height."""
    rendered = OUT / "logo-render.png"
    # Drawn as vectors at full size. Rasterizing the small SVG and scaling it up comes out blocky.
    subprocess.run(["swift", "scripts/render_svg.swift", str(LOGO_SVG), str(rendered), str(height)],
                   check=True, capture_output=True)
    mask = Image.open(rendered).convert("RGBA").split()[3]
    rendered.unlink()
    mark = Image.new("RGBA", mask.size, color + (255,))
    mark.putalpha(mask)
    return mark


def phone(name, height):
    """A screenshot with rounded corners and a soft shadow, at a given height."""
    shot = Image.open(SHOTS / name).convert("RGB")
    width = round(shot.width * height / shot.height)
    shot = shot.resize((width, height), Image.LANCZOS)
    radius = round(width * 0.13)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, width - 1, height - 1], radius, fill=255)
    pad = round(height * 0.05)
    card = Image.new("RGBA", (width + pad * 2, height + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", card.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 90), (pad, pad + round(pad * 0.4)), mask)
    card = Image.alpha_composite(card, shadow.filter(ImageFilter.GaussianBlur(pad * 0.45)))
    framed = Image.new("RGBA", shot.size)
    framed.paste(shot, (0, 0), mask)
    card.alpha_composite(framed, (pad, pad))
    return card


def place_row(canvas, cards, center_x, center_y, gap):
    """Places cards side by side with a gap between their screens, centered on a point."""
    # Each card has shadow padding around the screen, so the gap is measured between screens.
    pad = round(cards[0].height * 0.05 / 1.1)
    total = sum(c.width - 2 * pad for c in cards) + gap * (len(cards) - 1)
    x = round(center_x - total / 2) - pad
    for card in cards:
        canvas.alpha_composite(card, (x, round(center_y - card.height / 2)))
        x += card.width - 2 * pad + gap


def header():
    """3840 by 1646, 21 by 9. Wordmark at the left, three phones at the right."""
    canvas = gradient((3840, 1646)).convert("RGBA")
    mark = logo(230)
    canvas.alpha_composite(mark, (300, round((1646 - mark.height) / 2)))
    cards = [phone(name, 1380) for name in ("board.png", "tags.png", "calendar.png")]
    place_row(canvas, cards, center_x=2620, center_y=823, gap=90)
    return canvas


def search_result():
    """3840 by 2560, 3 by 2. Wordmark at the top, three phones below."""
    canvas = gradient((3840, 2560)).convert("RGBA")
    mark = logo(210)
    canvas.alpha_composite(mark, (round((3840 - mark.width) / 2), 170))
    cards = [phone(name, 1880) for name in ("board.png", "tags.png", "calendar.png")]
    place_row(canvas, cards, center_x=1920, center_y=1500, gap=130)
    return canvas


OUT.mkdir(parents=True, exist_ok=True)
for name, art in [("header-3840x1646.png", header()), ("search-results-3840x2560.png", search_result())]:
    art.convert("RGB").save(OUT / name)  # no alpha, as App Store Connect requires
    print(OUT / name, art.size)
