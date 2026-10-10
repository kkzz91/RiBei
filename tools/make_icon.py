# -*- coding: utf-8 -*-
"""生成「日贝」的应用图标。

为什么用脚本而不是丢几张现成图片：同一个图标要在 **5 个密度** 下产出
（还要 + 一张自适应图标的前景），手改很容易漏掉某一个密度 ——
漏了的表现是"某些手机上图标还是旧的"。脚本跑一次全部重生成，可复现。

设计（按用户选的方案）：**青玉 → 草绿 → 暖橙 的对角渐变底 + 白色沙漏 + 金色铜钱**
  · 沙漏 = 日 = 时间；铜钱 = 贝 = 货币
  · 只画图形不写字：48px 下文字一定糊

关于"图形画多大"，这里有个容易踩的坑：
  · **旧系统**用的是一张画好的圆角方图，不存在遮罩，图形可以占到约 62%；
  · **自适应图标**（Android 8+）由启动器裁形状，108dp 画布里只有中间
    **直径 66dp 的圆**是"任何遮罩下都可见"的安全区。
    图形的外接矩形必须能塞进这个圆：给定位高比 a，
    高度 h 要满足 (h/2)·√(a²+1) ≤ 33/108 ⇒ 本项目 a≈0.825，得 h ≤ 0.47。
    所以自适应那份只取 46% —— 画得太大，圆形启动器上会把铜钱切掉一块。

产出：
  1. res/mipmap-*/ic_launcher.png             旧系统用的整张图标（含圆角与底色）
  2. res/mipmap-*/ic_launcher_foreground.png  自适应图标的前景（透明底）
  3. icon_preview.png                         多尺寸 + 圆形/方圆角遮罩预览（给人看）
  4. icon_detail.png                          放大细节图（核对方孔、腰部缝隙）

用法：python tools/make_icon.py
"""

import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = 'E:/ribei'
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

# 超采样：先画大图再缩，边缘才不会有锯齿（PIL 画图本身不做抗锯齿）
SUPER = 4

# 图形外接矩形占图标的"高度比"——见文件头关于安全区的说明
ART_HEIGHT_LEGACY = 0.62
ART_HEIGHT_FOREGROUND = 0.46

DENSITIES = [
    ('mdpi', 48, 108),
    ('hdpi', 72, 162),
    ('xhdpi', 96, 216),
    ('xxhdpi', 144, 324),
    ('xxxhdpi', 192, 432),
]

# 渐变三停：青玉 → 草绿 → 暖橙
STOPS = [
    (0.0, (31, 143, 122)),
    (0.5, (63, 169, 127)),
    (1.0, (232, 150, 58)),
]

# 图形在"内容坐标系"里的样子（下面所有画图坐标都用这套，再整体映射到画布）
# 外接矩形要和 draw_art 里的实际坐标一致，否则会偏位或者算出错误的安全比例
CONTENT_L, CONTENT_T, CONTENT_R, CONTENT_B = 0.21, 0.12, 0.807, 0.887
CONTENT_W = CONTENT_R - CONTENT_L
CONTENT_H = CONTENT_B - CONTENT_T

WHITE = (255, 255, 255, 255)
# 铜钱用"浅金"而不是正铜色：图标右下角正好是暖橙渐变，
# 正铜色压上去对比太低、糊成一团；浅金比底亮，才跳得出来
GOLD = (255, 212, 122, 255)
CLEAR = (0, 0, 0, 0)


def gradient_background(size):
    """对角三停线性渐变。在 384 的小图上算好再放大 —— 渐变放大不会失真。"""
    small = 384
    img = Image.new('RGB', (small, small))
    px = img.load()
    last = len(STOPS) - 1
    for y in range(small):
        for x in range(small):
            t = (x + y) / (2.0 * (small - 1))
            for i in range(last):
                t0, c0 = STOPS[i]
                t1, c1 = STOPS[i + 1]
                if t <= t1 or i == last - 1:
                    f = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
                    f = 0.0 if f < 0 else (1.0 if f > 1 else f)
                    px[x, y] = tuple(
                        int(round(c0[k] + (c1[k] - c0[k]) * f)) for k in range(3)
                    )
                    break
    return img.resize((size, size), Image.Resampling.BICUBIC).convert('RGBA')


def add_glow(img, size):
    """左上角一层柔光，渐变才不至于"平得像贴纸"。"""
    glow = Image.new('L', (size, size), 0)
    ImageDraw.Draw(glow).ellipse(
        [-size * 0.36, -size * 0.46, size * 0.78, size * 0.68],
        fill=56,
    )
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.11))
    return Image.composite(Image.new('RGBA', (size, size), WHITE), img, glow)


def draw_art(size, height_ratio):
    """在透明画布上画图形。

    内容坐标系里的图形外接矩形是 [CONTENT_L..CONTENT_R] × [CONTENT_T..CONTENT_B]；
    这里把它**等比缩放并居中**到画布上，高度占 [height_ratio]。
    这样"画多大"就是一个参数，不用逐个坐标去凑。
    """
    layer = Image.new('RGBA', (size, size), CLEAR)
    d = ImageDraw.Draw(layer)

    scale = size * height_ratio / CONTENT_H
    # 内容中心 → 画布中心
    ccx = (CONTENT_L + CONTENT_R) / 2.0
    ccy = (CONTENT_T + CONTENT_B) / 2.0

    def px(v):
        return size / 2.0 + (v - ccx) * scale

    def py(v):
        return size / 2.0 + (v - ccy) * scale

    def u(v):
        """内容坐标系里的长度 → 像素"""
        return v * scale

    # ---------------- 沙漏 ----------------
    cx = 0.40
    top_y = 0.12
    bot_y = 0.76
    w = 0.38
    cap = 0.075
    mid = (top_y + bot_y) / 2.0
    neck = 0.018  # 腰部留一道缝，否则两个三角会看成"蝴蝶结"
    left = cx - w / 2.0
    right = cx + w / 2.0
    # 上下横梁只比三角略宽一点点。留太多会变成"两个小耳朵"，
    # 看着像蝴蝶结而不是沙漏；现在这样横梁和三角连成一个干净的梯形。
    inset = cap * 0.20

    d.rounded_rectangle(
        [px(left), py(top_y), px(right), py(top_y + cap)],
        radius=u(cap * 0.40),
        fill=WHITE,
    )
    d.rounded_rectangle(
        [px(left), py(bot_y - cap), px(right), py(bot_y)],
        radius=u(cap * 0.40),
        fill=WHITE,
    )
    d.polygon(
        [
            (px(left + inset), py(top_y + cap)),
            (px(right - inset), py(top_y + cap)),
            (px(cx), py(mid - neck)),
        ],
        fill=WHITE,
    )
    d.polygon(
        [
            (px(left + inset), py(bot_y - cap)),
            (px(right - inset), py(bot_y - cap)),
            (px(cx), py(mid + neck)),
        ],
        fill=WHITE,
    )

    # ---------------- 铜钱（右下角，轻压住沙漏右下角）----------------
    coin_x = 0.655
    coin_y = 0.735
    coin_r = 0.152
    d.ellipse(
        [px(coin_x - coin_r), py(coin_y - coin_r),
         px(coin_x + coin_r), py(coin_y + coin_r)],
        fill=GOLD,
    )
    d.ellipse(
        [px(coin_x - coin_r), py(coin_y - coin_r),
         px(coin_x + coin_r), py(coin_y + coin_r)],
        outline=WHITE,
        width=max(SUPER, int(u(coin_r * 0.22))),
    )
    # 方孔：画成完全透明的像素（PIL 是替换不是混合），孔里于是透出底下的渐变
    hole = coin_r * 0.30
    d.rectangle(
        [px(coin_x - hole), py(coin_y - hole),
         px(coin_x + hole), py(coin_y + hole)],
        fill=CLEAR,
    )

    return layer


def rounded_mask(size, radius_ratio=0.225):
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1],
        radius=size * radius_ratio,
        fill=255,
    )
    return mask


def build_legacy(size):
    """旧系统用的整张图标：渐变底 + 圆角 + 图形。"""
    work = size * SUPER
    img = add_glow(gradient_background(work), work)
    img.alpha_composite(draw_art(work, ART_HEIGHT_LEGACY))
    img.putalpha(rounded_mask(work))
    return img.resize((size, size), Image.Resampling.LANCZOS)


def build_foreground(size):
    """自适应图标的前景：透明底，只有图形（缩到安全圆里）。"""
    work = size * SUPER
    return draw_art(work, ART_HEIGHT_FOREGROUND).resize(
        (size, size), Image.Resampling.LANCZOS
    )


def build_preview():
    """各尺寸摆一排，外加圆 / 方圆角两种遮罩效果，方便一眼看出好不好看。"""
    pad = 24
    big = 190
    tiles = [big, 144, 96, 72, 48]
    width = pad + sum(t + pad for t in tiles) + (big + pad) * 2 + pad
    canvas = Image.new('RGBA', (width, big + pad * 2), (250, 248, 245, 255))

    x = pad
    for t in tiles:
        canvas.alpha_composite(build_legacy(t), (x, pad + (big - t) // 2))
        x += t + pad

    # 自适应图标在两种遮罩下的效果
    composed = add_glow(gradient_background(432), 432)
    composed.alpha_composite(build_foreground(432))
    composed = composed.resize((big, big), Image.Resampling.LANCZOS)

    circle = composed.copy()
    cmask = Image.new('L', (big, big), 0)
    ImageDraw.Draw(cmask).ellipse([0, 0, big - 1, big - 1], fill=255)
    circle.putalpha(cmask)
    canvas.alpha_composite(circle, (x, pad))
    x += big + pad

    squircle = composed.copy()
    squircle.putalpha(rounded_mask(big, 0.42))
    canvas.alpha_composite(squircle, (x, pad))

    out = os.path.join(ROOT, 'icon_preview.png')
    canvas.convert('RGB').save(out, 'PNG')
    return out


def build_detail():
    """把 192px 那版放大，专门核对铜钱方孔、沙漏腰缝这些细节。"""
    icon = build_legacy(192 * 4)
    side = int(icon.width * 0.66)
    off = (icon.width - side) // 2
    crop = icon.crop((off, off, off + side, off + side))
    crop = crop.resize((440, 440), Image.Resampling.LANCZOS)
    out = os.path.join(ROOT, 'icon_detail.png')
    crop.convert('RGB').save(out, 'PNG')
    return out


def main():
    made = 0
    for name, legacy, foreground in DENSITIES:
        folder = os.path.join(RES, 'mipmap-%s' % name)
        os.makedirs(folder, exist_ok=True)
        build_legacy(legacy).save(
            os.path.join(folder, 'ic_launcher.png'), 'PNG'
        )
        build_foreground(foreground).save(
            os.path.join(folder, 'ic_launcher_foreground.png'), 'PNG'
        )
        made += 2
        print('%-8s 图标 %3dpx / 前景 %3dpx' % (name, legacy, foreground))

    print('\n预览图：%s' % build_preview())
    print('细节图：%s' % build_detail())
    print('共生成 %d 个图标文件' % made)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
