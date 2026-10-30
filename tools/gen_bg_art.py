"""
生成《元素之境》主菜单的背景精灵：远山、浮岛A、浮岛B。
输出到 scripts/ui/bg/，RGBA PNG，3 倍超采样后缩回，边缘平滑，带柔和体积感。

做法：先手写一条"岩体剖面"折线（顶边 + 崖壁 + 参差的岩腹），沿法线方向做多倍频
置换得到自然的岩石锯齿，再叠竖直渐变、噪声纹理、苔藓带、针叶树和底部大气压暗。

用法：python tools/gen_bg_art.py
"""

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = os.path.join("scripts", "ui", "bg")
SS = 3  # 超采样倍数


def smooth_noise(w, h, cells, seed):
    rng = np.random.default_rng(seed)
    small = rng.random((max(2, cells), max(2, cells)))
    img = Image.fromarray((small * 255).astype(np.uint8), "L").resize((w, h), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255.0


def fbm(w, h, octaves=4, base=4, seed=0):
    total = np.zeros((h, w), dtype=np.float32)
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        total += (smooth_noise(w, h, base * (2 ** o), seed + o * 17) * 2.0 - 1.0) * amp
        norm += amp
        amp *= 0.5
    return total / norm


def vgrad(w, h, top, bottom):
    arr = np.zeros((h, w, 4), dtype=np.float32)
    t = (np.arange(h, dtype=np.float32) / max(1, h - 1))[:, None, None]
    for c in range(3):
        arr[:, :, c] = top[c] + (bottom[c] - top[c]) * t[:, :, 0]
    arr[:, :, 3] = 255.0
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


class Outline:
    """沿折线采样 + 法线置换，得到自然的岩石轮廓"""

    def __init__(self, base_pts, rng, amp, detail_amp):
        # 每段按长度细分
        dense = []
        for i in range(len(base_pts)):
            a = np.array(base_pts[i], dtype=np.float64)
            b = np.array(base_pts[(i + 1) % len(base_pts)], dtype=np.float64)
            n = max(2, int(np.linalg.norm(b - a) / 3.0))
            for k in range(n):
                dense.append(a + (b - a) * (k / n))
        dense = np.array(dense)

        # 1D 多倍频噪声（沿轮廓方向的相位）
        phases = [(rng.random() * math.tau, f, rng.random()) for f in (3.0, 7.0, 17.0, 31.0)]
        n = len(dense)
        disp = np.zeros(n)
        for idx in range(n):
            u = idx / n
            v = 0.0
            wsum = 0.0
            for ph, f, wt in phases:
                amp_k = 1.0 if f < 10 else (0.5 if f < 20 else 0.28)
                v += math.sin(u * math.tau * f + ph) * amp_k * wt
                wsum += amp_k
            disp[idx] = v / wsum

        center = dense.mean(axis=0)
        out = []
        for i in range(n):
            p = dense[i]
            prev_p = dense[(i - 1) % n]
            next_p = dense[(i + 1) % n]
            tangent = next_p - prev_p
            tl = np.linalg.norm(tangent) or 1.0
            normal = np.array([-tangent[1], tangent[0]]) / tl
            if np.dot(normal, p - center) < 0:
                normal = -normal
            scale = amp if i < n * 0.06 or i > n * 0.94 else detail_amp
            p2 = p + normal * disp[i] * scale
            out.append((float(p2[0]), float(p2[1])))
        self.pts = out


def island_profile(w, h, top_frac, half_frac, keel_bias):
    """手写的岩体剖面：顶边轻微起伏 → 近乎垂直的崖壁 → 参差的岩腹"""
    cx = w * 0.5
    top_y = h * top_frac
    half_w = w * half_frac
    depth = h * 0.80

    def P(x, s):
        return (cx + half_w * x, top_y + depth * s)

    pts = []
    # 顶边：左 → 右（4 个起伏，两端略低）
    top_samples = 22
    for i in range(top_samples + 1):
        t = i / top_samples
        x = -1.0 + t * 2.0
        dome = math.sin(t * math.pi) ** 0.5
        wob = math.sin(t * math.pi * 3.7 + 0.6) * 0.018 + math.sin(t * math.pi * 8.1) * 0.010
        pts.append(P(x, 0.035 - dome * 0.028 + wob))
    # 右侧崖壁 + 岩腹
    right = [
        (1.000, 0.10), (1.004, 0.20), (0.992, 0.30), (0.998, 0.40),
        (0.960, 0.47), (0.972, 0.52), (0.900, 0.58), (0.860, 0.65),
        (0.880, 0.69), (0.780, 0.74), (0.690, 0.80), (0.570, 0.86),
        (0.430, 0.92), (0.300, 0.97), (0.180, 1.00),
    ]
    for x, s in right:
        pts.append(P(x, s))
    # 岩根（偏心 + 钝头）
    pts.append(P(0.090 + keel_bias, 1.055))
    pts.append(P(-0.020 + keel_bias, 1.015))
    pts.append(P(-0.130 + keel_bias, 1.060))
    # 左侧岩腹 + 崖壁（与右侧不对称）
    left = [
        (-0.230, 0.985), (-0.350, 0.940), (-0.470, 0.895), (-0.590, 0.845),
        (-0.680, 0.795), (-0.750, 0.735), (-0.820, 0.690), (-0.855, 0.635),
        (-0.935, 0.575), (-0.925, 0.520), (-0.980, 0.455), (-0.996, 0.360),
        (-0.990, 0.270), (-1.002, 0.180), (-1.000, 0.090),
    ]
    for x, s in left:
        pts.append(P(x, s))
    return pts


def island_mask(w, h, top_frac, half_frac, keel_bias, seed, top_samples=22):
    rng = np.random.default_rng(seed)
    base = island_profile(w, h, top_frac, half_frac, keel_bias)
    outline = Outline(base, rng, amp=w * 0.020, detail_amp=w * 0.010)
    pts = [(min(max(x, 2.0), w - 3.0), min(max(y, 2.0), h - 3.0)) for x, y in outline.pts]

    img = Image.new("L", (w, h), 0)
    ImageDraw.Draw(img).polygon([(int(x), int(y)) for x, y in pts], fill=255)
    return img, pts


def make_island(path, size, top_frac, half_frac, keel_bias, seed,
                rock_top, rock_bottom, moss, moss_lit, tree_count=3):
    w, h = size[0] * SS, size[1] * SS
    mask, poly = island_mask(w, h, top_frac, half_frac, keel_bias, seed)
    cx = w * 0.5
    top_y = h * top_frac
    half_w = w * half_frac

    # --- 岩体：竖直渐变 + 双尺度噪声（大块明暗 + 细碎颗粒）---
    body = vgrad(w, h, rock_top, rock_bottom)
    big = fbm(w, h, octaves=3, base=4, seed=seed + 7)
    grain = fbm(w, h, octaves=3, base=26, seed=seed + 33)
    strata = np.sin((np.arange(h, dtype=np.float32)[:, None] / h) * 42.0
                    + fbm(w, h, octaves=2, base=3, seed=seed + 71) * 3.0)
    arr = np.asarray(body, dtype=np.float32)
    shade = 1.0 + big * 0.20 + grain * 0.10 + strata * 0.03
    arr[..., :3] = np.clip(arr[..., :3] * shade[..., None], 0, 255)
    body = Image.fromarray(arr.astype(np.uint8), "RGBA")

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(body, (0, 0), mask)

    # --- 苔藓带：沿顶边的一条不规则厚带 ---
    moss_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    md = ImageDraw.Draw(moss_img)
    tn = fbm(w, h, octaves=3, base=16, seed=seed + 55)
    top_pts = [p for p in poly[:130] if p[0] <= cx + half_w * 1.02]  # 顶边 + 右壁开头
    top_pts = [p for p in top_pts if p[1] <= top_y + h * 0.06]
    top_pts.sort(key=lambda q: q[0])
    band, lower = [], []
    for x, y in top_pts:
        thick = h * (0.016 + 0.012 * tn[int(max(0, min(h - 1, y))), int(max(0, min(w - 1, x)))])
        band.append((x, y - h * 0.010))
        lower.append((x, y + thick))
    md.polygon([(int(x), int(y)) for x, y in band + lower[::-1]], fill=moss)
    moss_img = moss_img.filter(ImageFilter.GaussianBlur(SS * 0.7))
    moss_img.putalpha(Image.composite(moss_img.getchannel("A"), Image.new("L", (w, h), 0), mask))
    out.alpha_composite(moss_img)

    # --- 苔藓上缘提亮 ---
    lit = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(lit).line([(int(x), int(y) - SS) for x, y in band],
                             fill=moss_lit, width=int(SS * 1.1))
    lit = lit.filter(ImageFilter.GaussianBlur(SS * 0.5))
    lit.putalpha(Image.composite(lit.getchannel("A"), Image.new("L", (w, h), 0), mask))
    out.alpha_composite(lit)

    # --- 左上轮廓光：沿"左壁 → 顶左 → 顶右"这段连续轮廓画，不能按 y 排序
    #     （按 y 排序会把左右壁的点连成一片，糊出一条水平的亮带）
    rim = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    top_count = 0
    for p in poly:
        if p[1] <= top_y + h * 0.05:
            top_count += 1
        else:
            break
    left_count = 0
    for p in reversed(poly):
        if p[0] >= cx - half_w * 0.55 and p[1] > top_y + h * 0.05:
            left_count += 1
        else:
            break
    if top_count > 4:
        rim_pts = poly[len(poly) - left_count:] + poly[:top_count]
        ImageDraw.Draw(rim).line([(int(x), int(y)) for x, y in rim_pts],
                                 fill=(118, 148, 182, 110), width=int(SS * 1.2))
        rim = rim.filter(ImageFilter.GaussianBlur(SS * 0.9))
        rim.putalpha(Image.composite(rim.getchannel("A"), Image.new("L", (w, h), 0), mask))
        out.alpha_composite(rim)

    # --- 针叶树 / 灌木 ---
    rng = np.random.default_rng(seed + 5)
    trees = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    td = ImageDraw.Draw(trees)
    for i in range(tree_count):
        t = 0.20 + 0.60 * rng.random()
        x = cx - half_w + t * half_w * 2.0
        dome = math.sin(t * math.pi) ** 0.5
        base_y = top_y + h * (0.035 - dome * 0.028)
        th = h * (0.060 + 0.050 * rng.random())
        tw = th * (0.30 + 0.10 * rng.random())
        for k in range(3):
            frac = k / 3
            y0 = base_y - th * (0.22 + 0.60 * frac)
            ww = tw * (1.0 - 0.22 * k)
            td.polygon([(x - ww, y0 + th * 0.30), (x, y0 - th * 0.18), (x + ww, y0 + th * 0.30)],
                       fill=(17, 29, 27, 240))
        td.line([(x, base_y), (x, base_y - th * 0.72)], fill=(13, 23, 21, 230), width=SS)
    for i in range(5):
        bx = cx + (rng.random() - 0.5) * half_w * 1.5
        by = top_y + h * (0.032 + (rng.random() - 0.5) * 0.012)
        r = w * (0.011 + 0.011 * rng.random())
        td.ellipse([bx - r, by - r * 0.85, bx + r, by + r * 0.45], fill=(22, 40, 34, 225))
    trees = trees.filter(ImageFilter.GaussianBlur(SS * 0.7))
    out.alpha_composite(trees)

    # --- 崖壁上的岩层细线（短、斜、贴着轮廓内侧）---
    lines = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lines)
    for k in range(6):
        s = 0.10 + 0.12 * k + rng.random() * 0.03
        y = top_y + h * 0.80 * s
        span = w * (0.10 + 0.10 * rng.random())
        x0 = cx + (rng.random() - 0.5) * half_w * 1.2 - span * 0.5
        ld.line([(x0, y), (x0 + span, y + span * (0.06 + 0.10 * rng.random()))],
                fill=(12, 17, 30, 120), width=max(1, int(SS * 0.8)))
    lines = lines.filter(ImageFilter.GaussianBlur(SS * 0.6))
    lines.putalpha(Image.composite(lines.getchannel("A"), Image.new("L", (w, h), 0), mask))
    out.alpha_composite(lines)

    # --- 岩根附近挂着的碎岩块（把剪影打散，别只剩一个整块）---
    shards = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shards)
    for i in range(4):
        sx = cx + (rng.random() - 0.5) * half_w * 1.5
        sy = top_y + h * (0.62 + 0.30 * rng.random())
        sr = w * (0.012 + 0.020 * rng.random())
        pts_shard = []
        for k in range(7):
            ang = k / 7 * math.tau
            rr = sr * (0.62 + 0.55 * rng.random())
            pts_shard.append((sx + math.cos(ang) * rr, sy + math.sin(ang) * rr * 0.8))
        sd.polygon(pts_shard, fill=(44, 58, 88, 150))
    shards = shards.filter(ImageFilter.GaussianBlur(SS * 0.8))
    out.alpha_composite(shards)

    # --- 底部压暗（大气透视）---
    ys = np.arange(h, dtype=np.float32)[:, None]
    ramp = np.clip((ys - (top_y + 0.22 * h)) / (0.78 * h), 0, 1) ** 1.5
    alpha_arr = np.repeat((ramp * 74).astype(np.uint8), w, axis=1)
    dark = Image.new("RGBA", (w, h), (6, 9, 18, 255))
    dark.putalpha(Image.composite(Image.fromarray(alpha_arr, "L"), Image.new("L", (w, h), 0), mask))
    out.alpha_composite(dark)

    # --- 轮廓下缘的冷色环境光：把"悬空的岩底"从背景里勾出来 ---
    # 只取多边形顺序上连续的一段（岩腹 → 岩根 → 另一侧岩腹），
    # 否则左右壁同高度的点会被连成一条横线。
    rim = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rim)
    low = [p[1] > top_y + h * 0.36 for p in poly]
    best_start, best_len, run_start = 0, 0, None
    for i, flag in enumerate(low + [False]):
        if flag and run_start is None:
            run_start = i
        elif not flag and run_start is not None:
            if i - run_start > best_len:
                best_len, best_start = i - run_start, run_start
            run_start = None
    if best_len > 3:
        rim_pts = [poly[i % len(poly)] for i in range(best_start, best_start + best_len)]
        rd.line(rim_pts, fill=(126, 156, 198, 84), width=max(1, int(SS * 1.3)), joint="curve")
        rim = rim.filter(ImageFilter.GaussianBlur(SS * 1.1))
        rim.putalpha(Image.composite(rim.getchannel("A"), Image.new("L", (w, h), 0), mask))
        out.alpha_composite(rim)

    out = out.resize(size, Image.LANCZOS)
    out.save(path)
    print("wrote", path, out.size)


def make_range(path, size, base_frac, amp_frac, color, alpha, seed, blur=2.0):
    w, h = size[0], size[1]
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    n = fbm(w, h, octaves=3, base=5, seed=seed)
    peaks = []
    x = -10.0
    while x <= w + 10:
        t = x / w
        ridge = (0.52 * abs(math.sin(t * math.pi * 2.7 + seed * 0.1))
                 + 0.30 * abs(math.sin(t * math.pi * 6.1 + 1.3))
                 + 0.18 * abs(math.sin(t * math.pi * 11.3 + 2.1)))
        y = h * base_frac - h * amp_frac * ridge
        y += n[int(max(0, min(h - 1, y))), int(max(0, min(w - 1, x)))] * h * 0.05
        peaks.append((x, y))
        x += max(3.0, w / 320.0)
    d.polygon([(int(x), int(y)) for x, y in peaks] + [(w + 10, h), (-10, h)],
              fill=color + (alpha,))
    img = img.filter(ImageFilter.GaussianBlur(blur))
    img.save(path)
    print("wrote", path, img.size)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    make_range(os.path.join(OUT_DIR, "range_far.png"), (1400, 300), 0.78, 0.54,
               (24, 30, 56), 190, 3, blur=2.6)
    make_range(os.path.join(OUT_DIR, "range_mid.png"), (1400, 300), 0.88, 0.48,
               (17, 22, 42), 210, 11, blur=1.9)

    make_island(os.path.join(OUT_DIR, "island_a.png"), (420, 380), 0.16, 0.44, -0.02, 21,
                rock_top=(52, 66, 96), rock_bottom=(22, 29, 48),
                moss=(38, 66, 55, 235), moss_lit=(94, 134, 104, 235), tree_count=3)
    make_island(os.path.join(OUT_DIR, "island_b.png"), (380, 330), 0.18, 0.43, 0.03, 47,
                rock_top=(48, 60, 88), rock_bottom=(20, 26, 42),
                moss=(35, 61, 50, 230), moss_lit=(86, 124, 96, 230), tree_count=2)


if __name__ == "__main__":
    main()
