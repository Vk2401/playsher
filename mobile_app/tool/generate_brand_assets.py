#!/usr/bin/env python3
"""Generate every Playsher brand asset from the one registered logo file.

    python3 tool/generate_brand_assets.py

Source of truth: ``Playsher Logo Final.ai`` at the repo root (a 3-page PDF from
Illustrator). Page 1 is the horizontal lockup — a brand-blue rounded tile with
the white P, then the black PLAYSHER wordmark. Everything below is derived from
that one page, so the logo is declared once and never redrawn by hand.

Two colour variants come out of a single extracted shape rather than two source
files: the P and the wordmark are saved as *white silhouettes on transparent*,
and the alpha channel carries the artwork. Flutter tints them at the use site
(``Image.asset(color: …, colorBlendMode: BlendMode.srcIn)``), so the blue-on-
light and white-on-dark versions can never drift apart.

Written asset trees:
  assets/logo/                         in-app logo (mark, wordmark, tile)
  android/app/src/main/res/mipmap-*/   launcher, round, adaptive fg, monochrome
  android/app/src/main/res/drawable*/  native launch-screen logo
  ios/Runner/Assets.xcassets/          AppIcon.appiconset + LaunchImage.imageset
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

APP = Path(__file__).resolve().parent.parent
REPO = APP.parent
SOURCE = REPO / "Playsher Logo Final.ai"

BLUE = (0, 97, 194)          # #0061C2 — matches AppColors.primary exactly
WHITE = (255, 255, 255)
RENDER_DPI = 600
SS = 4                       # supersampling factor for drawn geometry


# ── Extract the artwork out of the .ai ────────────────────────────────────────

def render_page_one(workdir: Path) -> Image.Image:
    if not SOURCE.exists():
        sys.exit(f"missing source artwork: {SOURCE}")
    subprocess.run(
        ["pdftoppm", "-png", "-r", str(RENDER_DPI), "-f", "1", "-l", "1",
         str(SOURCE), str(workdir / "page")],
        check=True,
    )
    rendered = sorted(workdir.glob("page-*.png"))
    if not rendered:
        sys.exit("pdftoppm produced no output — is poppler installed?")
    return Image.open(rendered[0]).convert("RGB")


def channel_mask(image: Image.Image, keep) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    src, dst = image.load(), mask.load()
    for y in range(image.height):
        for x in range(image.width):
            if keep(src[x, y]):
                dst[x, y] = 255
    return mask


def locate(page: Image.Image) -> tuple[tuple, tuple]:
    """Find the blue tile and the black wordmark on the lockup page."""
    blue = channel_mask(page, lambda p: p[2] > 120 and p[0] < 120)
    dark = channel_mask(page, lambda p: sum(p) < 200)
    tile, word = blue.getbbox(), dark.getbbox()
    if not tile or not word:
        sys.exit("could not find the tile and wordmark on page 1")
    return tile, word


def extract_glyph(tile: Image.Image) -> tuple[Image.Image, float]:
    """Pull the white P out of the tile, and measure the tile's corner radius.

    The tile is a convex rounded square and the P never reaches its edge, so
    for every row the blue pixels' x-extent *is* the tile. White inside that
    span is glyph ink; white outside it is the page. The span is then eroded by
    a few pixels so the tile's own antialiased rim is not mistaken for ink —
    that rim is why a plain flood fill from the corners leaves a hairline
    ring and reports the whole tile as glyph.
    """
    w, h = tile.size
    px = tile.load()
    spans: list[tuple[int, int] | None] = []
    for y in range(h):
        lo = hi = None
        for x in range(w):
            r, _, b = px[x, y]
            if b > 120 and r < 120:
                if lo is None:
                    lo = x
                hi = x
        spans.append((lo, hi) if lo is not None else None)

    rim = max(2, round(w * 0.005))
    whiteness = tile.split()[0]          # blue R=0, white R=255 → free antialiasing
    ink, src = Image.new("L", (w, h), 0), whiteness.load()
    dst = ink.load()
    for y in range(h):
        window = spans[max(0, y - rim):y + rim + 1]
        if not window or any(s is None for s in window):
            continue
        lo = max(s[0] for s in window) + rim
        hi = min(s[1] for s in window) - rim
        for x in range(lo, hi + 1):
            dst[x, y] = src[x, y]

    first = next(s for s in spans if s is not None)
    radius_ratio = (first[0] + rim) / w
    return ink, radius_ratio


def silhouette(mask: Image.Image) -> Image.Image:
    """A white RGBA image whose alpha is the mask — tintable, crops to the ink."""
    out = Image.new("RGBA", mask.size, WHITE + (0,))
    out.putalpha(mask)
    return out.crop(mask.getbbox())


# ── Compose the icon shapes ──────────────────────────────────────────────────

def fit(art: Image.Image, box: int) -> Image.Image:
    scale = box / max(art.size)
    size = (max(1, round(art.width * scale)), max(1, round(art.height * scale)))
    return art.resize(size, Image.LANCZOS)


def centered(canvas: Image.Image, art: Image.Image) -> Image.Image:
    canvas.alpha_composite(
        art,
        ((canvas.width - art.width) // 2, (canvas.height - art.height) // 2),
    )
    return canvas


def rounded_tile(size: int, radius_ratio: float, colour) -> Image.Image:
    big = Image.new("RGBA", (size * SS, size * SS), colour + (0,))
    ImageDraw.Draw(big).rounded_rectangle(
        (0, 0, size * SS - 1, size * SS - 1),
        radius=radius_ratio * size * SS,
        fill=colour + (255,),
    )
    return big.resize((size, size), Image.LANCZOS)


def circle(size: int, colour) -> Image.Image:
    big = Image.new("RGBA", (size * SS, size * SS), colour + (0,))
    ImageDraw.Draw(big).ellipse((0, 0, size * SS - 1, size * SS - 1),
                               fill=colour + (255,))
    return big.resize((size, size), Image.LANCZOS)


def tinted(art: Image.Image, colour) -> Image.Image:
    out = Image.new("RGBA", art.size, colour + (0,))
    out.putalpha(art.getchannel("A"))
    return out


def write(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)
    print(f"  {path.relative_to(APP)}  {image.width}x{image.height}")


# ── The asset trees ──────────────────────────────────────────────────────────

MIPMAP = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

# The P fills this share of the tile; measured off the registered lockup so the
# in-app tile and both launcher icons keep the artwork's own proportion.
GLYPH_IN_TILE = 0.692

# Adaptive icons draw a 108dp foreground of which only the middle 72dp survives
# the launcher's mask. Sizing the glyph against that 72dp — not the full 108 —
# is what keeps it the same size as the legacy icon's glyph, and lands it well
# inside the 66dp zone every launcher shape is guaranteed to show.
ADAPTIVE_VISIBLE = 72 / 108


def app_logo_assets(glyph: Image.Image, wordmark: Image.Image, radius: float) -> None:
    out = APP / "assets" / "logo"
    if out.exists():
        shutil.rmtree(out)
    print("assets/logo")
    write(fit(glyph, 1024), out / "playsher_mark.png")
    write(fit(wordmark, 2048), out / "playsher_wordmark.png")
    tile = rounded_tile(1024, radius, BLUE)
    write(centered(tile, fit(glyph, round(1024 * GLYPH_IN_TILE))),
          out / "playsher_tile.png")


def android_assets(glyph: Image.Image, radius: float) -> None:
    res = APP / "android" / "app" / "src" / "main" / "res"
    print("android launcher icons")
    for bucket, factor in MIPMAP.items():
        legacy = round(48 * factor)
        tile = rounded_tile(legacy, radius, BLUE)
        write(centered(tile, fit(glyph, round(legacy * GLYPH_IN_TILE))),
              res / f"mipmap-{bucket}" / "ic_launcher.png")
        disc = circle(legacy, BLUE)
        write(centered(disc, fit(glyph, round(legacy * GLYPH_IN_TILE * 0.86))),
              res / f"mipmap-{bucket}" / "ic_launcher_round.png")

        adaptive = round(108 * factor)
        inner = round(adaptive * ADAPTIVE_VISIBLE * GLYPH_IN_TILE)
        foreground = centered(
            Image.new("RGBA", (adaptive, adaptive), WHITE + (0,)), fit(glyph, inner))
        write(foreground, res / f"mipmap-{bucket}" / "ic_launcher_foreground.png")
        # Themed icons (Android 13+) recolour the alpha, so ship the same shape.
        write(foreground, res / f"mipmap-{bucket}" / "ic_launcher_monochrome.png")

    print("android launch screen")
    launch = fit(glyph, 320)
    write(tinted(launch, BLUE), res / "drawable" / "launch_logo.png")
    write(tinted(launch, WHITE), res / "drawable-night" / "launch_logo.png")


def ios_assets(glyph: Image.Image) -> None:
    icons = APP / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    manifest = json.loads((icons / "Contents.json").read_text())
    print("ios app icon")
    # iOS applies its own squircle mask, so the source must be an opaque,
    # full-bleed square with square corners — a pre-rounded tile would be
    # clipped twice and read as inset.
    for entry in manifest["images"]:
        side, _, _ = entry["size"].partition("x")
        px = round(float(side) * float(entry["scale"].rstrip("x")))
        square = Image.new("RGBA", (px, px), BLUE + (255,))
        icon = centered(square, fit(glyph, max(1, round(px * GLYPH_IN_TILE))))
        write(icon.convert("RGB"), icons / entry["filename"])

    print("ios launch image")
    launch = APP / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
    for name, factor in (("LaunchImage.png", 1),
                         ("LaunchImage@2x.png", 2),
                         ("LaunchImage@3x.png", 3)):
        write(tinted(fit(glyph, 96 * factor), BLUE), launch / name)


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        page = render_page_one(Path(tmp))
        tile_box, word_box = locate(page)
        print(f"lockup found: tile {tile_box}, wordmark {word_box}")
        ink, radius = extract_glyph(page.crop(tile_box))
        print(f"corner radius: {radius:.4f} of the tile")
        glyph = silhouette(ink)
        wordmark = silhouette(page.crop(word_box).split()[0].point(lambda p: 255 - p))
        print(f"glyph {glyph.size}, wordmark {wordmark.size}")

        app_logo_assets(glyph, wordmark, radius)
        android_assets(glyph, radius)
        ios_assets(glyph)
    print("done")


if __name__ == "__main__":
    main()
