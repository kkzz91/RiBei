# -*- coding: utf-8 -*-
"""生成「日贝」的朋友圈海报。

**为什么需要这个**：朋友圈只能发图片和视频，**发不了文件**。
所以推广只能靠一张图引流，安装包另外走「群文件 / 私聊」发。
（用户已经确认走这条路，所以海报里不嵌二维码、不需要网盘。）

产出：E:\\ribei\\宣传图\\日贝-朋友圈海报.png （1080×1350，4:5，朋友圈显示比例舒服）
"""

import io
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = 'E:/ribei'
OUT_DIR = os.path.join(ROOT, '宣传图')
ICON = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res',
                    'mipmap-xxxhdpi', 'ic_launcher.png')

W, H = 1080, 1350

FONT_REG = 'C:/Windows/Fonts/msyh.ttc'
FONT_BOLD = 'C:/Windows/Fonts/msyhbd.ttc'

# 和 App 内部一致的青玉色系
JADE = (31, 94, 82)
JADE_LIGHT = (82, 166, 146)
PAPER = (250, 248, 245)
INK = (28, 27, 25)
INK_SOFT = (107, 103, 96)

# 分类专属色（借 App 里那套，让海报和界面一个气质）
DOTS = [(224, 123, 57), (58, 134, 200), (212, 93, 140), (47, 143, 127),
        (22, 160, 168), (201, 162, 39)]

BULLETS = [
    ('记一笔只要两下', '常花的那几笔存成「常用」，点一下就记好了'),
    ('记账 + 倒计时 + 待办', '一个 App 装下，倒计时支持农历和重复'),
    ('数据只在你手机里', '不联网、不上传、不需要注册账号'),
    ('月底还能分享账单', '生成一张好看的账单图，直接发朋友圈'),
]


def font(path, size):
    return ImageFont.truetype(path, size)


def rounded(img, radius_ratio=0.0):
    """给整张图加圆角（可选；海报一般不需要，留个口子）"""
    if radius_ratio <= 0:
        return img
    mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, img.size[0] - 1, img.size[1] - 1],
        radius=img.size[0] * radius_ratio, fill=255)
    out = img.copy()
    out.putalpha(mask)
    return out


def build():
    img = Image.new('RGB', (W, H), PAPER)
    d = ImageDraw.Draw(img)

    # ---------- 背景：上下淡青的柔和渐变 ----------
    for y in range(H):
        t = y / (H - 1)
        # 顶部略深一点，底部回到纸色
        r = int(238 + (250 - 238) * t)
        g = int(244 + (248 - 244) * t)
        b = int(240 + (245 - 240) * t)
        d.line([(0, y), (W, y)], fill=(r, g, b))

    # 顶部一条青玉色横幅
    band_h = 296
    for y in range(band_h):
        t = y / band_h
        r = int(JADE[0] + (42 - JADE[0]) * t)
        g = int(JADE[1] + (120 - JADE[1]) * t)
        b = int(JADE[2] + (104 - JADE[2]) * t)
        d.line([(0, y), (W, y)], fill=(r, g, b))

    # ---------- 图标 ----------
    icon = Image.open(ICON).convert('RGBA').resize((200, 200), Image.LANCZOS)
    icon_x, icon_y = 84, 74
    img.paste(icon, (icon_x, icon_y), icon)

    # ---------- 标题 ----------
    d.text((icon_x + 232, 84), '日贝', font=font(FONT_BOLD, 92),
           fill=(255, 255, 255))
    d.text((icon_x + 238, 196), '记账 · 倒计时 · 待办提醒',
           font=font(FONT_REG, 30), fill=(198, 226, 217))

    # 副标题（横幅下方）
    d.text((84, band_h + 58), '一个把数据只放在你自己手机里的 App',
           font=font(FONT_BOLD, 44), fill=INK)
    d.text((84, band_h + 124), '安卓手机装上就能用，不用注册、不用登录',
           font=font(FONT_REG, 30), fill=INK_SOFT)

    # ---------- 四个卖点 ----------
    y = band_h + 216
    for i, (title, body) in enumerate(BULLETS):
        # 左侧小色块
        color = DOTS[i % len(DOTS)]
        d.rounded_rectangle([84, y + 6, 84 + 16, y + 22], radius=5, fill=color)
        d.text((124, y - 10), title, font=font(FONT_BOLD, 40), fill=INK)
        d.text((124, y + 46), body, font=font(FONT_REG, 29), fill=INK_SOFT)
        y += 124

    # ---------- 底部：怎么拿安装包 ----------
    card_top = H - 236
    d.rounded_rectangle([64, card_top, W - 64, H - 64], radius=28,
                        fill=(255, 255, 255), outline=(226, 238, 233), width=2)
    d.text((104, card_top + 30), '想要安装包？', font=font(FONT_BOLD, 40),
           fill=JADE)
    d.text((104, card_top + 92), '在群里说一声，或者私聊我，我发给你',
           font=font(FONT_REG, 31), fill=INK)
    d.text((104, card_top + 142), '装好之后第一次打开，记得把提醒权限开全',
           font=font(FONT_REG, 26), fill=INK_SOFT)

    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, '日贝-朋友圈海报.png')
    img.save(out, 'PNG')
    return out


if __name__ == '__main__':
    path = build()
    print('海报已生成：%s' % path)
    print('尺寸：%dx%d' % (W, H))
    sys.exit(0)
