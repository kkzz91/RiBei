import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 数据库的健康状况，给设置页的「数据与备份」用。
class DbHealth {
  const DbHealth({
    required this.path,
    required this.fileExists,
    required this.fileSizeBytes,
    required this.version,
    required this.warnings,
    required this.backups,
  });

  final String path;
  final bool fileExists;
  final int fileSizeBytes;

  /// 库文件里的 user_version；读不出来就是 null
  final int? version;

  /// 上次打开时记下的问题（迁移告警、备份失败等）
  final List<String> warnings;

  /// 留着的备份文件名（最新的在前）
  final List<String> backups;

  String get sizeText {
    if (!fileExists) return '不存在';
    final kb = fileSizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(2)} MB';
  }
}

/// 本地 SQLite。数据全部存在手机上，不联网、不上传。
///
/// ## 迁移设计（v1.5.3 重写，起因：有用户报"更新后账目不见了"）
///
/// 旧写法是"按 oldVersion 判断该加哪些列"，而且建表/加列都不做存在性检查。
/// 这样只要有一条语句抛异常，就会把整个迁移事务回滚，
/// **结果是数据库打不开 → 界面上显示成"没有账目"（数据其实还在盘上）**。
/// 另外 `onDowngrade` 没写，sqflite 默认会抛异常，库比代码新时同样打不开。
///
/// 现在改成**对账式自愈迁移**，四条保证：
/// 1. **建表/建索引一律 `IF NOT EXISTS`** —— 兜住"库文件在、但 user_version 是 0"
///    这类会让 sqflite 误走 onCreate 的情况（那种情况下旧代码必然报"表已存在"）；
/// 2. **加列前先查 `PRAGMA table_info`，只在缺列时才 ALTER** ——
///    杜绝"duplicate column name"把迁移打断；
/// 3. **不依赖 oldVersion 决定加哪些列，而是每次对照目标结构补齐** ——
///    不管用户从哪个版本跳过来、或上次迁移只做了一半，跑一次就补齐，天生幂等；
/// 4. **每一步单独 try/catch，绝不让异常冒出 `openDatabase`**，
///    并且**迁移前先把原库文件复制一份**留底。
///
/// 核心原则：**宁可某个新列没加上（读取时有默认值兜底），也绝不能让整个库打不开。**
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'ribei.db';

  /// v1: transactions + countdown_events
  /// v2: 新增 todos
  /// v3: 倒计时增加 农历/重复/提前天数；待办增加 优先级/重复/宽限
  /// v4: 账目增加 支付方式
  /// v5: 新增 milestones（纪念日/正计时）
  /// v6: 倒计时增加 背景主题（和纪念日共用同一套主题）
  /// v7: 倒计时和纪念日各增加 置顶(pinned) / 数字字体(digit_font)
  ///
  /// v1.5.3 重写了迁移逻辑（对账式自愈），v1.5.x 没改结构。
  /// v1.6.0 加了 milestones 表 —— 因为 _createAll 全程 IF NOT EXISTS，
  /// 老库升级时会**自动补建这张表**，不需要任何 ALTER。
  /// v6 / v7 都是"加列"，所以必须同时改两处：建表语句 + 对应的列定义表
  /// （只改一处的话，全新安装没事、老库升上来会缺这一列 —— 有脚本守着）。
  static const _dbVersion = 7;

  /// 备份文件名前缀（纯 ASCII：避免任何编码问题）
  static const _backupPrefix = 'ribei.backup';
  static const _backupKeep = 3;

  Database? _db;

  final List<String> _warnings = <String>[];

  List<String> get warnings => List<String>.unmodifiable(_warnings);

  /// 别处（比如 Provider 读取失败）发现问题时记一笔，供诊断页显示
  void note(String message) {
    if (_warnings.contains(message)) return;
    _warnings.add(message);
  }

  Future<Database> get database async => _db ??= await _open();

  // ---------------------------------------------------------------- 打开

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);

    await _prepareForMigration(path);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        // ⚠️ onCreate **不只是"全新安装"时才会被调用**：
        // sqflite 只要发现库文件的 user_version 是 0 就走这里，而
        // **文件其实已经存在、表和数据都还在**（比如备份恢复回来了一个半成品、
        // 或者上一版迁移失败回滚留下这个状态）时也会走。
        // 所以这里必须和 onUpgrade 一样"建表 + 补齐列"，
        // 只建表的话旧结构会缺列 —— 数据看得见，但新记账写不进去。
        await _step('建表', () => _reconcileSchema(db));
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _step('迁移到 v$newVersion', () => _reconcileSchema(db));
      },
      // sqflite 默认实现在降级时**抛异常**，那会让数据库彻底打不开。
      // 库比这个安装包新（用户装回了旧版、或换机时恢复了新库）时不该炸，
      // 记一条告警、照常打开即可 —— 多出来的列会被忽略。
      onDowngrade: (db, oldVersion, newVersion) async {
        _warnings.add('数据库版本(v$oldVersion)比这个安装包期望的(v$newVersion)更新，已按只读兼容方式继续');
      },
    );
  }

  /// 迁移前留一份原库文件。
  ///
  /// 只在"确实要迁移"时才复制，所以正常启动没有额外开销。
  /// 复制前先做一次 WAL checkpoint，否则可能只拷到主文件、
  /// 漏掉还在 `-wal` 里的最新数据。
  Future<void> _prepareForMigration(String path) async {
    final file = File(path);
    if (!file.existsSync()) return;

    int? current;
    try {
      // 不带 version 打开 → 不会触发 onCreate/onUpgrade
      final probe = await openDatabase(path);
      await probe.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      current = await probe.getVersion();
      await probe.close();
    } catch (error) {
      _warnings.add('打开旧库读版本失败：$error');
      // 读不出来更要留底
    }

    if (current != null && current >= _dbVersion) return;

    try {
      final from = current ?? 0;
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '')
          .replaceAll('-', '')
          .split('.')
          .first;
      final backup = File(p.join(p.dirname(path), '$_backupPrefix-v$from-$stamp.db'));
      await file.copy(backup.path);
      _warnings.add('迁移前已备份：${p.basename(backup.path)}（原版本 v$from）');
      await _pruneBackups(p.dirname(path));
    } catch (error) {
      _warnings.add('迁移前备份失败：$error');
    }
  }

  /// 只留最近的几个备份，别把手机塞满
  Future<void> _pruneBackups(String dir) async {
    try {
      final files = Directory(dir)
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).startsWith(_backupPrefix))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final old in files.skip(_backupKeep)) {
        try {
          old.deleteSync();
        } catch (_) {
          // 删不掉就算了，不影响使用
        }
      }
    } catch (_) {
      // 列目录失败不影响使用
    }
  }

  // ---------------------------------------------------------------- 迁移

  /// 跑一步迁移；失败只记录、不抛出。
  Future<void> _step(String label, Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      _warnings.add('$label 失败：$error');
    }
  }

  /// 把表结构补齐到当前目标。
  ///
  /// 注意这里**不看 oldVersion 决定加哪些列** —— 一律"缺什么补什么"。
  /// 这样从任意旧版本跳过来、或者上次迁移只做了一半，跑一次都能补齐。
  Future<void> _reconcileSchema(Database db) async {
    await _createAll(db);
    // 倒计时的列分两次加过（v3 农历/重复/提前天数、v6 背景主题），
    // 但这里**不按版本分别处理** —— 一律"对照目标结构缺什么补什么"，
    // 所以它们合在一张表里，跑一次就补齐（幂等，见类顶部的四条保证）。
    await _addMissingColumns(db, 'countdown_events', _countdownAddedColumns);
    await _addMissingColumns(db, 'milestones', _milestoneAddedColumns);
    await _addMissingColumns(db, 'todos', _todoV3Columns);
    await _addMissingColumns(db, 'transactions', _transactionV4Columns);
  }

  /// 目标结构：三张表 + 索引。全部 `IF NOT EXISTS`，可以反复调用。
  Future<void> _createAll(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        type INTEGER NOT NULL,
        category TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        date INTEGER NOT NULL,
        payment_method INTEGER NOT NULL DEFAULT -1,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS countdown_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        target_date INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        remind_enabled INTEGER NOT NULL DEFAULT 1,
        remind_hour INTEGER NOT NULL DEFAULT 9,
        remind_minute INTEGER NOT NULL DEFAULT 0,
        calendar INTEGER NOT NULL DEFAULT 0,
        lunar_month INTEGER NOT NULL DEFAULT 1,
        lunar_day INTEGER NOT NULL DEFAULT 1,
        repeat_rule INTEGER NOT NULL DEFAULT 0,
        lead_days INTEGER NOT NULL DEFAULT 3,
        theme INTEGER NOT NULL DEFAULT 0,
        pinned INTEGER NOT NULL DEFAULT 0,
        digit_font INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_countdown_target ON countdown_events(target_date)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS todos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        due_at INTEGER NOT NULL,
        remind_enabled INTEGER NOT NULL DEFAULT 1,
        done INTEGER NOT NULL DEFAULT 0,
        completed_at INTEGER,
        priority INTEGER NOT NULL DEFAULT 1,
        repeat_rule INTEGER NOT NULL DEFAULT 0,
        grace_minutes INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_todos_due ON todos(due_at)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS milestones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        start_date INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        theme INTEGER NOT NULL DEFAULT 0,
        pinned INTEGER NOT NULL DEFAULT 0,
        digit_font INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_milestones_start ON milestones(start_date)',
    );
  }

  /// 只在列真的缺失时才加 —— 这是"迁移不会被打断"的关键。
  Future<void> _addMissingColumns(
    Database db,
    String table,
    Map<String, String> columns,
  ) async {
    final existing = await _columnsOf(db, table);
    for (final entry in columns.entries) {
      if (existing.contains(entry.key)) continue;
      await db.execute(
        'ALTER TABLE $table ADD COLUMN ${entry.key} ${entry.value}',
      );
    }
  }

  Future<Set<String>> _columnsOf(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return <String>{
      for (final row in rows)
        if (row['name'] is String) row['name']! as String,
    };
  }

  // 倒计时表"后加的列"：v3 的农历/重复/提前天数 + v6 的背景主题。
  // 加新列时**这里和 _createAll 的建表语句都要改**（tools/check_migration_v4.py
  // 的第 0 节会双向核对，只改一处会直接报错）。
  static const _countdownAddedColumns = <String, String>{
    'calendar': 'INTEGER NOT NULL DEFAULT 0',
    'lunar_month': 'INTEGER NOT NULL DEFAULT 1',
    'lunar_day': 'INTEGER NOT NULL DEFAULT 1',
    'repeat_rule': 'INTEGER NOT NULL DEFAULT 0',
    'lead_days': 'INTEGER NOT NULL DEFAULT 3',
    'theme': 'INTEGER NOT NULL DEFAULT 0',
    'pinned': 'INTEGER NOT NULL DEFAULT 0',
    'digit_font': 'INTEGER NOT NULL DEFAULT 0',
  };

  // 纪念日表"后加的列"：v7 的置顶 / 数字字体（v5 建表时还没有）。
  static const _milestoneAddedColumns = <String, String>{
    'pinned': 'INTEGER NOT NULL DEFAULT 0',
    'digit_font': 'INTEGER NOT NULL DEFAULT 0',
  };

  // v3：待办的优先级 / 重复 / 宽限
  static const _todoV3Columns = <String, String>{
    'priority': 'INTEGER NOT NULL DEFAULT 1',
    'repeat_rule': 'INTEGER NOT NULL DEFAULT 0',
    'grace_minutes': 'INTEGER NOT NULL DEFAULT 0',
  };

  /// v4：账目的支付方式。
  ///
  /// 默认值给 -1（未记录）而不是"微信"：这个字段出现之前的账，
  /// 当时根本没有支付方式这个概念，不能替它们瞎认一个。
  static const _transactionV4Columns = <String, String>{
    'payment_method': 'INTEGER NOT NULL DEFAULT -1',
  };

  // ---------------------------------------------------------------- 诊断

  /// 给设置页看的：库文件在哪、多大、什么版本、有没有走过迁移、留着哪些备份。
  ///
  /// 用户报"数据不见了"时，先让他看这里 ——
  /// **文件还在、行数还在**，就说明数据没丢，是别的地方读不出来。
  Future<DbHealth> health() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    final file = File(path);

    var version = _dbVersion;
    if (file.existsSync()) {
      try {
        final probe = await openDatabase(path, readOnly: true);
        version = await probe.getVersion();
        await probe.close();
      } catch (error) {
        _warnings.add('读取库版本失败：$error');
      }
    }

    var backups = <String>[];
    try {
      backups = Directory(dir)
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .where((name) => name.startsWith(_backupPrefix))
          .toList()
        ..sort((a, b) => b.compareTo(a));
    } catch (_) {
      // 列目录失败不影响
    }

    return DbHealth(
      path: path,
      fileExists: file.existsSync(),
      fileSizeBytes: file.existsSync() ? file.lengthSync() : 0,
      version: version,
      warnings: warnings,
      backups: backups,
    );
  }

  /// 三张表各有多少行。用来确认"数据到底还在不在"。
  Future<Map<String, int>> rowCounts() async {
    final db = await database;
    Future<int> count(String table) async {
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
      final value = rows.first['c'];
      return value is int ? value : 0;
    }

    return <String, int>{
      '账目': await count('transactions'),
      '倒计时': await count('countdown_events'),
      '待办': await count('todos'),
    };
  }
}
