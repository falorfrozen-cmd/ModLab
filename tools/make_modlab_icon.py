"""Generate the ModLab application icon (multi-size .ico + preview PNG).

The standard installer previously shipped without a custom icon, so the Setup
executable carried Inno Setup's default icon - the same default icon used by a
very large number of Inno-based samples. A unique, project-owned icon is a
normal packaging requirement; its effect on antivirus classification is not
established. The palette matches the installer UI (#0F1823 / #46DCCC).

Run:  py -3 tools/make_modlab_icon.py <output.ico> [preview.png]
"""
import sys
from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
BG = (15, 24, 35, 255)        # #0F1823 dark navy
BORDER = (42, 59, 77, 255)    # #2A3B4D
ACCENT = (70, 220, 204, 255)  # #46DCCC teal
BAR = (30, 74, 85, 255)       # #1E4A55 muted teal


def font(size):
    for candidate in (r"C:\Windows\Fonts\arialbd.ttf", r"C:\Windows\Fonts\segoeuib.ttf"):
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    raise SystemExit("No bold system font found.")


def build():
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), radius=196, fill=BG)
    draw.rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), radius=196, outline=BORDER, width=14)

    glyph = "M"
    typeface = font(620)
    left, top, right, bottom = draw.textbbox((0, 0), glyph, font=typeface)
    draw.text((SIZE / 2 - (right - left) / 2 - left, 430 - (bottom - top) / 2 - top),
              glyph, font=typeface, fill=ACCENT)

    # Lab bench underline: a short accent bar plus a muted bar.
    draw.rounded_rectangle((332, 812, 692, 872), radius=30, fill=ACCENT)
    draw.rounded_rectangle((252, 812, 308, 872), radius=28, fill=BAR)
    draw.rounded_rectangle((716, 812, 772, 872), radius=28, fill=BAR)
    return image


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    icon_path = sys.argv[1]
    preview_path = sys.argv[2] if len(sys.argv) > 2 else None
    image = build()
    sizes = [(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (24, 24), (16, 16)]
    image.resize((256, 256), Image.LANCZOS).save(icon_path, format="ICO", sizes=sizes)
    if preview_path:
        image.resize((256, 256), Image.LANCZOS).save(preview_path, format="PNG")
    print("wrote", icon_path)


if __name__ == "__main__":
    main()
