"""重写倒计时卡片布局。

问题：左侧色条是 5px 宽却给了 20px 圆角（半径超过宽度一半会被压成畸形），
而且高度写死 92px；卡片本身还有 1px 描边 —— 两套圆角/边框叠在一起就是
用户看到的"两个框重合"。

修法：卡片加 clipBehavior 让内容按卡片圆角裁剪；色条去掉自身圆角与固定高度，
用 IntrinsicHeight + stretch 自动撑满卡片高度；上下留白改由内容区的 padding 提供。
"""
import io

PATH = r'E:\ribei\lib\screens\countdown_screen.dart'

OLD = """      child: Card(
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
            child: Row(
              children: [
                // 左侧紧迫度色条
                Container(
                  width: 5,
                  height: 92,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 剩余天数
                SizedBox(
                  width: 74,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${days.abs()}',
                        style: AppText.dayHero(context).copyWith(color: color),
                      ),
                      Text(
                        event.isPast ? '天前' : '天',
                        style: AppText.label(context).copyWith(color: color),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ["""

NEW = """      child: Card(
        // 让内容按卡片圆角裁剪。左侧色条紧贴卡片边缘，
        // 不裁剪的话色条自身的圆角会和卡片描边叠成"两套框"。
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: IntrinsicHeight(
            child: Row(
              // 让色条自动撑满卡片高度（原来写死 92px，内容一变就露馅）
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: color),
                const SizedBox(width: 16),
                // 剩余天数
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: SizedBox(
                    width: 74,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${days.abs()}',
                          style: AppText.dayHero(
                            context,
                          ).copyWith(color: color),
                        ),
                        Text(
                          event.isPast ? '天前' : '天',
                          style: AppText.label(context).copyWith(color: color),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: ["""

# 内容列的收尾部分（从 Column 结束到处）
OLD_TAIL = """                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: context.palette.inkFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );"""

NEW_TAIL = """                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: context.palette.inkFaint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );"""


def main():
    with io.open(PATH, encoding='utf-8') as f:
        src = f.read()
    for name, old, new in (('卡片头部', OLD, NEW), ('卡片尾部', OLD_TAIL, NEW_TAIL)):
        n = src.count(old)
        if n != 1:
            print('  !! %s 命中 %d 次，跳过' % (name, n))
            continue
        src = src.replace(old, new, 1)
        print('  == %s 已替换' % name)
    with io.open(PATH, 'w', encoding='utf-8') as f:
        f.write(src)


main()
