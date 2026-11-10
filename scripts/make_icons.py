#!/usr/bin/env python3
"""Generate prdctv app icons and the logo-mark image from the logo's vector geometry.

Run from the repo root (or `make icons`). Needs Pillow: `python3 -m pip install Pillow`.
The full logo's wordmark is set in Bauhaus 93 (installed with Microsoft Office) and converted
to vector outlines by scripts/wordmark_outline.swift; the font itself is never bundled.

The mark is redrawn from measurements of the logo (a 93-unit square frame) rather than
scaled from a bitmap, so every size stays sharp:
  - outer square with 12-unit 45° corner cuts at top-right and bottom-left
  - square hole from (6, 7) to (74, 74): thin left/top edges, thick right/bottom edges
"""
import json
import os
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageCms, ImageDraw, ImageFilter

# The logo file is tagged Display P3, where the green is #9FD77F. Converted to sRGB (the space
# these PNGs are saved and tagged in) that is #8ED973; the gray is the same in both.
BG = (142, 217, 115)      # logo background green  sRGB #8ED973 (= Display P3 #9FD77F)
PINK = (224, 86, 155)     # app icon gradient pink #E0569B
MARK = (232, 232, 232)    # logo mark gray         #E8E8E8
SRGB_ICC = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()

# Full logo layout, measured from the logo in its pixels: the mark is 93 px, and the
# wordmark is Bauhaus 93 at 128 px with its baseline level with the bottom of the mark,
# starting 134 px right of the mark's left edge.
WORDMARK = "prdctv"
WORDMARK_SIZE = 128
WORDMARK_ORIGIN = (134, 93)
FONT = os.environ.get("LOGO_FONT", "/Applications/Microsoft Word.app/Contents/Resources/DFonts/Bauhaus93.ttf")
UNITS = 93
OUTER = [(0, 0), (81, 0), (93, 12), (93, 93), (12, 93), (0, 81)]
HOLE = (6, 7, 74, 74)
SS = 4  # supersampling factor for antialiasing

ASSETS = Path("prdctv/Resources/Assets.xcassets")
ICONSET = ASSETS / "AppIcon.appiconset"
MARKSET = ASSETS / "LogoMark.imageset"
FULLSET = ASSETS / "LogoFull.imageset"


def mark_mask(canvas: int, size: float, center=None) -> Image.Image:
    """Antialiased 'L' mask of the mark, `size` px wide, centered on a canvas."""
    big = canvas * SS
    s = size * SS / UNITS
    cx, cy = center if center else (canvas / 2, canvas / 2)
    ox, oy = cx * SS - UNITS * s / 2, cy * SS - UNITS * s / 2
    pt = lambda x, y: (ox + x * s, oy + y * s)
    mask = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon([pt(*p) for p in OUTER], fill=255)
    draw.rectangle([pt(HOLE[0], HOLE[1]), pt(HOLE[2], HOLE[3])], fill=0)
    return mask.resize((canvas, canvas), Image.LANCZOS)


def gradient(size: int) -> Image.Image:
    """Pink at the top left to logo green at the bottom right, blended in linear light so the middle stays clean."""
    def linear(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    def srgb(c):
        c = c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
        return round(max(0, min(1, c)) * 255)

    lut = []
    for i in range(256):
        t = i / 255
        mix = min(1, max(0, (t - 0.25) / 0.5))
        mix = mix * mix * (3 - 2 * mix)  # smoothstep between 25% and 75% of the way
        lut.append(tuple(srgb(linear(a) * (1 - mix) + linear(b) * mix) for a, b in zip(PINK, BG)))
    # t = (x + y) / 2, so the top left is 0 and the bottom right is 1.
    down = Image.linear_gradient("L").resize((size, size))
    across = down.rotate(90)
    diagonal = ImageChops.add(down, across, scale=2)
    return Image.merge("RGB", [diagonal.point([c[k] for c in lut]) for k in range(3)])


def ios_icon(appearance: str, background=gradient) -> Image.Image:
    """1024 full-bleed iOS icon; the system applies the rounded mask."""
    size = 1024
    mask = mark_mask(size, size * 0.50)
    if appearance == "dark":
        # Transparent background: iOS draws its dark backdrop; the mark takes the background colors.
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        img.paste(background(size).convert("RGBA"), mask=mask)
        return img
    if appearance == "tinted":
        # Grayscale on black; iOS applies the user's tint.
        img = Image.new("RGB", (size, size), (0, 0, 0))
        img.paste(Image.new("RGB", (size, size), (230, 230, 230)), mask=mask)
        return img
    img = background(size)
    img.paste(Image.new("RGB", (size, size), MARK), mask=mask)
    return img


def mac_icon(background=gradient) -> Image.Image:
    """1024 macOS icon on Apple's grid: 824 pt rounded body, transparent margin, soft shadow."""
    size, body, radius = 1024, 824, 185
    inset = (size - body) // 2
    big = size * SS

    body_mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(body_mask).rounded_rectangle(
        [inset * SS, inset * SS, (inset + body) * SS - 1, (inset + body) * SS - 1], radius=radius * SS, fill=255
    )
    body_mask = body_mask.resize((size, size), Image.LANCZOS)

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_alpha = body_mask.point(lambda a: a * 0.28).filter(ImageFilter.GaussianBlur(14))
    shadow.paste(Image.new("RGBA", (size, size), (0, 0, 0, 255)), (0, 10), mask=shadow_alpha)

    img = shadow
    img.paste(background(size).convert("RGBA"), mask=body_mask)
    img.paste(Image.new("RGBA", (size, size), MARK + (255,)), mask=mark_mask(size, body * 0.50))
    return img


def write_iconset(folder: Path, background=gradient) -> int:
    """Writes the iOS and macOS app icon images and their Contents.json. Returns the image count."""
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob("*.png"):
        old.unlink()

    images = []
    for appearance, name in [("any", "ios-1024.png"), ("dark", "ios-1024-dark.png"), ("tinted", "ios-1024-tinted.png")]:
        ios_icon(appearance, background).save(folder / name, icc_profile=SRGB_ICC)
        entry = {"filename": name, "idiom": "universal", "platform": "ios", "size": "1024x1024"}
        if appearance != "any":
            entry["appearances"] = [{"appearance": "luminosity", "value": appearance}]
        images.append(entry)

    mac = mac_icon(background)
    for pt in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = pt * scale
            name = f"mac-{pt}@{scale}x.png"
            mac.resize((px, px), Image.LANCZOS).save(folder / name, icc_profile=SRGB_ICC)
            images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{pt}x{pt}"})

    (folder / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )
    return len(images)


def main() -> None:
    images = [None] * write_iconset(ICONSET)

    # Template vector mark: tinted by the system (menu bar) or by foregroundStyle in the app.
    x0, y0, x1, y1 = HOLE
    outer = "M" + "L".join(f"{x} {y}" for x, y in OUTER) + "Z"
    hole = f"M{x0} {y0}H{x1}V{y1}H{x0}Z"
    write_template_svg(MARKSET, "LogoMark", f'<path fill-rule="evenodd" d="{outer} {hole}"/>',
                       view=(UNITS, UNITS), height=16)
    print(f"Wrote {len(images)} app icon images to {ICONSET} and the logo mark to {MARKSET}")

    # Full inline logo (mark + wordmark) for title bars.
    if not Path(FONT).exists():
        print(f"Skipped the full logo: Bauhaus 93 not found at {FONT} (set LOGO_FONT to its path).")
        return
    outline = json.loads(subprocess.run(
        ["swift", "scripts/wordmark_outline.swift", FONT, WORDMARK, str(WORDMARK_SIZE)],
        check=True, capture_output=True, text=True,
    ).stdout)
    ox, oy = WORDMARK_ORIGIN
    width = ox + outline["bounds"][2]
    height = oy + outline["bounds"][3]
    body = (
        f'<path fill-rule="evenodd" d="{outer} {hole}"/>'
        f'<path transform="translate({ox} {oy})" d="{outline["d"]}"/>'
    )
    write_template_svg(FULLSET, "LogoFull", body, view=(round(width, 2), round(height, 2)), height=18)
    print(f"Wrote the full logo to {FULLSET}")


def write_template_svg(folder: Path, name: str, body: str, view: tuple, height: float) -> None:
    """Writes a single-color vector image set, rendered as a template (it takes the text color)."""
    folder.mkdir(parents=True, exist_ok=True)
    w, h = view
    (folder / f"{name}.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{round(height * w / h, 2)}" height="{height}" '
        f'viewBox="0 0 {w} {h}"><g fill="#000">{body}</g></svg>\n'
    )
    (folder / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True, "template-rendering-intent": "template"},
    }, indent=2) + "\n")


if __name__ == "__main__":
    main()
