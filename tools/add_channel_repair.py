"""设置页：接上 RescheduleReport、加重建渠道按钮、自检显示重要性。"""
import io

PATH = r'E:\ribei\lib\screens\settings_screen.dart'

R1_OLD = """    setState(() => _busy = true);
    final scheduled = await NotificationService.instance.rescheduleAll(
      countdowns: countdowns.events,
      todos: todos.items,
    );
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已重新排定 $scheduled 条提醒')),
    );
  }
"""

R1_NEW = """    setState(() => _busy = true);
    final report = await NotificationService.instance.rescheduleAll(
      countdowns: countdowns.events,
      todos: todos.items,
    );
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(report.summary)),
    );
  }

  /// 换一对全新渠道 ID 重建通知渠道。
  ///
  /// 系统把这个 App 的通知改成"无声 / 不震动"之后，App 自己是改不回来的
  /// —— Android 只认用户的修改，不认 App 的覆盖。换新 ID 等于拿一套干净默认值。
  Future<void> _recreateChannels() async {
    Haptics.impact();
    final countdowns = context.read<CountdownProvider>();
    final todos = context.read<TodoProvider>();
    setState(() => _busy = true);
    await NotificationService.instance.recreateChannels();
    final report = await NotificationService.instance.rescheduleAll(
      countdowns: countdowns.events,
      todos: todos.items,
    );
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已重建通知渠道 · ${report.summary}')),
    );
  }
"""

R2_OLD = """          _DiagnosticsCard(
            diag: _diag,
            busy: _busy,
            onRefresh: _refresh,
            onReschedule: _reschedule,
          ),"""

R2_NEW = """          _DiagnosticsCard(
            diag: _diag,
            busy: _busy,
            onRefresh: _refresh,
            onReschedule: _reschedule,
            onRecreate: _recreateChannels,
          ),"""

R3_OLD = """  const _DiagnosticsCard({
    required this.diag,
    required this.busy,
    required this.onRefresh,
    required this.onReschedule,
  });

  final ReminderDiagnostics? diag;
  final bool busy;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onReschedule;"""

R3_NEW = """  const _DiagnosticsCard({
    required this.diag,
    required this.busy,
    required this.onRefresh,
    required this.onReschedule,
    required this.onRecreate,
  });

  final ReminderDiagnostics? diag;
  final bool busy;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onReschedule;
  final Future<void> Function() onRecreate;"""

R4_OLD = """                      Expanded(
                        child: Text(
                          '${c.id}  ·  ${c.name}',
                          style: TextStyle(fontSize: 12.5, color: p.inkSoft),
                        ),
                      ),
                      Text(
                        c.playSound ? '有声' : '无声',
                        style: TextStyle(fontSize: 12, color: p.inkFaint),
                      ),"""

R4_NEW = """                      Expanded(
                        child: Text(
                          '${c.name} · 重要性 ${_importanceLabel(c.importance)}',
                          style: TextStyle(fontSize: 12.5, color: p.inkSoft),
                        ),
                      ),
                      Text(
                        c.playSound ? '有声' : '无声',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.playSound ? p.inkFaint : p.danger,
                        ),
                      ),"""

R5_OLD = """          Divider(height: 1, indent: 16, endIndent: 16, color: p.line),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
            leading: Icon(Icons.refresh, size: 20, color: p.inkSoft),"""

R5_NEW = """          Divider(height: 1, indent: 16, endIndent: 16, color: p.line),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
            leading: Icon(
              Icons.hearing_outlined,
              size: 20,
              color: p.danger,
            ),
            title: const Text(
              '修复「没声音 / 没震动」',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '换一对全新的通知渠道 ID。系统一旦记住某个渠道被静音，App 改不回来',
                style: TextStyle(fontSize: 12, color: p.inkSoft),
              ),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: busy
                ? null
                : () async {
                    await onRecreate();
                    await onRefresh();
                  },
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: p.line),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
            leading: Icon(Icons.refresh, size: 20, color: p.inkSoft),"""

HELPER = """

/// Importance 枚举取中文名（不写 exhaustive switch，避免枚举增项后编译失败）
String _importanceLabel(Importance i) {
  switch (i.name) {
    case 'max':
    case 'high':
      return '高';
    case 'defaultImportance':
      return '默认';
    case 'low':
      return '低';
    case 'min':
      return '最低';
    case 'none':
      return '已关闭';
    default:
      return i.name;
  }
}
"""


def main():
    with io.open(PATH, encoding='utf-8') as f:
        src = f.read()

    for name, old, new in (
        ('R1 重排+重建渠道方法', R1_OLD, R1_NEW),
        ('R2 传入 onRecreate', R2_OLD, R2_NEW),
        ('R3 组件构造参数', R3_OLD, R3_NEW),
        ('R4 渠道行显示重要性', R4_OLD, R4_NEW),
        ('R5 重建渠道按钮', R5_OLD, R5_NEW),
    ):
        n = src.count(old)
        if n != 1:
            print('  !! %s 命中 %d 次，跳过' % (name, n))
            continue
        src = src.replace(old, new, 1)
        print('  == %s' % name)

    if '_importanceLabel(Importance i)' not in src:
        src = src.rstrip('\n') + '\n' + HELPER
        print('  == 追加 _importanceLabel 辅助函数')

    with io.open(PATH, 'w', encoding='utf-8') as f:
        f.write(src)
    print('  行数: %d' % len(src.split('\n')))


main()
