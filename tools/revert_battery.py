"""退回 permission_handler 相关的代码，改成文字指引。

该插件要求 Android SDK 37（未正式发布），AGP 9 无法解析，
为它去改 SDK 元数据不划算 —— 电池优化本来就是系统层的一次性设置。
"""
import io

SVC = r'E:\ribei\lib\services\notification_service.dart'
SET = r'E:\ribei\lib\screens\settings_screen.dart'


SVC_RULES = [
    (
        "import 'package:permission_handler/permission_handler.dart' as ph;\n",
        "",
    ),
    (
        """  final bool exactAlarmsAllowed;

  /// 是否已豁免电池优化。不豁免的话，息屏/后台时系统会冻结 App、
  /// 推迟甚至丢掉闹钟 —— 这是国产 ROM 上"提醒不响"最常见的原因。
  final bool batteryUnrestricted;
}""",
        """  final bool exactAlarmsAllowed;
}""",
    ),
    (
        """    required this.exactAlarmsAllowed,
    required this.batteryUnrestricted,
  });""",
        """    required this.exactAlarmsAllowed,
  });""",
    ),
    (
        """  /// 是否已豁免电池优化
  Future<bool> isBatteryUnrestricted() async {
    try {
      return (await ph.Permission.ignoreBatteryOptimizations.status).isGranted;
    } catch (_) {
      return false;
    }
  }

  /// 申请豁免电池优化，会弹出系统的「允许后台运行」对话框。
  Future<bool> requestBatteryUnrestricted() async {
    try {
      final status = await ph.Permission.ignoreBatteryOptimizations.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// 打开系统的「应用信息」页，便于手动改自启动 / 省电策略 / 权限
  Future<void> openSystemSettings() async {
    await _plugin.openAppNotificationSettings();
  }

  Future<void> openAppSettingsPage() async {
    await ph.openAppSettings();
  }""",
        """  /// 打开系统的通知设置页
  Future<void> openSystemSettings() async {
    await _plugin.openAppNotificationSettings();
  }""",
    ),
    (
        """      exactAlarmsAllowed: await canUseExactAlarms(),
      batteryUnrestricted: await isBatteryUnrestricted(),
    );""",
        """      exactAlarmsAllowed: await canUseExactAlarms(),
    );""",
    ),
]


SET_RULES = [
    (
        """  /// 申请豁免电池优化。
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
""",
        "",
    ),
    (
        """            _DiagRow(
              label: '后台运行',
              value: d.batteryUnrestricted ? '已豁免电池优化' : '受限，息屏可能不响',
              ok: d.batteryUnrestricted,
              warnOnly: true,
            ),
""",
        "",
    ),
    (
        """            onReschedule: _reschedule,
            onRequestBattery: _requestBatteryUnrestricted,
          ),""",
        """            onReschedule: _reschedule,
          ),""",
    ),
    (
        """    required this.onReschedule,
    required this.onRequestBattery,
  });""",
        """    required this.onReschedule,
  });""",
    ),
    (
        """  final Future<void> Function() onReschedule;
  final Future<void> Function() onRequestBattery;""",
        """  final Future<void> Function() onReschedule;""",
    ),
    (
        """          Divider(height: 1, indent: 16, endIndent: 16, color: p.line),
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
""",
        """          Divider(height: 1, indent: 16, endIndent: 16, color: p.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.battery_saver_outlined,
                      size: 19,
                      color: p.danger,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '到点不提醒？多半是后台被限制',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '国产系统会冻结后台 App、把闹钟押后甚至丢掉。请手动打开这三处：\\n'
                  '① 应用信息 → 省电策略 → 无限制\\n'
                  '② 应用信息 → 自启动 → 打开\\n'
                  '③ 权限管理 → 其他权限 → 闹钟和提醒 → 允许',
                  style: TextStyle(fontSize: 12, color: p.inkSoft, height: 1.7),
                ),
              ],
            ),
          ),
""",
    ),
]


def apply(path, rules, label):
    with io.open(path, encoding='utf-8') as f:
        src = f.read()
    for old, new in rules:
        n = src.count(old)
        if n != 1:
            print('  !! %s 命中 %d 次: %s' % (label, n, old.strip()[:46].replace('\n', ' / ')))
            continue
        src = src.replace(old, new, 1)
    with io.open(path, 'w', encoding='utf-8') as f:
        f.write(src)
    print('  == %s 处理完成' % label)


apply(SVC, SVC_RULES, 'notification_service.dart')
apply(SET, SET_RULES, 'settings_screen.dart')
