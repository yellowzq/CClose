#!/usr/bin/env python3
"""Programmatic CClose icon generator (pure stdlib, no Pillow).

Renders the icon from vector-ish SDF drawing into a 512x512 RGBA canvas,
then box-downsamples to any target size. Output:
  concept strips      -> assets/out/concept_<a|b|c>.png   (preview)
  final ICO           -> assets/app.ico                    (multi-size)

Usage:
  python assets/make_icon.py preview   # write 3 concept strips
  python assets/make_icon.py ico <a|b|c>  # write app.ico for chosen concept
"""
import math
import struct
import sys
import zlib

MASTER = 512
COLORS = {
    # concept A palette
    "frame": (0x2F, 0x6B, 0xEA),
    "frame_dark": (0x1E, 0x4F, 0xC4),
    "window": (0xF8, 0xFA, 0xFF),
    "close_red": (0xE5, 0x48, 0x4D),
    "close_dark": (0xC8, 0x35, 0x3A),
    # concept B palette
    "slate": (0x2B, 0x2F, 0x38),
    "slate_light": (0x3A, 0x40, 0x4C),
    "content": (0xCF, 0xD6, 0xE4),
}


def new_canvas(w, h):
    return [[(0, 0, 0, 0) for _ in range(w)] for _ in range(h)]


def blend(canvas, x, y, cr, cg, cb, a):
    if a <= 0.0 or not (0 <= y < len(canvas) and 0 <= x < len(canvas[0])):
        return
    r, g, b, al = canvas[y][x]
    ra = al / 255.0
    out_a = a + ra * (1 - a)
    if out_a <= 0:
        return
    r = (cr * a + r * ra * (1 - a)) / out_a
    g = (cg * a + g * ra * (1 - a)) / out_a
    b = (cb * a + b * ra * (1 - a)) / out_a
    canvas[y][x] = (int(r), int(g), int(b), int(out_a * 255))


def sd_round_box(px, py, cx, cy, hw, hh, r):
    qx = abs(px - cx) - (hw - r)
    qy = abs(py - cy) - (hh - r)
    ox, oy = max(qx, 0.0), max(qy, 0.0)
    return math.hypot(ox, oy) - r + min(max(qx, qy), 0.0)


def fill_round_rect(canvas, x0, y0, x1, y1, r, color, alpha=1.0):
    cx = (x0 + x1) / 2
    cy = (y0 + y1) / 2
    hw = (x1 - x0) / 2
    hh = (y1 - y0) / 2
    xa = int(max(0, math.floor(x0 - 2)))
    xb = int(min(len(canvas[0]) - 1, math.ceil(x1 + 2)))
    ya = int(max(0, math.floor(y0 - 2)))
    yb = int(min(len(canvas) - 1, math.ceil(y1 + 2)))
    for y in range(ya, yb + 1):
        for x in range(xa, xb + 1):
            d = sd_round_box(x + 0.5, y + 0.5, cx, cy, hw, hh, r)
            a = max(0.0, min(1.0, 0.5 - d))
            if a > 0:
                blend(canvas, x, y, *color, a * alpha)


def fill_round_rect_grad(canvas, x0, y0, x1, y1, r, top, bottom):
    cx = (x0 + x1) / 2
    cy = (y0 + y1) / 2
    hw = (x1 - x0) / 2
    hh = (y1 - y0) / 2
    xa = int(max(0, math.floor(x0 - 2)))
    xb = int(min(len(canvas[0]) - 1, math.ceil(x1 + 2)))
    ya = int(max(0, math.floor(y0 - 2)))
    yb = int(min(len(canvas) - 1, math.ceil(y1 + 2)))
    for y in range(ya, yb + 1):
        t = (y + 0.5 - y0) / (y1 - y0)
        t = max(0.0, min(1.0, t))
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(xa, xb + 1):
            d = sd_round_box(x + 0.5, y + 0.5, cx, cy, hw, hh, r)
            a = max(0.0, min(1.0, 0.5 - d))
            if a > 0:
                blend(canvas, x, y, *color, a)


def sd_segment(px, py, x0, y0, x1, y1):
    vx, vy = x1 - x0, y1 - y0
    wx, wy = px - x0, py - y0
    l2 = vx * vx + vy * vy
    if l2 == 0:
        return math.hypot(px - x0, py - y0)
    t = max(0.0, min(1.0, (wx * vx + wy * vy) / l2))
    return math.hypot(px - (x0 + t * vx), py - (y0 + t * vy))


def stroke_line(canvas, x0, y0, x1, y1, w, color):
    half = w / 2
    xa = int(max(0, math.floor(min(x0, x1) - half - 2)))
    xb = int(min(len(canvas[0]) - 1, math.ceil(max(x0, x1) + half + 2)))
    ya = int(max(0, math.floor(min(y0, y1) - half - 2)))
    yb = int(min(len(canvas) - 1, math.ceil(max(y0, y1) + half + 2)))
    for y in range(ya, yb + 1):
        for x in range(xa, xb + 1):
            d = sd_segment(x + 0.5, y + 0.5, x0, y0, x1, y1) - half
            a = max(0.0, min(1.0, 0.5 - d))
            if a > 0:
                blend(canvas, x, y, *color, a)


def draw_close_x(canvas, cx, cy, size, width, color):
    h = size / 2
    s = h * 0.78  # slightly inset so strokes end inside the square
    stroke_line(canvas, cx - s, cy - s, cx + s, cy + s, width, color)
    stroke_line(canvas, cx - s, cy + s, cx + s, cy - s, width, color)


def downsample(canvas, size):
    """Box resample to `size`, alpha-weighted colors (handles any size)."""
    m = len(canvas)
    out = new_canvas(size, size)
    scale = m / size
    area = scale * scale
    for y in range(size):
        y0, y1 = y * scale, (y + 1) * scale
        for x in range(size):
            x0, x1 = x * scale, (x + 1) * scale
            r = g = b = a = 0.0
            sy = int(math.floor(y0))
            while sy < y1:
                wy = min(y1, sy + 1.0) - max(y0, sy)
                sx = int(math.floor(x0))
                while sx < x1:
                    wx = min(x1, sx + 1.0) - max(x0, sx)
                    w = wx * wy
                    pr, pg, pb, pa = canvas[sy][sx]
                    r += pr * pa * w
                    g += pg * pa * w
                    b += pb * pa * w
                    a += pa * w
                    sx += 1
                sy += 1
            if a > 0:
                r /= a
                g /= a
                b /= a
                a /= area
            out[y][x] = (int(r), int(g), int(b), int(a))
    return out


# --------------------------------------------------------------------------
# Concepts
# --------------------------------------------------------------------------

def concept_a():
    """Blue-framed light window, bold red close X filling the body."""
    c = new_canvas(MASTER, MASTER)
    # soft drop shadow
    fill_round_rect(c, 84, 84, 468, 468, 58, (0x1E, 0x3A, 0x7A), 70 / 255)
    # window body (light) with blue frame drawn as two nested round rects
    fill_round_rect(c, 64, 64, 448, 448, 54, COLORS["window"])
    fill_round_rect(c, 62, 62, 450, 450, 56, COLORS["frame_dark"])
    fill_round_rect(c, 70, 70, 442, 442, 52, COLORS["frame"])
    # top title-bar band in blue
    fill_round_rect_grad(c, 72, 72, 438, 168, 26, (0x3B, 0x7B, 0xF8), COLORS["frame_dark"])
    fill_round_rect(c, 72, 154, 438, 168, 7, COLORS["frame_dark"])
    # window controls: three light dots on the title bar
    for i in range(3):
        dx = 112 + i * 44
        fill_round_rect(c, dx, 108, dx + 26, 134, 13, (0xD9, 0xE5, 0xFF))
    # bold red X centered in the body
    draw_close_x(c, 256, 316, 252, 46, COLORS["close_red"])
    draw_close_x(c, 256, 316, 252, 30, COLORS["close_dark"])
    return c


def concept_b():
    """Dark slate window with the classic red close button in the title bar."""
    c = new_canvas(MASTER, MASTER)
    fill_round_rect(c, 84, 84, 468, 468, 54, (0x10, 0x12, 0x18), 60 / 255)
    fill_round_rect_grad(c, 64, 64, 448, 448, 50, COLORS["slate_light"], COLORS["slate"])
    # title bar
    fill_round_rect_grad(c, 68, 68, 444, 158, 36, (0x43, 0x4A, 0x58), (0x2B, 0x2F, 0x38))
    fill_round_rect(c, 68, 146, 444, 158, 6, (0x24, 0x27, 0x2F))
    # red close button, top-right of title bar
    bx0, by0, bx1, by1 = 352, 88, 420, 156
    fill_round_rect(c, bx0, by0, bx1, by1, 34, COLORS["close_red"])
    draw_close_x(c, (bx0 + bx1) / 2, (by0 + by1) / 2, 46, 11, (0xFF, 0xFF, 0xFF))
    # faint content lines in the body (hint of a window beneath)
    for i, yy in enumerate((216, 264, 312)):
        fill_round_rect(c, 112, yy, 368 if i else 320, yy + 24, 12, (0x0B, 0x0D, 0x11), 120 / 255)
    return c


def concept_c():
    """Stacked windows: a back window and a closing front window with a big X."""
    c = new_canvas(MASTER, MASTER)
    # back window (offset up-left, dimmed)
    fill_round_rect(c, 96, 96, 432, 432, 46, (0x5A, 0x74, 0xB8), 230 / 255)
    fill_round_rect(c, 100, 100, 428, 428, 44, (0xAF, 0xC3, 0xE8))
    # front window (blue, centered, prominent)
    fill_round_rect(c, 140, 150, 452, 452, 46, (0x1E, 0x4F, 0xC4))
    fill_round_rect_grad(c, 144, 154, 448, 448, 44, (0x3B, 0x7B, 0xF8), (0x2F, 0x6B, 0xEA))
    # white X on the front window body
    draw_close_x(c, 296, 300, 232, 42, (0xFF, 0xFF, 0xFF))
    draw_close_x(c, 296, 300, 232, 28, (0x2F, 0x6B, 0xEA))
    return c


CONCEPTS = {"a": concept_a, "b": concept_b, "c": concept_c}


# --------------------------------------------------------------------------
# PNG / ICO writers
# --------------------------------------------------------------------------

def write_png(path, rows):
    h = len(rows)
    w = len(rows[0])
    def chunk(tag, data):
        out = struct.pack(">I", len(data)) + tag + data
        out += struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        return out
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    raw = b"".join(b"\x00" + b"".join(bytes(px) for px in row) for row in rows)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def make_bmp_dib(size, img):
    """BGRA XOR + 1bpp AND mask, bottom-up, biHeight doubled (ICO convention)."""
    xor = b""
    for y in range(size - 1, -1, -1):
        for x in range(size):
            r, g, b, a = img[y][x]
            xor += struct.pack("BBBB", b, g, r, a)
    and_row = ((size + 7) // 8 + 3) & ~3  # pad to 4 bytes
    and_mask = b"\x00" * (and_row * size)
    xor_len = size * size * 4
    header = struct.pack("<IiiHHIIiiII", 40, size, size * 2, 1, 32, 0, xor_len, 0, 0, 0, 0)
    return header + xor + and_mask


def write_ico(path, sizes):
    entries = b""
    blobs = b""
    offset = 6 + 16 * len(sizes)
    for s in sizes:
        img = downsample(CONCEPTS[CONCEPT](), s)
        blob = make_bmp_dib(s, img)
        entries += struct.pack("<BBBBHHII", s if s < 256 else 0, s if s < 256 else 0, 0, 0, 1, 32, len(blob), offset)
        offset += len(blob)
        blobs += blob
    with open(path, "wb") as f:
        f.write(struct.pack("<HHH", 0, 1, len(sizes)))
        f.write(entries)
        f.write(blobs)


def strip(canvas, bg):
    """Compose a preview strip: sizes shown nearest-neighbor at 64px each."""
    SIZES = [16, 24, 32, 48, 256]
    pad = 12
    cell = 64 + pad * 2
    w = len(SIZES) * cell
    out = new_canvas(w, 64 + pad * 2)
    for y in range(64 + pad * 2):
        for x in range(w):
            out[y][x] = bg
    for i, s in enumerate(SIZES):
        img = downsample(canvas, s)
        ox = pad + i * cell
        oy = pad
        # nearest-neighbor upscale to 64
        for yy in range(64):
            for xx in range(64):
                out[oy + yy][ox + xx] = img[yy * s // 64][xx * s // 64]
    return out


def render_strip(canvas):
    light = (0xFF, 0xFF, 0xFF, 255)
    dark = (0x2B, 0x2F, 0x38, 255)
    top = strip(canvas, light)
    bottom = strip(canvas, dark)
    return top + bottom


def png_from_canvas(canvas):
    rows = [[(r, g, b, a) for (r, g, b, a) in row] for row in canvas]
    return rows


CONCEPT = "a"


def main():
    global CONCEPT
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    if sys.argv[1] == "preview":
        import os
        os.makedirs("assets/out", exist_ok=True)
        for name in ("a", "b", "c"):
            CONCEPT = name
            canvas = CONCEPTS[name]()
            write_png(f"assets/out/concept_{name}.png", png_from_canvas(render_strip(canvas)))
            print(f"wrote assets/out/concept_{name}.png")
    elif sys.argv[1] == "ico":
        CONCEPT = sys.argv[2]
        write_ico("assets/app.ico", [16, 24, 32, 48, 64, 128, 256])
        print("wrote assets/app.ico")
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
