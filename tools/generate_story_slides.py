#!/usr/bin/env python3
"""Echo Runner story slide generator — pixel art panels using game sprites."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
STORY = ROOT / "assets" / "story"
PANELS = STORY / "panels"
PLAYER_SHEET = ROOT / "assets" / "sprites" / "mainPlayer.png"
ENEMY_SHEET = ROOT / "assets" / "sprites" / "enemy.png"
DIRT = ROOT / "assets" / "environment" / "deaddirt.png"

CYAN = (0, 245, 255)
ORANGE = (255, 120, 40)
RED = (255, 48, 48)
BG = (6, 8, 14)


def sheet_frame(sheet: Image.Image, col: int, row: int) -> Image.Image:
    w, h = sheet.size
    fw, fh = w // 8, h // 8
    return sheet.crop((col * fw, row * fh, (col + 1) * fw, (row + 1) * fh)).convert("RGBA")


def scale_nearest(img: Image.Image, target_w: int, target_h: int) -> Image.Image:
    return img.resize((target_w, target_h), Image.NEAREST)


def posterize(img: Image.Image, bits: int = 4) -> Image.Image:
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    r, g, b, a = img.split()
    rgb = Image.merge("RGB", (r, g, b))
    rgb = ImageEnhance.Color(rgb).enhance(1.15)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.2)
    levels = 2 ** bits
    rgb = rgb.quantize(colors=levels, method=Image.MEDIANCUT).convert("RGB")
    out = Image.new("RGBA", img.size)
    out.paste(rgb, (0, 0))
    out.putalpha(a)
    return out


def dark_bg(size: tuple[int, int], tint: tuple[int, int, int] = BG) -> Image.Image:
    img = Image.new("RGBA", size, tint + (255,))
    draw = ImageDraw.Draw(img)
    for y in range(0, size[1], 4):
        shade = 8 + (y % 16)
        draw.line([(0, y), (size[0], y)], fill=(tint[0], tint[1], tint[2] + shade, 255))
    return img


def paste_ground(img: Image.Image, dirt: Image.Image, y_frac: float = 0.55, alpha: int = 90) -> None:
    tw = img.width
    th = int(img.height * (1.0 - y_frac))
    patch = dirt.resize((tw, th), Image.NEAREST)
    patch.putalpha(alpha)
    img.paste(patch, (0, int(img.height * y_frac)), patch)


def draw_echo_ring(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    radius: float,
    color: tuple[int, int, int] = CYAN,
    alpha: int = 180,
    width: int = 3,
) -> None:
    for i in range(width):
        r = radius - i
        a = max(20, alpha - i * 35)
        draw.ellipse(
            (cx - r, cy - r, cx + r, cy + r),
            outline=color + (a,),
            width=2,
        )


def paste_sprite(
    canvas: Image.Image,
    sprite: Image.Image,
    cx: int,
    cy: int,
    scale: int = 3,
) -> None:
    s = scale_nearest(sprite, sprite.width * scale, sprite.height * scale)
    x = cx - s.width // 2
    y = cy - s.height // 2
    canvas.paste(s, (x, y), s)


def vignette(img: Image.Image, strength: float = 0.55) -> Image.Image:
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    cx, cy = img.width / 2, img.height / 2
    max_r = math.hypot(cx, cy)
    for r in range(int(max_r), 0, -12):
        a = int(255 * strength * (1.0 - r / max_r) ** 1.6)
        if a <= 0:
            continue
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(0, 0, 0, a))
    return Image.alpha_composite(img, overlay)


def finalize(img: Image.Image) -> Image.Image:
    return posterize(vignette(img))


def make_single(
    name: str,
    size: tuple[int, int],
    draw_fn,
) -> None:
    img = dark_bg(size)
    draw_fn(img, ImageDraw.Draw(img))
    out = finalize(img).convert("RGB")
    out.save(STORY / name, optimize=True)
    print(f"wrote {name}")


def make_panel(name: str, draw_fn) -> None:
    size = (512, 384)
    img = dark_bg(size, (8, 10, 18))
    draw_fn(img, ImageDraw.Draw(img))
    out = finalize(img).convert("RGB")
    PANELS.mkdir(parents=True, exist_ok=True)
    out.save(PANELS / name, optimize=True)
    print(f"wrote panels/{name}")


def main() -> None:
    STORY.mkdir(parents=True, exist_ok=True)
    player = Image.open(PLAYER_SHEET).convert("RGBA")
    enemy = Image.open(ENEMY_SHEET).convert("RGBA")
    dirt = Image.open(DIRT).convert("RGBA")

    p_front = sheet_frame(player, 0, 0)
    p_back = sheet_frame(player, 0, 1)
    p_side = sheet_frame(player, 2, 0)
    p_run = sheet_frame(player, 4, 2)
    e_front = sheet_frame(enemy, 0, 0)
    e_chase = sheet_frame(enemy, 3, 4)

    # 01 intro — style reference
    def draw_intro(img, draw):
        paste_ground(img, dirt, 0.62, 70)
        paste_sprite(img, p_back, img.width // 2, int(img.height * 0.58), 5)
        draw_echo_ring(draw, img.width * 0.5, img.height * 0.72, 55, alpha=120)
        draw_echo_ring(draw, img.width * 0.5, img.height * 0.72, 95, alpha=60)

    make_single("01_intro.png", (960, 540), draw_intro)

    # panels 3-up
    def draw_p2a(img, draw):
        paste_ground(img, dirt, 0.68, 80)
        paste_sprite(img, p_side, 180, 250, 4)
        draw.rectangle((8, 8, 503, 375), outline=(40, 50, 70, 255), width=3)

    def draw_p2b(img, draw):
        paste_ground(img, dirt, 0.68, 80)
        paste_sprite(img, p_front, 256, 250, 4)
        draw_echo_ring(draw, 256, 290, 70, alpha=200)
        draw_echo_ring(draw, 256, 290, 110, alpha=90)

    def draw_p2c(img, draw):
        paste_ground(img, dirt, 0.68, 50)
        paste_sprite(img, p_back, 256, 250, 4)
        draw_echo_ring(draw, 256, 300, 130, alpha=160)
        # reveal wedge
        draw.pieslice((126, 170, 386, 330), 200, 340, fill=CYAN + (35,), outline=CYAN + (100,))

    make_panel("p2a.png", draw_p2a)
    make_panel("p2b.png", draw_p2b)
    make_panel("p2c.png", draw_p2c)

    # 03 chase
    def draw_chase(img, draw):
        paste_ground(img, dirt, 0.58, 85)
        paste_sprite(img, p_run, img.width // 2 - 40, int(img.height * 0.55), 5)
        paste_sprite(img, e_chase, img.width // 2 + 120, int(img.height * 0.62), 4)
        for i in range(5):
            draw.line(
                (180 + i * 18, 300, 230 + i * 18, 285),
                fill=CYAN + (90 - i * 12,),
                width=2,
            )

    make_single("03_chase.png", (960, 540), draw_chase)

    # panels 2-up slide 4
    def draw_p4a(img, draw):
        paste_ground(img, dirt, 0.68, 80)
        paste_sprite(img, p_front, 256, 240, 5)
        draw_echo_ring(draw, 256, 260, 50, color=ORANGE, alpha=200)
        draw_echo_ring(draw, 256, 260, 85, color=ORANGE, alpha=120)

    def draw_p4b(img, draw):
        paste_sprite(img, e_front, 256, 230, 5)
        draw.ellipse((220, 175, 250, 195), fill=RED + (220,))
        draw.ellipse((262, 175, 292, 195), fill=RED + (220,))

    make_panel("p4a.png", draw_p4a)
    make_panel("p4b.png", draw_p4b)

    # panels 2-up slide 5
    def draw_p5a(img, draw):
        paste_ground(img, dirt, 0.7, 60)
        for i in range(6):
            draw_echo_ring(draw, 120 + i * 28, 300 - i * 8, 12 + i * 2, alpha=140 - i * 15)

    def draw_p5b(img, draw):
        paste_ground(img, dirt, 0.68, 70)
        paste_sprite(img, p_run, 160, 250, 4)
        paste_sprite(img, e_chase, 360, 270, 5)
        draw.line((190, 300, 330, 310), fill=CYAN + (100,), width=3)

    make_panel("p5a.png", draw_p5a)
    make_panel("p5b.png", draw_p5b)

    # 06 gate
    def draw_gate(img, draw):
        paste_ground(img, dirt, 0.58, 90)
        paste_sprite(img, p_back, img.width // 2, int(img.height * 0.58), 5)
        sy = int(img.height * 0.52)
        draw.line((40, sy, img.width - 40, sy), fill=RED + (255,), width=5)
        draw_echo_ring(draw, img.width * 0.5, sy, 18, color=RED, alpha=200)

    make_single("06_gate.png", (960, 540), draw_gate)

    # 07 boss
    def draw_boss(img, draw):
        paste_ground(img, dirt, 0.62, 50)
        paste_sprite(img, p_front, img.width // 2, int(img.height * 0.72), 4)
        paste_sprite(img, e_front, img.width // 2, int(img.height * 0.38), 8)
        draw.rectangle((0, 0, img.width - 1, img.height - 1), outline=RED + (80,), width=4)

    make_single("07_boss.png", (960, 540), draw_boss)

    print("All 11 story images generated.")


if __name__ == "__main__":
    main()
