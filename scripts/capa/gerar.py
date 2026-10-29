# Arte de capa do Infinite Orb: ícone 512x512 e miniatura 1920x1080 (desenhadas por código)
# Uso: python scripts/capa/gerar.py  (gera assets/capa/icone.png e assets/capa/miniatura.png; precisa de numpy e Pillow)
import math, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

FONTS = 'C:/Windows/Fonts/'
SS = 2  # supersampling


def to_img(arr):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGB')


def to_arr(img):
    return np.asarray(img.convert('RGB')).astype(np.float32)


def add_layer(base, layer_rgba, blur=0, strength=1.0, additive=False):
    """Compõe uma camada RGBA (normal ou aditiva com brilho)."""
    if blur:
        layer_rgba = layer_rgba.filter(ImageFilter.GaussianBlur(blur))
    la = np.asarray(layer_rgba).astype(np.float32)
    rgb, a = la[..., :3], la[..., 3:4] / 255.0 * strength
    if additive:
        return base + rgb * a
    return base * (1 - a) + rgb * a


def background(W, H, ocx, ocy, R):
    y = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    top = np.array([5, 6, 20], np.float32)
    mid = np.array([26, 20, 70], np.float32)
    bot = np.array([12, 10, 36], np.float32)
    col = np.where(y < 0.62, top + (mid - top) * (y / 0.62), mid + (bot - mid) * ((y - 0.62) / 0.38))
    arr = np.broadcast_to(col, (H, W, 3)).copy()
    X, Y = np.meshgrid(np.arange(W, dtype=np.float32), np.arange(H, dtype=np.float32))
    d2 = (X - ocx) ** 2 + (Y - ocy) ** 2
    arr += np.array([90, 40, 170], np.float32) * np.exp(-d2 / (R * 3.2) ** 2)[..., None] * 0.9
    arr += np.array([40, 140, 220], np.float32) * np.exp(-d2 / (R * 1.7) ** 2)[..., None] * 0.7
    return arr, X, Y


def stars(base, W, H, count, rng, avoid=None):
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(count):
        x, y = rng.uniform(0, W), rng.uniform(0, H * 0.75)
        r = rng.choice([1, 1, 1, 1.5, 2, 3]) * SS * 0.6
        b = rng.randint(140, 255)
        tint = rng.choice([(b, b, b), (b, int(b * 0.9), int(b * 0.6)), (int(b * 0.7), int(b * 0.9), b)])
        d.ellipse([x - r, y - r, x + r, y + r], fill=tint + (255,))
    base = add_layer(base, layer, blur=3 * SS, strength=1.2, additive=True)
    return add_layer(base, layer, strength=0.9, additive=True)


def barrier(base, W, H, cx, cy, rx, ry):
    """A barreira dos arquimagos: cúpula de luz com linhas de hexágonos tênues."""
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], outline=(110, 220, 255, 255), width=int(3 * SS))
    for k in range(1, 6):  # meridianos da cúpula
        f = k / 6
        d.ellipse([cx - rx * f, cy - ry, cx + rx * f, cy + ry], outline=(110, 220, 255, 90), width=int(1.5 * SS))
    for k in range(1, 4):  # paralelos
        yy = cy - ry * k / 4
        hw = rx * math.sqrt(max(0, 1 - ((cy - yy) / ry) ** 2))
        d.ellipse([cx - hw, yy - ry * 0.06, cx + hw, yy + ry * 0.06], outline=(110, 220, 255, 70), width=int(1.5 * SS))
    base = add_layer(base, layer, blur=10 * SS, strength=0.8, additive=True)
    return add_layer(base, layer, strength=0.35, additive=True)


def ring_points(cx, cy, rx, ry, tilt, n=720):
    pts = []
    ct, st = math.cos(tilt), math.sin(tilt)
    for i in range(n + 1):
        t = 2 * math.pi * i / n
        x, y = rx * math.cos(t), ry * math.sin(t)
        pts.append((cx + x * ct - y * st, cy + x * st + y * ct, math.sin(t)))
    return pts


def draw_ring(base, W, H, cx, cy, rx, ry, tilt, width, color, front):
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    pts = ring_points(cx, cy, rx, ry, tilt)
    seg = []
    for x, y, s in pts:
        if (s > 0) == front:
            seg.append((x, y))
        elif seg:
            if len(seg) > 1:
                d.line(seg, fill=color + (255,), width=int(width), joint='curve')
            seg = []
    if len(seg) > 1:
        d.line(seg, fill=color + (255,), width=int(width), joint='curve')
    base = add_layer(base, layer, blur=width * 2.5, strength=0.9, additive=True)
    return add_layer(base, layer, strength=0.95 if front else 0.55)


def orb(base, X, Y, cx, cy, R):
    nx, ny = (X - cx) / R, (Y - cy) / R
    r2 = nx ** 2 + ny ** 2
    inside = r2 < 1
    nz = np.sqrt(np.clip(1 - r2, 0, 1))
    L = np.array([-0.45, -0.55, 0.70]); L /= np.linalg.norm(L)
    diff = np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0, 1)
    ang = np.arctan2(ny, nx)
    rr = np.sqrt(r2)
    swirl = 0.5 + 0.5 * np.sin(5 * ang + 9 * rr - 1.3) * np.sin(3 * ang - 6 * rr + 0.4)
    deep = np.array([45, 15, 110], np.float32)
    violet = np.array([140, 70, 230], np.float32)
    cyan = np.array([90, 225, 255], np.float32)
    col = deep + (violet - deep) * (diff ** 0.8)[..., None]
    col = col + (cyan - col) * (swirl * 0.55 * (1 - rr * 0.6))[..., None]
    core = np.exp(-(rr / 0.42) ** 2)
    col += np.array([200, 245, 255], np.float32) * core[..., None] * 0.9
    fres = (1 - nz) ** 3
    col += np.array([255, 190, 90], np.float32) * fres[..., None] * 0.9
    spec = np.clip(diff, 0, 1) ** 40
    col += 255 * spec[..., None] * 0.8
    edge = np.clip((R - np.sqrt((X - cx) ** 2 + (Y - cy) ** 2)) / (1.5 * SS), 0, 1)[..., None]
    out = base * (1 - edge) + col * edge
    # halo dourado em volta
    d = np.sqrt((X - cx) ** 2 + (Y - cy) ** 2)
    halo = np.exp(-((d - R) / (R * 0.10)) ** 2) * (d > R * 0.9)
    out += np.array([255, 200, 110], np.float32) * halo[..., None] * 0.55
    return out


def infinity(base, W, H, cx, cy, a, width):
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    pts = []
    for i in range(721):
        t = 2 * math.pi * i / 720
        s = 1 + math.sin(t) ** 2
        pts.append((cx + a * math.cos(t) / s, cy + a * math.sin(t) * math.cos(t) / s))
    def stamp(draw, radius, color):
        for i in range(len(pts) - 1):
            (x0, y0), (x1, y1) = pts[i], pts[i + 1]
            steps = max(1, int(math.hypot(x1 - x0, y1 - y0) / max(1, radius * 0.3)))
            for k in range(steps):
                x, y = x0 + (x1 - x0) * k / steps, y0 + (y1 - y0) * k / steps
                draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=color)
    stamp(d, width / 2, (255, 215, 120, 255))
    base = add_layer(base, layer, blur=width * 2, strength=1.3, additive=True)
    base = add_layer(base, layer, strength=1.0)
    core = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    stamp(ImageDraw.Draw(core), width * 0.18, (255, 255, 235, 255))
    return add_layer(base, core, blur=1, strength=0.95)


def particles(base, W, H, cx, cy, R, rng, count):
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(count):
        ang = rng.uniform(0, 2 * math.pi)
        dist = R * rng.uniform(1.1, 2.6)
        x, y = cx + math.cos(ang) * dist, cy + math.sin(ang) * dist * 0.8 - rng.uniform(0, R * 0.5)
        r = rng.uniform(1, 3.2) * SS
        c = rng.choice([(120, 230, 255), (190, 140, 255), (255, 210, 120)])
        d.ellipse([x - r, y - r, x + r, y + r], fill=c + (255,))
    base = add_layer(base, layer, blur=4 * SS, strength=1.4, additive=True)
    return add_layer(base, layer, strength=0.9, additive=True)


def ridge(W, base_y, amp, seed, freq):
    rng = random.Random(seed)
    phases = [(rng.uniform(0, 6.28), f, amp / (k + 1)) for k, f in enumerate(freq)]
    pts = []
    for x in range(0, W + 8, 8):
        y = base_y
        for ph, f, a in phases:
            y -= a * (0.5 + 0.5 * math.sin(x / W * f * 6.28 + ph))
        pts.append((x, y))
    return pts


def landscape(base, W, H, rng, village=True):
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    far = ridge(W, H * 0.80, H * 0.22, 3, [1.3, 3.1, 7.7])
    d.polygon(far + [(W, H), (0, H)], fill=(28, 26, 74, 255))
    near = ridge(W, H * 0.90, H * 0.12, 9, [2.2, 5.3, 11.0])
    d.polygon(near + [(W, H), (0, H)], fill=(14, 13, 40, 255))
    base = add_layer(base, layer)
    if not village:
        return base
    # vila Aurora: telhados com janelas acesas
    vill = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    lights = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dv, dl = ImageDraw.Draw(vill), ImageDraw.Draw(lights)
    ground = H * 0.93
    x = W * 0.30
    while x < W * 0.70:
        w = rng.uniform(W * 0.025, W * 0.045)
        h = rng.uniform(H * 0.04, H * 0.075)
        dv.rectangle([x, ground - h, x + w, H], fill=(9, 8, 26, 255))
        dv.polygon([(x - w * 0.12, ground - h), (x + w / 2, ground - h - w * 0.55), (x + w * 1.12, ground - h)], fill=(9, 8, 26, 255))
        for _ in range(rng.randint(1, 3)):
            wx = x + rng.uniform(0.15, 0.7) * w
            wy = ground - h + rng.uniform(0.2, 0.6) * h
            s = w * 0.13
            dl.rectangle([wx, wy, wx + s, wy + s * 1.3], fill=(255, 190, 90, 255))
        x += w + rng.uniform(W * 0.003, W * 0.015)
    # torre do relógio no meio
    tw = W * 0.022
    tx = W * 0.5 - tw / 2
    dv.rectangle([tx, ground - H * 0.10, tx + tw, H], fill=(9, 8, 26, 255))
    dv.polygon([(tx - tw * 0.2, ground - H * 0.10), (tx + tw / 2, ground - H * 0.13), (tx + tw * 1.2, ground - H * 0.10)], fill=(9, 8, 26, 255))
    dl.ellipse([tx + tw * 0.2, ground - H * 0.085, tx + tw * 0.8, ground - H * 0.085 + tw * 0.6], fill=(255, 210, 120, 255))
    base = add_layer(base, vill)
    base = add_layer(base, lights, blur=6 * SS, strength=1.5, additive=True)
    return add_layer(base, lights, strength=1.0)


def hunter(base, W, H, x, ground, h):
    """Silhueta de um hunter encapuzado sobre a rocha, com a espada brilhando apoiada no chão."""
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    c = (6, 5, 16, 255)
    rock = [(x - h * 1.0, H), (x - h * 0.8, ground + h * 0.06), (x - h * 0.35, ground - h * 0.03), (x + h * 0.35, ground), (x + h * 0.85, ground + h * 0.14), (x + h * 1.1, H)]
    d.polygon(rock, fill=c)
    top = ground - h
    sh = top + h * 0.20  # ombros
    # capa ao vento (para trás, à esquerda)
    d.polygon([(x - h * 0.06, top + h * 0.08), (x - h * 0.17, sh), (x - h * 0.30, top + h * 0.55), (x - h * 0.52, ground - h * 0.10),
               (x - h * 0.40, ground - h * 0.14), (x - h * 0.30, ground - h * 0.04), (x - h * 0.08, ground - h * 0.30)], fill=c)
    # capuz e cabeça
    d.ellipse([x - h * 0.075, top + h * 0.02, x + h * 0.075, top + h * 0.18], fill=c)
    d.polygon([(x - h * 0.07, top + h * 0.06), (x - h * 0.15, top + h * 0.03), (x - h * 0.06, top + h * 0.16)], fill=c)
    # tronco (ombros largos, cintura fina)
    d.polygon([(x - h * 0.16, sh), (x + h * 0.15, sh), (x + h * 0.09, top + h * 0.55), (x - h * 0.09, top + h * 0.55)], fill=c)
    # pernas afastadas
    d.polygon([(x - h * 0.09, top + h * 0.53), (x - h * 0.01, top + h * 0.53), (x - h * 0.10, ground), (x - h * 0.20, ground)], fill=c)
    d.polygon([(x + h * 0.01, top + h * 0.53), (x + h * 0.09, top + h * 0.53), (x + h * 0.17, ground), (x + h * 0.08, ground)], fill=c)
    # braço até a empunhadura
    hand = (x + h * 0.26, top + h * 0.50)
    d.line([(x + h * 0.12, sh + h * 0.02), (x + h * 0.21, top + h * 0.37), hand], fill=c, width=int(h * 0.055), joint='curve')
    d.line([(hand[0] - h * 0.06, hand[1] + h * 0.03), (hand[0] + h * 0.06, hand[1] - h * 0.01)], fill=c, width=int(h * 0.03))  # guarda
    base = add_layer(base, layer)
    blade = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(blade).line([(hand[0] + h * 0.01, hand[1] + h * 0.03), (x + h * 0.36, ground + h * 0.02)], fill=(150, 235, 255, 255), width=max(2, int(h * 0.028)))
    base = add_layer(base, blade, blur=h * 0.035, strength=1.8, additive=True)
    return add_layer(base, blade, strength=1.0)


def gold_text(base, W, H, text, font, cx, y, spacing):
    """Título dourado com contorno escuro, sombra e brilho."""
    widths = [font.getbbox(ch)[2] - font.getbbox(ch)[0] if ch != ' ' else font.size * 0.3 for ch in text]
    total = sum(widths) + spacing * (len(text) - 1)
    mask = Image.new('L', (W, H), 0)
    dm = ImageDraw.Draw(mask)
    x = cx - total / 2
    for ch, w in zip(text, widths):
        if ch != ' ':
            dm.text((x - font.getbbox(ch)[0], y), ch, font=font, fill=255)
        x += w + spacing
    bbox = mask.getbbox()
    stroke = mask.filter(ImageFilter.MaxFilter(int(font.size * 0.09) | 1))
    shadow = stroke.filter(ImageFilter.GaussianBlur(font.size * 0.08))
    arr = base
    sh = np.asarray(shadow).astype(np.float32)[..., None] / 255
    off = int(font.size * 0.05)
    sh = np.roll(sh, (off, off), (0, 1))
    arr = arr * (1 - sh * 0.85)
    glow = np.asarray(stroke.filter(ImageFilter.GaussianBlur(font.size * 0.25))).astype(np.float32)[..., None] / 255
    arr += np.array([255, 170, 60], np.float32) * glow * 0.45
    st = np.asarray(stroke).astype(np.float32)[..., None] / 255
    arr = arr * (1 - st) + np.array([22, 12, 40], np.float32) * st
    yy = np.arange(H, dtype=np.float32)[:, None, None]
    t = np.clip((yy - bbox[1]) / max(1, bbox[3] - bbox[1]), 0, 1)
    c1, c2, c3 = np.array([255, 246, 200], np.float32), np.array([240, 175, 55], np.float32), np.array([255, 220, 130], np.float32)
    fill = np.where(t < 0.55, c1 + (c2 - c1) * (t / 0.55), c2 + (c3 - c2) * ((t - 0.55) / 0.45))
    m = np.asarray(mask).astype(np.float32)[..., None] / 255
    return arr * (1 - m) + fill * m


def plain_text(base, W, H, text, font, cx, y, color, spacing):
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    widths = [font.getbbox(ch)[2] - font.getbbox(ch)[0] if ch != ' ' else font.size * 0.35 for ch in text]
    total = sum(widths) + spacing * (len(text) - 1)
    x = cx - total / 2
    for ch, w in zip(text, widths):
        if ch != ' ':
            d.text((x - font.getbbox(ch)[0], y), ch, font=font, fill=color + (255,), stroke_width=max(1, font.size // 12), stroke_fill=(10, 8, 28, 255))
        x += w + spacing
    return add_layer(base, layer)


def vignette(arr, X, Y, W, H, k=0.55):
    d = np.sqrt(((X - W / 2) / (W / 2)) ** 2 + ((Y - H / 2) / (H / 2)) ** 2)
    return arr * (1 - k * np.clip(d - 0.55, 0, 1) ** 1.5)[..., None]


def orb_group(arr, X, Y, W, H, cx, cy, R):
    arr = draw_ring(arr, W, H, cx, cy, R * 1.55, R * 0.42, math.radians(-14), R * 0.035, (255, 200, 95), front=False)
    arr = draw_ring(arr, W, H, cx, cy, R * 1.32, R * 0.30, math.radians(18), R * 0.022, (140, 230, 255), front=False)
    arr = orb(arr, X, Y, cx, cy, R)
    arr = infinity(arr, W, H, cx, cy, R * 0.62, R * 0.07)
    arr = draw_ring(arr, W, H, cx, cy, R * 1.55, R * 0.42, math.radians(-14), R * 0.035, (255, 200, 95), front=True)
    arr = draw_ring(arr, W, H, cx, cy, R * 1.32, R * 0.30, math.radians(18), R * 0.022, (140, 230, 255), front=True)
    return arr


def thumbnail(path):
    W, H = 1920 * SS, 1080 * SS
    rng = random.Random(7)
    cx, cy, R = W * 0.5, H * 0.36, H * 0.20
    arr, X, Y = background(W, H, cx, cy, R)
    arr = stars(arr, W, H, 420, rng)
    arr = barrier(arr, W, H, W * 0.5, H * 0.95, W * 0.62, H * 0.80)
    arr = particles(arr, W, H, cx, cy, R, rng, 90)
    arr = landscape(arr, W, H, rng, village=True)
    arr = hunter(arr, W, H, W * 0.11, H * 0.87, H * 0.22)
    arr = orb_group(arr, X, Y, W, H, cx, cy, R)
    arr = vignette(arr, X, Y, W, H)
    title = ImageFont.truetype(FONTS + 'georgiab.ttf', int(H * 0.125))
    arr = gold_text(arr, W, H, 'INFINITE ORB', title, W * 0.5, H * 0.585, int(H * 0.012))
    sub = ImageFont.truetype(FONTS + 'georgiab.ttf', int(H * 0.036))
    arr = plain_text(arr, W, H, 'O DIA QUE SE REPETE', sub, W * 0.5, H * 0.745, (170, 225, 255), int(H * 0.012))
    to_img(arr).resize((W // SS, H // SS), Image.LANCZOS).save(path)


def icon(path, with_title=True):
    W = H = 512 * SS
    rng = random.Random(11)
    cx, cy, R = W * 0.5, H * (0.40 if with_title else 0.5), H * (0.22 if with_title else 0.27)
    arr, X, Y = background(W, H, cx, cy, R)
    arr = stars(arr, W, H, 110, rng)
    arr = particles(arr, W, H, cx, cy, R, rng, 40)
    arr = landscape(arr, W, H, rng, village=False)
    arr = orb_group(arr, X, Y, W, H, cx, cy, R)
    arr = vignette(arr, X, Y, W, H, 0.7)
    if with_title:
        f1 = ImageFont.truetype(FONTS + 'georgiab.ttf', int(H * 0.15))
        arr = gold_text(arr, W, H, 'INFINITE', f1, W * 0.5, H * 0.68, int(H * 0.008))
        arr = gold_text(arr, W, H, 'ORB', f1, W * 0.5, H * 0.82, int(H * 0.02))
    to_img(arr).resize((W // SS, H // SS), Image.LANCZOS).save(path)


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'assets/capa'
    icon(out + '/icone.png')
    thumbnail(out + '/miniatura.png')
    print('ok')
