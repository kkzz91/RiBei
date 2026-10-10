import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// 提醒能力状态条。
///
/// 存在的理由：**系统可能在后台把权限悄悄收回**（小米等国产 ROM 尤其激进），
/// 一旦「闹钟和提醒」被收回，提醒会静默降级成不精确闹钟 —— 表现为延迟甚至不响，
/// 而 App 里看不出任何异常。所以每次进入界面、以及从系统设置返回时都复查一遍，
/// 缺了就直接摆出一条可点的提示。
class ReminderStatusBanner extends StatefulWidget {
  const ReminderStatusBanner({super.key});

  @override
  State<ReminderStatusBanner> createState() => _ReminderStatusBannerState();
}

class _ReminderStatusBannerState extends State<ReminderStatusBanner>
    with WidgetsBindingObserver {
  bool _notificationsOn = true;
  bool _exactAllowed = true;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 用户刚从系统设置页回来时，重新检查
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final service = NotificationService.instance;
    final notifications = await service.notificationsAllowed();
    final exact = await service.canUseExactAlarms();
    if (!mounted) return;
    setState(() {
      _notificationsOn = notifications;
      _exactAllowed = exact;
      _checked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || (_notificationsOn && _exactAllowed)) {
      return const SizedBox.shrink();
    }

    final p = context.palette;
    final missingNotifications = !_notificationsOn;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: p.expenseSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                missingNotifications
                    ? Icons.notifications_off_outlined
                    : Icons.alarm_off_outlined,
                size: 19,
                color: p.danger,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  missingNotifications
                      ? '通知权限未开启，到点不会提醒你'
                      : '「闹钟和提醒」未授权，提醒会延迟甚至不响',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 28, right: 6),
            child: Text(
              missingNotifications
                  ? '系统设置的「通知」里把日贝关掉了，需要重新打开'
                  : '系统可能在后台收回了这个权限。不开的话，提醒时间会被系统随意推迟',
              style: TextStyle(fontSize: 12, color: p.danger, height: 1.4),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => NotificationService.instance
                      .openSystemSettings(),
                  style: TextButton.styleFrom(
                    foregroundColor: p.danger,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: const Text('系统设置'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: p.danger,
                    minimumSize: const Size(96, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () async {
                    final service = NotificationService.instance;
                    if (missingNotifications) {
                      await service.ensurePermissions();
                    } else {
                      await service.requestExactAlarms();
                    }
                    await _check();
                  },
                  child: Text(missingNotifications ? '去开启' : '去授权'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
