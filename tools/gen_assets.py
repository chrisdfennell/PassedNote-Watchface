#!/usr/bin/env python
"""
Generate the Passed Note store/marketing image assets:

    assets/app_icon_24bit.png   128x128  mini notebook-page icon (24-bit)
    assets/app_icon_64color.png 128x128  same icon, 64-color quantized
    assets/cover_image.png/.jpg 500x500  square promo (real screenshot on paper)
    assets/hero_image.png       1440x720 wide banner (screenshot + handwritten title)

Everything is drawn in the face's own visual language - lined filler paper,
blue/black/red ballpoint - using the same TTF handwriting fonts the watch
fonts are baked from. The watch render (assets/screen_active.png) is
composited in so the marketing art matches the actual face. Run after
capturing a fresh screenshot.

Run:  python tools/gen_assets.py
"""
import os, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
FONTS = os.path.join(ROOT, "fonts-src")

PAPER    = (252, 250, 240)
RULE     = (158, 199, 232)
MARGIN   = (232, 120, 120)
INK_BLUE = (27, 62, 158)
INK_BLACK = (40, 40, 48)
INK_RED  = (200, 50, 80)
HOLE_RIM = (200, 196, 180)


def load_font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def paper(size, spacing, margin_x=None, holes=False, rule_w=2):
    """Lined filler paper backdrop."""
    w, h = size
    img = Image.new("RGB", size, PAPER)
    d = ImageDraw.Draw(img)
    y = spacing
    while y < h:
        d.line([(0, y), (w, y)], fill=RULE, width=rule_w)
        y += spacing
    if margin_x is not None:
        d.line([(margin_x, 0), (margin_x, h)], fill=MARGIN, width=rule_w)
    if holes:
        r = int(spacing * 0.30)
        hx = int(margin_x * 0.45)
        for hy in (int(h * 0.22), int(h * 0.5), int(h * 0.78)):
            d.ellipse([hx - r, hy - r, hx + r, hy + r], fill=(24, 24, 24), outline=HOLE_RIM, width=rule_w)
    return img


def squiggle(d, x1, x2, y, amp, color, width=4, wavelen=28):
    pts = []
    x = x1
    while x <= x2:
        pts.append((x, y + amp * math.sin((x - x1) / wavelen * 2 * math.pi)))
        x += 4
    d.line(pts, fill=color, width=width, joint="curve")


def heart(d, x, y, r, color):
    lobe = r * 0.55
    ly = y - r * 0.35
    d.ellipse([x - 2 * lobe, ly - lobe, x, ly + lobe], fill=color)
    d.ellipse([x, ly - lobe, x + 2 * lobe, ly + lobe], fill=color)
    d.polygon([(x - r, ly + lobe * 0.4), (x + r, ly + lobe * 0.4), (x, y + r)], fill=color)


def star(d, x, y, r, color, width=4):
    pts = []
    for i in range(11):
        ang = -math.pi / 2 + i * math.pi / 5
        rad = r if i % 2 == 0 else r * 0.42
        pts.append((x + rad * math.cos(ang), y + rad * math.sin(ang)))
    d.line(pts, fill=color, width=width, joint="curve")


def folded_corner(d, w, size):
    """Dog-eared top-right corner."""
    d.polygon([(w - size, 0), (w, 0), (w, size)], fill=(228, 223, 206))
    d.line([(w - size, 0), (w, size)], fill=(185, 180, 164), width=2)


def _text(d, x, y, s, font, color, anchor="la"):
    d.text((x, y), s, font=font, fill=color, anchor=anchor)


def fit_font(d, name, text, start, maxw):
    """Largest size <= start whose rendered text fits in maxw."""
    size = start
    while size > 8:
        f = load_font(name, size)
        if d.textlength(text, font=f) <= maxw:
            return f
        size -= 2
    return load_font(name, 8)


# ---------------------------------------------------------------- app icon

def gen_app_icon():
    S = 128
    img = paper((S, S), 18, margin_x=20, rule_w=1)
    d = ImageDraw.Draw(img)
    folded_corner(d, S, 26)

    t = fit_font(d, "segoescb.ttf", "10:08", 46, S * 0.88)
    _text(d, S * 0.5, S * 0.42, "10:08", t, INK_BLUE, anchor="mm")
    squiggle(d, S * 0.14, S * 0.86, S * 0.66, 3, INK_BLUE, width=3, wavelen=18)
    heart(d, S * 0.72, S * 0.86, 9, INK_RED)

    img.save(os.path.join(ASSETS, "app_icon_24bit.png"))
    img.convert("P", palette=Image.ADAPTIVE, colors=64).convert("RGB").save(
        os.path.join(ASSETS, "app_icon_64color.png"))
    print("app_icon_24bit.png / app_icon_64color.png  128x128")


# ---------------------------------------------------------------- watch render

def load_watch(target):
    """The real screenshot, circle-masked, resized, with a soft drop shadow."""
    path = os.path.join(ASSETS, "screen_active.png")
    if not os.path.exists(path):
        print("WARNING: assets/screen_active.png not found - run savescreenshot.ps1 first")
        return None
    shot = Image.open(path).convert("RGBA").resize((target, target), Image.LANCZOS)
    mask = Image.new("L", (target, target), 0)
    ImageDraw.Draw(mask).ellipse([2, 2, target - 2, target - 2], fill=255)
    shot.putalpha(mask)
    return shot


def paste_watch_with_shadow(bg, watch, ox, oy):
    wsz = watch.size[0]
    pad = 40
    shadow = Image.new("RGBA", (wsz + pad * 2, wsz + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([pad, pad + 6, pad + wsz, pad + wsz + 6], fill=(30, 30, 40, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(12))
    bg.paste(shadow, (ox - pad, oy - pad), shadow)
    bg.paste(watch, (ox, oy), watch)


# ---------------------------------------------------------------- cover (square)

def gen_cover():
    S = 500
    bg = paper((S, S), 40, margin_x=None, rule_w=2).convert("RGBA")
    d = ImageDraw.Draw(bg)
    star(d, 40, 46, 18, INK_BLUE, width=4)
    heart(d, S - 42, 50, 16, INK_RED)

    watch = load_watch(int(S * 0.82))
    if watch is not None:
        wsz = watch.size[0]
        paste_watch_with_shadow(bg, watch, (S - wsz) // 2, int(S * 0.05))

    d = ImageDraw.Draw(bg)
    title_f = load_font("segoescb.ttf", 56)
    _text(d, S / 2, S * 0.935, "Passed Note", title_f, INK_BLUE, anchor="mm")

    out = bg.convert("RGB")
    out.save(os.path.join(ASSETS, "cover_image.png"))
    out.save(os.path.join(ASSETS, "cover_image.jpg"), quality=90)
    print("cover_image.png / cover_image.jpg  500x500")


# ---------------------------------------------------------------- hero (banner)

def gen_hero():
    W, H = 1440, 720
    bg = paper((W, H), 52, margin_x=150, holes=True, rule_w=3).convert("RGBA")
    d = ImageDraw.Draw(bg)

    # Watch on the right; all text is fit inside the column left of it.
    wsz = int(H * 0.80)
    wx = W - wsz - 70
    text_w = wx - 205 - 40

    title_f = fit_font(d, "segoescb.ttf", "Passed Note", 110, text_w)
    sub_f = fit_font(d, "Inkfree.ttf", "a watch face that looks like", 46, text_w)
    small_f = fit_font(d, "segoesc.ttf", "handwritten time, doodled weather,", 38, text_w)

    _text(d, 205, 110, "Passed Note", title_f, INK_BLUE)
    tw = d.textlength("Passed Note", font=title_f)
    squiggle(d, 210, 210 + tw, 268, 6, INK_BLUE, width=7, wavelen=42)
    _text(d, 205, 322, "a watch face that looks like", sub_f, INK_BLACK)
    _text(d, 205, 388, "a note passed to you in class", sub_f, INK_BLACK)
    _text(d, 205, 505, "handwritten time, doodled weather,", small_f, INK_BLUE)
    _text(d, 205, 560, "ur stats & doodles in real pens", small_f, INK_BLUE)
    _text(d, 205, 615, "for Garmin round watches", small_f, INK_BLUE)

    star(d, 128, 615, 26, INK_BLUE, width=5)
    heart(d, wx - 60, 100, 26, INK_RED)

    watch = load_watch(wsz)
    if watch is not None:
        paste_watch_with_shadow(bg, watch, wx, (H - wsz) // 2)

    bg.convert("RGB").save(os.path.join(ASSETS, "hero_image.png"))
    print("hero_image.png  1440x720")


if __name__ == "__main__":
    os.makedirs(ASSETS, exist_ok=True)
    gen_app_icon()
    gen_cover()
    gen_hero()
    print("Done.")
