"""用新的 ReminderStatusBanner 替换旧的 _PermissionNotice。

旧版只检查"通知权限"，不看「闹钟和提醒」—— 而后者被系统收回时，
提醒会静默降级成不精确闹钟（延迟/不响），App 里完全看不出来。
"""
import io
import os

FILES = [
    r'E:\ribei\lib\screens\countdown_screen.dart',
    r'E:\ribei\lib\screens\todo_screen.dart',
]

IMPORT_ANCHOR = "import '../theme/app_theme.dart';"
NEW_IMPORT = "import '../widgets/reminder_status_banner.dart';"

OLD_USAGE = "if (!_notificationsOn) const _PermissionNotice(),"
NEW_USAGE = "const ReminderStatusBanner(),"

CLASS_HEAD = 'class _PermissionNotice extends StatelessWidget {'


def strip_class(lines, head):
    """删掉从 head 开始到第一个顶格 '}' 为止的整个类（含后面一个空行）。"""
    start = None
    for i, line in enumerate(lines):
        if line.startswith(head):
            start = i
            break
    if start is None:
        return lines, False
    end = None
    for j in range(start + 1, len(lines)):
        if lines[j].rstrip() == '}':
            end = j
            break
    if end is None:
        return lines, False
    # 连带删掉紧随其后的空行
    cut_end = end + 1
    while cut_end < len(lines) and lines[cut_end].strip() == '':
        cut_end += 1
    return lines[:start] + lines[cut_end:], True


def main():
    for path in FILES:
        with io.open(path, encoding='utf-8') as f:
            src = f.read()
        lines = src.split('\n')
        name = os.path.basename(path)

        # 1) import
        if NEW_IMPORT not in src:
            src = src.replace(
                IMPORT_ANCHOR, IMPORT_ANCHOR + '\n' + NEW_IMPORT, 1
            )
            print('  ++ %s: 加 import' % name)

        # 2) 用法替换
        n = src.count(OLD_USAGE)
        if n == 1:
            src = src.replace(OLD_USAGE, NEW_USAGE, 1)
            print('  == %s: 换成 ReminderStatusBanner' % name)
        else:
            print('  !! %s: 用法命中 %d 次' % (name, n))

        # 3) 删除旧类
        lines = src.split('\n')
        lines, removed = strip_class(lines, CLASS_HEAD)
        if removed:
            print('  -- %s: 删除旧 _PermissionNotice 类' % name)
        src = '\n'.join(lines)

        with io.open(path, 'w', encoding='utf-8') as f:
            f.write(src)


main()
