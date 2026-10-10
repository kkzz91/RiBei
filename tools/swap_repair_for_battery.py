"""设置页：删掉闯祸的「重建渠道」按钮，换成「允许后台运行」（电池优化豁免）。"""
import io

PATH = r'E:\ribei\lib\screens\settings_screen.dart'

R1_OLD = """  /// 换一对全新渠道 ID 重建通知渠道。
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

R1_NEW = """  /// 申请豁免电池优化。
  ///
  /// 国产 ROM 上"息屏/后台不提醒"，十有八九是电池优化把 App 冻结了、
  /// 把闹钟押后或直接丢掉。这是系统层开关，只能请用户授权。
  Future<void> _requestBatteryUnrestricted() async {
    Haptics.impact();
    final granted =
        await NotificationService.instance.requestBatteryUnrestricted();
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? '已允许后台运行'
              : '没拿到豁免。可到「应用信息 → 省电策略」手动选「无限制」',
        ),
      ),
    );
  }
"""

R2_OLD = """          Divider(height: 1, indent: 16, endIndent: 16, color: p.line),
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
"""

R2_NEW = """          Divider(height: 1, indent: 16, endIndent: 16, color: p.line),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
            leading: Icon(
              Icons.battery_saver_outlined,
              size: 20,
              color: p.danger,
            ),
            title: const Text(
              '允许后台运行',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '关掉电池优化。不关的话，息屏或挂后台时系统会把闹钟押后甚至丢掉',
                style: TextStyle(fontSize: 12, color: p.inkSoft),
              ),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: onRequestBattery,
          ),
"""

R3_OLD = """            _DiagRow(
              label: '已排定提醒',
              value: '${d.pendingCount} 条',
              ok: d.pendingCount > 0,
            ),"""

R3_NEW = """            _DiagRow(
              label: '后台运行',
              value: d.batteryUnrestricted ? '已豁免电池优化' : '受限，息屏可能不响',
              ok: d.batteryUnrestricted,
              warnOnly: true,
            ),
            _DiagRow(
              label: '已排定提醒',
              value: '${d.pendingCount} 条',
              ok: d.pendingCount > 0,
            ),"""

R4_OLD = """    required this.onRefresh,
    required this.onReschedule,
    required this.onRecreate,
  });

  final ReminderDiagnostics? diag;
  final bool busy;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onReschedule;
  final Future<void> Function() onRecreate;"""

R4_NEW = """    required this.onRefresh,
    required this.onReschedule,
    required this.onRequestBattery,
  });

  final ReminderDiagnostics? diag;
  final bool busy;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onReschedule;
  final Future<void> Function() onRequestBattery;"""

R5_OLD = """            onReschedule: _reschedule,
            onRecreate: _recreateChannels,
          ),"""

R5_NEW = """            onReschedule: _reschedule,
            onRequestBattery: _requestBatteryUnrestricted,
          ),"""


def main():
    with io.open(PATH, encoding='utf-8') as f:
        src = f.read()

    for name, old, new in (
        ('R1 换成申请电池豁免', R1_OLD, R1_NEW),
        ('R2 按钮文案换成后台运行', R2_OLD, R2_NEW),
        ('R3 自检加后台运行行', R3_OLD, R3_NEW),
        ('R4 卡片参数改名', R4_OLD, R4_NEW),
        ('R5 调用处改名', R5_OLD, R5_NEW),
    ):
        n = src.count(old)
        if n != 1:
            print('  !! %s 命中 %d 次，跳过' % (name, n))
            continue
        src = src.replace(old, new, 1)
        print('  == %s' % name)

    with io.open(PATH, 'w', encoding='utf-8') as f:
        f.write(src)


main()
