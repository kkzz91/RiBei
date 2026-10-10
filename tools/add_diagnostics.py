"""给设置页加：触感强度三档 + 提醒自检面板。

纯字面替换，命中数会打印出来，便于核对。
"""
import io

PATH = r'E:\ribei\lib\screens\settings_screen.dart'

R1_OLD = """class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsOn = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final on = await NotificationService.instance.notificationsAllowed();
    if (mounted) setState(() => _notificationsOn = on);
  }
"""

R1_NEW = """class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsOn = true;
  ReminderDiagnostics? _diag;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final service = NotificationService.instance;
    final on = await service.notificationsAllowed();
    final diag = await service.diagnostics();
    if (!mounted) return;
    setState(() {
      _notificationsOn = on;
      _diag = diag;
    });
  }

  /// 手动重排：把数据库里的倒计时和待办重新写进系统闹钟。
  /// 换手机、系统清理过闹钟、或怀疑提醒丢了的时候用。
  Future<void> _reschedule() async {
    Haptics.impact();
    final countdowns = context.read<CountdownProvider>();
    final todos = context.read<TodoProvider>();
    setState(() => _busy = true);
    final scheduled = await NotificationService.instance.rescheduleAll(
      countdowns: countdowns.events,
      todos: todos.items,
    );
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已重新排定 \$scheduled 条提醒')),
    );
  }
"""

R2_OLD = """              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '打字、勾选时轻微震动。需系统「声音与触感 → 触感反馈」已开启',
                  style: TextStyle(fontSize: 12, color: p.inkSoft),
                ),
              ),
            ),
          ),
"""

R2_NEW = """              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '打字、勾选时震动。需系统「声音与触感 → 触感反馈」已开启',
                  style: TextStyle(fontSize: 12, color: p.inkSoft),
                ),
              ),
            ),
          ),
          if (settings.hapticsEnabled) ...[
            const SizedBox(height: 10),
            _HapticStrengthChooser(
              value: settings.hapticStrength,
              onChanged: (v) {
                // 先应用再震动，这样试的就是刚选的那一档
                context.read<SettingsProvider>().setHapticStrength(v);
                Haptics.tap();
              },
            ),
          ],
"""

R3_OLD = "          const _SectionLabel('数据'),"

R3_NEW = """          const _SectionLabel('提醒自检'),
          _DiagnosticsCard(
            diag: _diag,
            busy: _busy,
            onRefresh: _refresh,
            onReschedule: _reschedule,
          ),
          const SizedBox(height: 22),

          const _SectionLabel('数据'),"""

WIDGETS = """

// ---------------------------------------------------------------- 触感强度

class _HapticStrengthChooser extends StatelessWidget {
  const _HapticStrengthChooser({required this.value, required this.onChanged});

  final HapticStrength value;
  final ValueChanged<HapticStrength> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        const SizedBox(width: 2),
        Text('强度', style: TextStyle(fontSize: 13, color: p.inkSoft)),
        const SizedBox(width: 12),
        for (final s in HapticStrength.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == s ? p.jade : p.paper,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: value == s ? p.jade : p.line),
                ),
                child: Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: value == s
                        ? (p.isDark ? const Color(0xFF0B1F1A) : Colors.white)
                        : p.inkSoft,
                  ),
                ),
              ),
            ),
          ),
          if (s != HapticStrength.strong) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- 提醒自检

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({
    required this.diag,
    required this.busy,
    required this.onRefresh,
    required this.onReschedule,
  });

  final ReminderDiagnostics? diag;
  final bool busy;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onReschedule;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = diag;

    return Card(
      child: Column(
        children: [
          if (d == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('读取中…', style: TextStyle(color: p.inkSoft)),
            )
          else ...[
            _DiagRow(
              label: '通知权限',
              value: d.notificationsEnabled ? '已开启' : '未开启',
              ok: d.notificationsEnabled,
            ),
            _DiagRow(
              label: '精确闹钟',
              value: d.exactAlarmsAllowed ? '已允许' : '未允许（会晚几分钟）',
              ok: d.exactAlarmsAllowed,
              warnOnly: true,
            ),
            _DiagRow(
              label: '已排定提醒',
              value: '\${d.pendingCount} 条',
              ok: d.pendingCount > 0,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Text(
                    '通知渠道',
                    style: TextStyle(fontSize: 14, color: p.ink),
                  ),
                  const Spacer(),
                  Text(
                    '\${d.channels.length} 个',
                    style: TextStyle(fontSize: 13, color: p.inkSoft),
                  ),
                ],
              ),
            ),
            if (d.channels.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '一个都没有 —— 提醒必然弹不出来',
                    style: TextStyle(fontSize: 12.5, color: p.danger),
                  ),
                ),
              )
            else
              for (final c in d.channels)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                  child: Row(
                    children: [
                      Icon(
                        c.importance.index >= 4
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_outlined,
                        size: 15,
                        color: c.importance.index >= 4 ? p.jade : p.warn,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${c.id}  ·  ${c.name}',
                          style: TextStyle(fontSize: 12.5, color: p.inkSoft),
                        ),
                      ),
                      Text(
                        c.playSound ? '有声' : '无声',
                        style: TextStyle(fontSize: 12, color: p.inkFaint),
                      ),
                    ],
                  ),
                ),
          ],
          Divider(height: 1, indent: 16, endIndent: 16, color: p.line),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
            leading: Icon(Icons.refresh, size: 20, color: p.inkSoft),
            title: const Text(
              '重新排定全部提醒',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '提醒莫名不响时，点这里把闹钟按数据重建一遍',
                style: TextStyle(fontSize: 12, color: p.inkSoft),
              ),
            ),
            trailing: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right, size: 20),
            onTap: busy
                ? null
                : () async {
                    await onReschedule();
                    await onRefresh();
                  },
          ),
        ],
      ),
    );
  }
}

class _DiagRow extends StatelessWidget {
  const _DiagRow({
    required this.label,
    required this.value,
    required this.ok,
    this.warnOnly = false,
  });

  final String label;
  final String value;
  final bool ok;
  final bool warnOnly;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Color tint;
    if (ok) {
      tint = p.inkSoft;
    } else {
      tint = warnOnly ? p.warn : p.danger;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: p.ink)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}
"""


def main():
    with io.open(PATH, encoding='utf-8') as f:
        src = f.read()

    for name, old, new in (
        ('R1 状态字段+自检读取', R1_OLD, R1_NEW),
        ('R2 触感强度选择', R2_OLD, R2_NEW),
        ('R3 自检面板挂载', R3_OLD, R3_NEW),
    ):
        n = src.count(old)
        if n != 1:
            print('  !! %s 命中 %d 次，跳过' % (name, n))
            continue
        src = src.replace(old, new, 1)
        print('  == %s 完成' % name)

    # 追加两个新组件
    if '_HapticStrengthChooser' in src.split('\n')[-1:][0] or 'class _HapticStrengthChooser' in src:
        print('  -- 组件已存在，跳过追加')
    else:
        src = src.rstrip('\n') + '\n' + WIDGETS
        print('  == 追加 _HapticStrengthChooser / _DiagnosticsCard / _DiagRow')

    with io.open(PATH, 'w', encoding='utf-8') as f:
        f.write(src)
    print('  文件行数: %d' % len(src.split('\n')))


main()
