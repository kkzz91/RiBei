# -*- coding: utf-8 -*-
"""离线验证「日贝」的数据库迁移。

本机没有真机，sqflite 跑不起来；但迁移的风险全在 **SQL 本身**：
ALTER TABLE 加列能不能成功、老数据会不会掉。这两件事用 Python 自带的
sqlite3 就能如实验证。

做法（关键：不手抄 SQL）：
  1. 从 lib/data/app_database.dart 里**抠出真实的 CREATE 语句和列定义表**；
  2. 用「当前建表语句 - 后加的列」反推出历史版本的表结构（v1 / v2 / v3）；
  3. 按新版 _reconcileSchema 的顺序升级，每步后检查数据完整性；
  4. **再单独验证几条"以前会炸、现在不会炸"的路径** —— 这几条才是
     "更新后账目不见了"的可能成因。

用法：python tools/check_migration_v4.py
"""

import io
import re
import sqlite3
import sys

DART = 'E:/ribei/lib/data/app_database.dart'

# Dart 里那些"后加的列"是分开命名的，这里显式对上表名。
# 新增迁移时**必须同步加进来** —— 漏了的话下面的校验会直接报错，不会静默放过。
COLUMN_MAPS = {
    'countdown_events': '_countdownV3Columns',
    'todos': '_todoV3Columns',
    'transactions': '_transactionV4Columns',
}

# 各表"最早的版本"里就有的列（v1 的 transactions/countdown_events，v2 的 todos，v5 的 milestones）。
#
# 这条基线是用来做**覆盖性检查**的，防一个具体的坑：
# 以后加 v5 列时，如果只往 _createAll 的建表语句里加了列、**忘了往补列表里加**，
# 那么全新安装没问题、老库升级上来就会缺这一列 ——
# 表现是"数据看得见，但新记的账写不进去"，而且很难发现。
# 有了这条检查，漏加会直接报错，不会带着坑发版。
BASELINE = {
    'transactions': [
        'id', 'amount', 'type', 'category', 'note', 'date', 'created_at',
    ],
    'countdown_events': [
        'id', 'title', 'target_date', 'note', 'remind_enabled',
        'remind_hour', 'remind_minute', 'created_at',
    ],
    'todos': [
        'id', 'title', 'note', 'due_at', 'remind_enabled', 'done',
        'completed_at', 'created_at',
    ],
    # v5 新表：整张表都是"基线"，没有后加的列
    'milestones': [
        'id', 'title', 'start_date', 'note', 'theme', 'created_at',
    ],
}

failures = []


def check(label, ok, detail=''):
    mark = 'OK  ' if ok else 'FAIL'
    print('  [%s] %s%s' % (mark, label, ('  -> ' + detail) if detail else ''))
    if not ok:
        failures.append(label)


# ------------------------------------------------------------------ 抠源码

def read_dart():
    return io.open(DART, encoding='utf-8').read()


def extract(src):
    """抠出建表语句 + 索引语句 + 三张列定义表。"""
    tables = {}
    for m in re.finditer(r"'''(.*?)'''", src, re.S):
        block = m.group(1).strip()
        if block.upper().startswith('CREATE TABLE'):
            name = re.search(r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(\w+)',
                             block, re.I).group(1)
            # ⚠️ 必须**原样保留换行**：后面的 drop_columns 是按行删列的。
            # 早先这里做了 ' '.join(block.split()) 把换行压平，
            # 结果一列都删不掉 —— 历史表结构其实是当前结构，
            # 于是"老数据迁移"那几项测试变成了假通过。
            tables[name] = block

    indexes = []
    for m in re.finditer(r"'(CREATE INDEX[^']*)'", src):
        if m.group(1) not in indexes:
            indexes.append(m.group(1))

    columns = {}
    for m in re.finditer(r"static const (\w+) = <String, String>\{(.*?)\};",
                         src, re.S):
        pairs = re.findall(r"'([^']+)'\s*:\s*'([^']*)'", m.group(2))
        columns[m.group(1)] = dict(pairs)

    return tables, indexes, columns


def statements_for(columns, table):
    """把列定义表翻译成 ALTER 语句（和 Dart 里拼出来的完全一致）。"""
    return ['ALTER TABLE %s ADD COLUMN %s %s' % (table, k, v)
            for k, v in columns.items()]


# ------------------------------------------------------------------ 工具

def table_columns(db, table):
    return [r[1] for r in db.execute('PRAGMA table_info(%s)' % table)]


def create_columns(create_sql):
    """从建表语句里解析出列名（跳过主键/约束那些行）"""
    body = create_sql[create_sql.index('(') + 1:create_sql.rindex(')')]
    out = []
    for line in body.split('\n'):
        s = line.strip().rstrip(',').strip()
        if not s:
            continue
        head = s.split(' ')[0].strip('"`[]')
        if head.upper() in ('PRIMARY', 'UNIQUE', 'CHECK', 'FOREIGN', 'CONSTRAINT'):
            continue
        out.append(head)
    return out


def drop_columns(create_sql, cols):
    """从建表语句里删掉指定的列，得到历史版本的表结构。"""
    keep = []
    for line in create_sql.split('\n'):
        stripped = line.strip().rstrip(',')
        name = stripped.split(' ')[0].lower() if stripped else ''
        if name in [c.lower() for c in cols]:
            continue
        keep.append(line.rstrip())
    text = '\n'.join(keep).rstrip().rstrip(',')
    if not text.endswith(')'):
        text += '\n)'
    return text


def new_migrate(db, tables, indexes, columns):
    """复刻新版 _reconcileSchema：建表 IF NOT EXISTS + 只补缺的列。

    顺序必须是「先建表 → 再建索引 → 最后补列」：
    索引依赖表，表还没建就建索引会报 no such table。
    """
    for name in sorted(tables):
        db.executescript(tables[name])
    for stmt in indexes:
        db.execute(stmt)
    for table in sorted(tables):
        existing = table_columns(db, table)
        for key, typ in columns.get(table, {}).items():
            if key in existing:
                continue
            db.execute('ALTER TABLE %s ADD COLUMN %s %s' % (table, key, typ))


def has_table(db, name):
    return db.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)
    ).fetchone() is not None


def seed(db, only=None):
    """塞一批"老用户"的数据。

    只往**当前已经存在**的表里塞 —— 这样这个函数在 v1 / v2 / v3 各个阶段都能直接用。
    [only] 限定只塞某几张表（避免重复调用时把账目塞两遍）。
    """
    def want(name):
        return has_table(db, name) and (only is None or name in only)

    if want('transactions'):
        db.executemany(
            'INSERT INTO transactions (amount, type, category, note, date, created_at) '
            'VALUES (?,?,?,?,?,?)',
            [(12.5, 0, '餐饮', '早饭', 1770000000000, 1770000000000),
             (3000.0, 1, '生活费', '', 1770100000000, 1770100000000),
             (7.0, 0, '交通', '公交', 1770200000000, 1770200000000)])
    if want('countdown_events'):
        db.execute(
            'INSERT INTO countdown_events (title, target_date, note, remind_enabled, '
            'remind_hour, remind_minute, created_at) VALUES (?,?,?,?,?,?,?)',
            ('期末考试', 1780000000000, '带学生证', 1, 9, 0, 1770000000000))
    if want('todos'):
        db.execute(
            'INSERT INTO todos (title, note, due_at, remind_enabled, done, '
            'completed_at, created_at) VALUES (?,?,?,?,?,?,?)',
            ('交作业', '', 1780000000000, 1, 0, None, 1770000000000))


def counts(db):
    return tuple(
        db.execute('SELECT COUNT(*) FROM %s' % t).fetchone()[0]
        for t in ('transactions', 'countdown_events', 'todos'))


def main():
    src = read_dart()
    tables, indexes, raw_columns = extract(src)

    if len(tables) != 4:
        print('!! 只抠到 %d 张表，预期 4 张（加新表要同步改这里）' % len(tables))
        return 1

    # Dart 变量名 -> 表名。
    # 全新表（比如 v5 的 milestones）没有"后加的列"，所以没有列定义表，
    # columns 里就是空 dict —— 建表 IF NOT EXISTS 会自动建，不需要 ALTER。
    columns = {}
    for table in tables:
        var = COLUMN_MAPS.get(table)
        if var is not None and var not in raw_columns:
            print('!! 源码里找不到列定义表 %s（是不是改名了？）' % var)
            return 1
        columns[table] = raw_columns.get(var, {}) if var else {}

    for name, sql in tables.items():
        if 'IF NOT EXISTS' not in sql.upper():
            print('!! %s 的建表语句没有 IF NOT EXISTS' % name)
            return 1

    print('== 从源文件抠到的内容 ==')
    print('  建表：%s（都带 IF NOT EXISTS）' % ', '.join(sorted(tables)))
    print('  索引：%d 条' % len(indexes))
    for t in sorted(columns):
        print('  列定义 %s：%d 列' % (t, len(columns[t])))
    print()

    # ---------------- 0. 覆盖性检查（防"以后加列时漏补"）----------------
    print('== 0. 建表语句里的每一列，都要"要么在基线里、要么在补列表里" ==')
    for table in sorted(tables):
        created = create_columns(tables[table])
        covered = set(BASELINE.get(table, [])) | set(columns.get(table, {}))
        missing = [c for c in created if c not in covered]
        check(
            '%s 的 %d 列都有出处' % (table, len(created)),
            not missing,
            ('这些列既不在基线、也不在补列表里（老库升级会缺列！）：%s' % missing)
            if missing else '',
        )
        # 反过来也要查：补列表里写了、建表语句里却没有 —— 那是写错了
        ghost = [c for c in columns.get(table, {}) if c not in created]
        check(
            '%s 的补列表没有多余项' % table,
            not ghost,
            ('补列表里有、建表语句里没有（写错了？）：%s' % ghost) if ghost else '',
        )
    print()

    # 历史版本的表结构 = 当前建表语句去掉后加的列
    v1_transactions = drop_columns(tables['transactions'], columns['transactions'])
    v1_countdowns = drop_columns(tables['countdown_events'], columns['countdown_events'])
    v2_todos = drop_columns(tables['todos'], columns['todos'])

    # ---------------- 1. 老数据升上来一条不少 ----------------
    print('== 1. 老数据升到 v4 之后一条不少 ==')
    db = sqlite3.connect(':memory:')
    db.executescript(v1_transactions)
    db.executescript(v1_countdowns)
    seed(db)
    # v1 -> v2：补上待办表（模拟历史版本自己走过的这一步），只补塞待办
    db.executescript(v2_todos)
    seed(db, only={'todos'})
    before = counts(db)
    new_migrate(db, tables, indexes, columns)
    check('账目/倒计时/待办行数不变', counts(db) == before, str(before))
    check('账目金额与备注一字不改',
          db.execute('SELECT amount, category, note FROM transactions ORDER BY id')
            .fetchall() == [(12.5, '餐饮', '早饭'), (3000.0, '生活费', ''),
                            (7.0, '交通', '公交')])
    check('老账目一律「未记录」(-1)',
          [r[0] for r in db.execute('SELECT payment_method FROM transactions')]
          == [-1, -1, -1])
    check('老倒计时拿到 v3 默认值 (0,1,1,0,3)',
          db.execute('SELECT calendar, lunar_month, lunar_day, repeat_rule, lead_days '
                     'FROM countdown_events').fetchone() == (0, 1, 1, 0, 3))
    check('老待办拿到 v3 默认值 (1,0,0)',
          db.execute('SELECT priority, repeat_rule, grace_minutes FROM todos')
            .fetchone() == (1, 0, 0))
    print()

    # ---------------- 2. 以前会炸的路径 ----------------
    print('== 2. 以前会炸、现在不会炸的路径 ==')

    # 2a. 建表语句没有 IF NOT EXISTS → 表已存在时直接报错
    trap = sqlite3.connect(':memory:')
    trap.executescript(v1_transactions)
    seed(trap)
    exploded = False
    try:
        # 旧代码 onCreate 的样子
        trap.execute(tables['transactions'].replace('IF NOT EXISTS ', ''))
    except sqlite3.OperationalError as e:
        exploded = 'already exists' in str(e)
    check('旧写法：库在但 user_version=0 时会被 onCreate 撞死', exploded,
          '这就是"整个库打不开"的一种成因')

    # 2b. ALTER 加已存在的列 → duplicate column
    trap2 = sqlite3.connect(':memory:')
    trap2.executescript(v1_transactions)
    trap2.executescript(v1_countdowns)
    seed(trap2)
    new_migrate(trap2, tables, indexes, columns)   # 已经升到最新
    dup = False
    try:
        trap2.execute('ALTER TABLE transactions ADD COLUMN payment_method '
                      'INTEGER NOT NULL DEFAULT -1')
    except sqlite3.OperationalError as e:
        dup = 'duplicate column' in str(e)
    check('旧写法：重复加列会报 duplicate column', dup,
          '这在事务里一抛就回滚 → 库打不开 → 界面显示成"没有账目"')

    # 2c. 新版：同样的两种情况都不报错，且数据完好
    healed = sqlite3.connect(':memory:')
    healed.executescript(v1_transactions)
    healed.executescript(v1_countdowns)
    seed(healed)
    healed.executescript(v2_todos)
    seed(healed, only={'todos'})
    before_heal = counts(healed)
    try:
        new_migrate(healed, tables, indexes, columns)
        new_migrate(healed, tables, indexes, columns)   # 再来一遍，验幂等
        new_migrate(healed, tables, indexes, columns)
        ok = True
        err = ''
    except Exception as e:      # noqa: BLE001 - 这里就是要抓所有异常
        ok = False
        err = str(e)
    check('新写法：连着跑 3 次都不报错（幂等）', ok, err)
    check('新写法：跑完数据仍在', counts(healed) == before_heal, str(before_heal))
    print()

    # ---------------- 3. 卡住的库能自愈（用户数据回来的证明）----------------
    print('== 3. 上次迁移卡在半路的库，装新版后能自愈 ==')
    stuck = sqlite3.connect(':memory:')
    stuck.executescript(v1_transactions)
    stuck.executescript(v1_countdowns)
    stuck.executescript(v2_todos)          # 停在 v2：有 todos，但缺 v3/v4 的列
    seed(stuck)
    stuck.execute('PRAGMA user_version = 2')
    before_stuck = counts(stuck)
    missing_before = 'payment_method' not in table_columns(stuck, 'transactions')
    new_migrate(stuck, tables, indexes, columns)
    check('卡在 v2 的库确实缺 v4 的列', missing_before)
    check('自愈后列补齐了',
          'payment_method' in table_columns(stuck, 'transactions'))
    check('自愈过程一条记录都没少', counts(stuck) == before_stuck, str(before_stuck))
    check('自愈后账目内容照旧',
          stuck.execute('SELECT COUNT(*), SUM(amount) FROM transactions').fetchone()
          == (3, 3019.5))
    print()

    # ---------------- 4. 新库与升级后的列名集合一致 ----------------
    print('== 4. 全新安装与老库升级后的列名集合一致 ==')
    fresh = sqlite3.connect(':memory:')
    for name in sorted(tables):
        fresh.executescript(tables[name])
    new_migrate(fresh, tables, indexes, columns)
    for name in sorted(tables):
        a = set(table_columns(fresh, name))
        b = set(table_columns(db, name))
        check('%s 列名集合一致' % name, a == b,
              '新库多 %s / 老库多 %s' % (sorted(a - b), sorted(b - a)))
    print()

    # ---------------- 5. 库文件在、但 user_version 是 0（本次事故最可能的形态）----
    print('== 5. 库文件在、但 user_version=0 且表里已有数据 ==')
    print('   （用户报的"直接装上了但账本是空的"最可能是这种）')
    orphan = sqlite3.connect(':memory:')
    orphan.executescript(v1_transactions)
    orphan.executescript(v1_countdowns)
    seed(orphan)
    orphan.executescript(v2_todos)
    seed(orphan, only={'todos'})
    orphan.execute('PRAGMA user_version = 0')       # ← 关键：版本号丢了
    before_orphan = counts(orphan)
    check('这个库确实报告版本 0 但表在、有数据',
          orphan.execute('PRAGMA user_version').fetchone()[0] == 0
          and before_orphan == (3, 1, 1), str(before_orphan))

    # 旧代码在这条路上走 onCreate，用的是不带 IF NOT EXISTS 的 CREATE TABLE
    broke = False
    try:
        orphan.execute(tables['transactions'].replace('IF NOT EXISTS ', ''))
    except sqlite3.OperationalError as e:
        broke = 'already exists' in str(e)
    check('旧写法：这种库会被 onCreate 撞死（于是界面永远空白）', broke)

    # 新写法：onCreate 也走 _reconcileSchema（建表 IF NOT EXISTS + 补齐列）
    new_migrate(orphan, tables, indexes, columns)
    check('新写法：数据一条不少', counts(orphan) == before_orphan,
          str(before_orphan))
    check('新写法：缺的列也补齐了（否则新记账写不进去）',
          'payment_method' in table_columns(orphan, 'transactions'))
    check('新写法：账目内容照旧',
          orphan.execute('SELECT COUNT(*), SUM(amount) FROM transactions')
            .fetchone() == (3, 3019.5))
    # 补完之后应该能正常写入
    orphan.execute(
        'INSERT INTO transactions (amount, type, category, note, date, '
        'payment_method, created_at) VALUES (?,?,?,?,?,?,?)',
        (15.0, 0, '餐饮', '午饭', 1790000000000, 1, 1790000000000))
    check('新写法：修好后能继续记账', counts(orphan)[0] == 4)
    print()

    if failures:
        print('结果：%d 项未通过 -> %s' % (len(failures), failures))
        return 1
    print('结果：全部通过')
    print('  · 老数据完好、新列默认值正确、新库与老库列名一致')
    print('  · 旧写法会炸的情况（表已存在 / 重复加列）已确认会炸')
    print('  · 新写法幂等、能把"卡住的库"补齐并保住数据')
    print('  · user_version=0 但有数据的老库：数据保留、列补齐、能继续记账')
    return 0


if __name__ == '__main__':
    sys.exit(main())
