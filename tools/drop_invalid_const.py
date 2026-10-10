"""移除包含了动态取色（context.palette / AppText.xxx(context)）的 const 关键字。

Dart 的 const 表达式必须是编译期常量，而 context.palette 是运行期值，
所以这些 const 必须去掉。用括号配对扫描定位每个 const 表达式的范围，
只对真正受影响的表达式动手，不误删其它 const。
"""
import re
import os
import glob

OPENERS = '([{'
CLOSERS = ')]}'


def const_spans(src):
    spans = []
    for m in re.finditer(r'\bconst\b', src):
        i = m.end()
        while i < len(src) and src[i].isspace():
            i += 1
        # 跳过类型/标识符，如 Icon、BorderRadius.circular、_LegendDot
        j = i
        while j < len(src) and (src[j].isalnum() or src[j] in '_.<>'):
            j += 1
        if j >= len(src) or src[j] not in OPENERS:
            continue
        depth = 0
        k = j
        quote = None
        while k < len(src):
            c = src[k]
            if quote:
                if c == '\\':
                    k += 2
                    continue
                if c == quote:
                    quote = None
            elif c in ('"', "'"):
                quote = c
            elif c in OPENERS:
                depth += 1
            elif c in CLOSERS:
                depth -= 1
                if depth == 0:
                    break
            k += 1
        if depth == 0 and k < len(src):
            spans.append((m.start(), k + 1))
    return spans


def main():
    root = r'E:\ribei\lib'
    files = glob.glob(os.path.join(root, '**', '*.dart'), recursive=True)
    total = 0
    for path in files:
        with open(path, encoding='utf-8') as f:
            src = f.read()
        targets = []
        for a, b in const_spans(src):
            seg = src[a:b]
            if 'context.palette' in seg or re.search(r'AppText\.\w+\(context\)', seg):
                targets.append((a, b))
        if not targets:
            continue
        out = src
        for a, b in reversed(targets):
            seg = out[a:b]
            out = out[:a] + re.sub(r'^const\s+', '', seg) + out[b:]
        with open(path, 'w', encoding='utf-8') as f:
            f.write(out)
        total += len(targets)
        print('  %-40s 去掉 %d 个 const' % (os.path.basename(path), len(targets)))
    print('共处理 %d 处' % total)


main()
