import 'dart:io';

import 'package:flutter/material.dart';
// 别用 `as p`：本文件的 build 里有个局部变量 p（调色板），会把别名遮住。
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_database.dart';
import '../providers/countdown_provider.dart';
import '../providers/ledger_provider.dart';
import '../providers/todo_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../widgets/app_toast.dart';
import '../widgets/pressable.dart';

/// 「数据与备份」。
///
/// 这一页的存在理由很具体（v1.5.3）：有用户报"更新后账目不见了"。
/// 判断"到底丢没丢"其实只需要几件事：**库文件还在不在、多大、里面有多少行**。
/// 数据只是"读不出来"的时候，这一页能当场证明数据还在，
/// 并且能把库文件导出发给作者排查 —— 而不是让人一着急就卸载重装。
class DataHealthScreen extends StatefulWidget {
  const DataHealthScreen({super.key});

  @override
  State<DataHealthScreen> createState() => _DataHealthScreenState();
}

class _DataHealthScreenState extends State<DataHealthScreen> {
  DbHealth? _health;
  Map<String, int>? _counts;
  bool _busy = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    final db = AppDatabase.instance;
    final health = await db.health();
    Map<String, int>? counts;
    try {
      counts = await db.rowCounts();
    } catch (error) {
      db.note('统计行数失败：$error');
    }
    if (!mounted) return;
    setState(() {
      _health = health;
      _counts = counts;
      _busy = false;
    });
  }

  /// 把库文件本身导出去。
  ///
  /// 导**原始 .db** 而不是 JSON：它带着 `user_version` 和全部行，
  /// 是最忠实的一份证据，作者拿 Python 的 sqlite3 就能直接打开看。
  /// 注意别写进 `cacheDir/share_plus/` —— share_plus 自己会往那儿复制，
  /// 文件本来就在里面会直接抛 IOException。
  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    Haptics.impact();

    try {
      final health = _health ?? await AppDatabase.instance.health();
      if (!health.fileExists) {
        throw StateError('数据库文件还没生成');
      }
      final dir = Directory('${(await getTemporaryDirectory()).path}/ribei_share');
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final stamp =
          '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}';
      final target = File(path.join(dir.path, '日贝备份-$stamp.db'));
      await File(health.path).copy(target.path);

      final counts = _counts ?? <String, int>{};
      final summary = counts.entries.map((e) => '${e.key} ${e.value}').join('、');

      if (!mounted) return;
      setState(() => _exporting = false);

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(target.path, mimeType: 'application/octet-stream')],
          text: '日贝数据备份（库版本 v${health.version}，$summary）',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _exporting = false);
      AppToast.show(
        context,
        '导出失败：$error',
        icon: Icons.error_outline,
        tint: context.palette.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final health = _health;
    final errors = [
      context.watch<LedgerProvider>().loadError,
      context.watch<CountdownProvider>().loadError,
      context.watch<TodoProvider>().loadError,
    ].whereType<String>().toList();

    return Scaffold(
      appBar: AppBar(title: const Text('数据与备份')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          // ---------- 结论先行 ----------
          if (errors.isEmpty)
            _Banner(
              tint: p.jade,
              icon: Icons.check_circle_outline_rounded,
              title: '数据正常',
              body: '这次打开数据库没有报错。下面可以核对文件与行数。',
            )
          else
            _Banner(
              tint: p.danger,
              icon: Icons.warning_amber_rounded,
              title: '数据读取失败 —— 但数据本身通常还在',
              body: '先看下面的「库文件」和「行数」：文件在、行数不为 0，'
                  '就说明记录没丢，是读取环节出了问题，后续版本能修回来。\n'
                  '**在那之前：千万不要卸载重装。** 卸载会真的把数据删掉。',
            ),
          const SizedBox(height: 18),

          const _SectionLabel('库文件'),
          Card(
            child: Column(
              children: [
                _Row(label: '位置', value: health == null ? '读取中…' : 'App 私有目录'),
                _Row(
                  label: '文件名',
                  value: health == null ? '—' : path.basename(health.path),
                ),
                _Row(
                  label: '文件大小',
                  value: health?.sizeText ?? '—',
                  warn: health != null && !health.fileExists,
                ),
                _Row(
                  label: '库内版本',
                  value: health?.version == null
                      ? '—'
                      : 'v${health!.version}（当前 App 期望 v4）',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const _SectionLabel('记录条数（数据还在不在，看这里）'),
          Card(
            child: Column(
              children: [
                if (_counts == null)
                  const _Row(label: '统计', value: '读不出来')
                else
                  for (final entry in _counts!.entries)
                    _Row(
                      label: entry.key,
                      value: '${entry.value} 条',
                      warn: entry.value == 0,
                    ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '注意：「0 条」和「读不出来」是两回事 —— '
              '上面写「读不出来」才是异常；写「0 条」说明表是空的。',
              style: TextStyle(fontSize: 11.5, color: p.inkSoft, height: 1.7),
            ),
          ),
          const SizedBox(height: 18),

          if (health != null && health.backups.isNotEmpty) ...[
            const _SectionLabel('自动备份（迁移前留的）'),
            Card(
              child: Column(
                children: [
                  for (final name in health.backups)
                    _Row(label: '备份', value: name),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          if (health != null && health.warnings.isNotEmpty) ...[
            const _SectionLabel('这次启动记下的问题'),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final w in health.warnings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '· $w',
                          style: TextStyle(
                            fontSize: 12,
                            color: p.ink,
                            height: 1.6,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          Pressable(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _exporting ? null : _export,
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_alt, size: 19),
              label: Text(_exporting ? '正在导出…' : '导出备份（把那本账发给我）'),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '导出的是数据库文件本身（.db），里面是完整的账目、倒计时和待办。'
            '可以发到微信「文件传输助手」自己留一份，也可以发我排查问题。',
            style: TextStyle(fontSize: 11.5, color: p.inkFaint, height: 1.7),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _busy ? null : _refresh,
              child: Text(_busy ? '刷新中…' : '刷新'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 零件

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: context.palette.inkSoft,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.warn = false});

  final String label;
  final String value;

  /// 值得注意的行（文件不存在、行数为 0）标成橙色
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13.5, color: p.ink)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: warn ? p.warn : p.inkSoft,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.tint,
    required this.icon,
    required this.title,
    required this.body,
  });

  final Color tint;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: p.isDark ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withValues(alpha: 0.38)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: tint,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  // 这里刻意不写 markdown 的星号：Text 不会渲染它，会原样显示
                  body.replaceAll('**', ''),
                  style: TextStyle(fontSize: 12, color: p.ink, height: 1.7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
