"""批量插入触感反馈调用与 import。

纯机械替换，用字面匹配（非正则），改完由 flutter analyze 兜底校验。
"""
import os

LIB = r'E:\ribei\lib'

# 锚点：所有 screen 都 import 了 app_theme
ANCHOR = "import '../theme/app_theme.dart';"

IMPORTS = {
    'screens/add_countdown_screen.dart': ["import '../utils/haptics.dart';"],
    'screens/add_todo_screen.dart': ["import '../utils/haptics.dart';"],
    'screens/add_transaction_screen.dart': ["import '../utils/haptics.dart';"],
    'screens/todo_screen.dart': ["import '../utils/haptics.dart';"],
    'screens/main_shell.dart': ["import '../utils/haptics.dart';"],
    'screens/ledger_screen.dart': [
        "import '../utils/haptics.dart';",
        "import 'settings_screen.dart';",
    ],
}

REPLACEMENTS = {
    'screens/main_shell.dart': [
        (
            "onDestinationSelected: (i) => setState(() => _index = i),",
            "onDestinationSelected: (i) {\n"
            "          Haptics.tap();\n"
            "          setState(() => _index = i);\n"
            "        },",
        ),
    ],
    'screens/add_transaction_screen.dart': [
        # ★ 数字键盘：每按一下都给一次触感，这是"类微信输入"手感的核心
        (
            "onTap: () => onKey(key),",
            "onTap: () {\n"
            "            Haptics.tap();\n"
            "            onKey(key);\n"
            "          },",
        ),
        # 选分类
        (
            "onTap: () => onSelected(c.name),",
            "onTap: () {\n"
            "            Haptics.tap();\n"
            "            onSelected(c.name);\n"
            "          },",
        ),
        # 切支出/收入
        (
            "onTap: () => onChanged(value),",
            "onTap: () {\n"
            "            Haptics.tap();\n"
            "            onChanged(value);\n"
            "          },",
        ),
        # 保存
        (
            "setState(() => _saving = true);",
            "Haptics.impact();\n    setState(() => _saving = true);",
        ),
    ],
    'screens/todo_screen.dart': [
        # 勾选完成
        (
            "onTap: onTap,\n      behavior: HitTestBehavior.opaque,",
            "onTap: () {\n"
            "        Haptics.impact();\n"
            "        onTap();\n"
            "      },\n"
            "      behavior: HitTestBehavior.opaque,",
        ),
    ],
    'screens/add_todo_screen.dart': [
        (
            "setState(() => _saving = true);",
            "Haptics.impact();\n    setState(() => _saving = true);",
        ),
    ],
    'screens/add_countdown_screen.dart': [
        (
            "setState(() => _saving = true);",
            "Haptics.impact();\n    setState(() => _saving = true);",
        ),
    ],
    'screens/ledger_screen.dart': [
        # 顶栏加设置入口
        (
            "      appBar: AppBar(\n        title: const Text('账本'),\n        actions: [",
            "      appBar: AppBar(\n"
            "        title: const Text('账本'),\n"
            "        actions: [\n"
            "          IconButton(\n"
            "            tooltip: '设置',\n"
            "            icon: const Icon(Icons.settings_outlined),\n"
            "            onPressed: () {\n"
            "              Haptics.tap();\n"
            "              Navigator.of(context).push(\n"
            "                MaterialPageRoute<void>(\n"
            "                  builder: (_) => const SettingsScreen(),\n"
            "                ),\n"
            "              );\n"
            "            },\n"
            "          ),",
        ),
    ],
}


def main():
    for rel, lines in IMPORTS.items():
        path = os.path.join(LIB, rel.replace('/', os.sep))
        with open(path, encoding='utf-8') as f:
            src = f.read()
        if ANCHOR not in src:
            print('  !! 找不到锚点: %s' % rel)
            continue
        if lines[0] in src:
            print('  -- import 已存在，跳过: %s' % rel)
        else:
            src = src.replace(
                ANCHOR, ANCHOR + '\n' + '\n'.join(lines), 1
            )
            with open(path, 'w', encoding='utf-8') as f:
                f.write(src)
            print('  ++ 已加 import: %s (%d 个)' % (rel, len(lines)))

    for rel, pairs in REPLACEMENTS.items():
        path = os.path.join(LIB, rel.replace('/', os.sep))
        with open(path, encoding='utf-8') as f:
            src = f.read()
        hits = 0
        for old, new in pairs:
            n = src.count(old)
            if n == 0:
                print('  !! 未匹配到 (%s): %s' % (rel, old[:40].replace('\n', '\\n')))
                continue
            if n > 1:
                print('  !! 匹配 %d 次，只改第一处 (%s): %s' % (n, rel, old[:40]))
            src = src.replace(old, new, 1)
            hits += 1
        if hits:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(src)
            print('  == %s: 插入 %d 处触感调用' % (rel, hits))


main()
