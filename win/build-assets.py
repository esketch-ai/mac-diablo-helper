#!/usr/bin/env python3
"""
Generates the Windows icon assets from the macOS status-bar images.

The macOS build ships two PNGs in d3key/Assets.xcassets/StatusBar.imageset: a 16pt and a
32px icon. Windows wants a single .ico that carries several sizes so the shell can pick the
right one per taskbar size and DPI.

The "active/running" variant is produced here rather than maintained by hand: it is the
idle icon composited over a green disc, matching the colour HelperEngine reports, so the two
tray states cannot drift apart visually.

Run from the repository root:
    python3 win/build-assets.py

Requires Pillow. If it is unavailable the script says so and leaves the existing assets
alone rather than half-writing them.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "d3key/Assets.xcassets/StatusBar.imageset/d3a_statusbar@2x.png"
OUT = ROOT / "win/src/DM_Helper.Wpf/Assets"

IDLE_ICO = OUT / "d3a_statusbar.ico"
RUN_ICO = OUT / "d3a_statusbar_active.ico"
APP_ICO = OUT / "app.ico"

SIZES = (16, 24, 32, 48, 64, 128, 256)
RUNNING_RGB = (26, 158, 75)


def require_pillow():
    try:
        from PIL import Image, ImageDraw  # noqa: F401
        return Image, ImageDraw
    except ImportError:
        print("Pillow is required: pip install pillow", file=sys.stderr)
        sys.exit(1)


def save_ico(image, path, Image):
    """Writes a multi-size .ico.

    Pillow only emits frames at or below the source resolution, so the image is upsampled to
    the largest target first. Without this the tray icons would carry just 16/24/32 and look
    soft at 150% display scaling.
    """
    largest = max(SIZES)
    if image.width < largest:
        image = image.resize((largest, largest), Image.LANCZOS)

    image.save(path, sizes=[(s, s) for s in SIZES])
    print(f"wrote {path.relative_to(ROOT)} (sizes {', '.join(str(s) for s in SIZES)})")


def main():
    Image, ImageDraw = require_pillow()

    if not SRC.exists():
        print(f"source image missing: {SRC}", file=sys.stderr)
        sys.exit(1)

    OUT.mkdir(parents=True, exist_ok=True)

    idle = Image.open(SRC).convert("RGBA")

    save_ico(idle, IDLE_ICO, Image)

    # Running variant: green disc behind the idle glyph. Composited at 4x so the disc edge
    # stays smooth before it is downsampled into each icon size.
    scale = 4
    big = idle.resize((idle.width * scale, idle.height * scale), Image.LANCZOS)
    inset = max(1, int(big.width * 0.06))
    disc = Image.new("RGBA", big.size, (0, 0, 0, 0))
    ImageDraw.Draw(disc).ellipse(
        (inset, inset, big.width - inset, big.height - inset),
        fill=RUNNING_RGB + (235,),
    )

    disc.alpha_composite(big)
    save_ico(disc, RUN_ICO, Image)

    # Application icon: the 1024px app icon if it is present, otherwise reuse the tray one.
    app_src = ROOT / "d3key/Assets.xcassets/AppIcon.appiconset/d3a_icon_512x512@2x.png"
    if app_src.exists():
        app = Image.open(app_src).convert("RGBA")
        save_ico(app, APP_ICO, Image)
    else:
        save_ico(idle, APP_ICO, Image)
        print("  (app icon unavailable, reused the tray icon)")


if __name__ == "__main__":
    main()
