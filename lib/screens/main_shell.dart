import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/countdown_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/todo_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../widgets/data_health_banner.dart';
import 'birthday_screen.dart';
import 'days_screen.dart';
import 'ledger_screen.dart';
import 'stats_screen.dart';
import 'todo_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  /// 每次启动按数据库重建一遍闹钟。
  ///
  /// 申请通知权限那段弹窗已经搬到首次启动的说明页去了
  /// （见 `onboarding_screen.dart`）—— 一进来就弹框要权限，用户容易顺手点掉，
  /// 不如在讲清"为什么必须要"之后一次性申请。
  /// 权限后来被系统收回时，靠页面顶部的 [ReminderStatusBanner] 常驻提示兜底，
  /// 那里还带「去授权」按钮，比启动时弹一次更可靠。
  Future<void> _bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    // 在 await 之前取好依赖，避免 await 之后再碰 context。
    final service = NotificationService.instance;
    final countdowns = context.read<CountdownProvider>();
    final todos = context.read<TodoProvider>();

    // 系统可能回收过闹钟，每次启动都按数据库重建一次，保证提醒不会莫名消失。
    await countdowns.load();
    await todos.load();
    // 重复任务到期后自动滚到下一个周期，
    // 免得"每周一交作业"很久没开 App 回来显示成逾期几十天
    await todos.rollForwardRepeating();
    await service.rescheduleAll(
      countdowns: countdowns.events,
      todos: todos.items,
    );

    await _celebrateBirthdayIfAny();
  }

  /// 倒计时里名称或备注提到「生日」的，到了当天弹一次小惊喜。
  ///
  /// 两个约束：
  /// ① **一天只弹一次** —— 记录写在 SettingsProvider 里（存的是日期，
  ///    所以到了明年同一天会自动再触发）；
  /// ② **一次只庆祝一个** —— 万一有两个人生日撞同一天，
  ///    关掉这一页后下次进 App 会弹另一个，而不是连着弹两页。
  ///
  /// 注意：只在启动时判断一次。如果 App 一直开着跨过了零点，那天不会弹，
  /// 重开一次就有了 —— 这个取舍是为了不在前台定时轮询。
  Future<void> _celebrateBirthdayIfAny() async {
    final settings = context.read<SettingsProvider>();
    final countdowns = context.read<CountdownProvider>();
    final day = _dayKey(DateTime.now());

    for (final event in countdowns.events) {
      final id = event.id;
      if (id == null || !event.isBirthdayToday) continue;
      if (settings.birthdayCelebrated(id, day)) continue;

      await settings.markBirthdayCelebrated(id, day);
      // 等首帧站稳再弹，免得和页面入场动画挤在一起
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => BirthdayScreen(event: event),
        ),
      );
      return;
    }
  }

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  @override
  Widget build(BuildContext context) {
    final todoProvider = context.watch<TodoProvider>();
    final alertCount = todoProvider.overdueCount + todoProvider.todayCount;
    final urgent = context.watch<CountdownProvider>().urgentCount;

    return Scaffold(
      // 数据读不出来时，用悬浮在顶部的方式提示。
      // 不占用布局，是因为正常情况下它是零尺寸的（SizedBox.shrink），
      // 用 SafeArea 包裹放在 Column 里会平白多出状态栏的高度。
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: const [
              LedgerScreen(),
              // 倒计时 + 纪念日已经合并成一个「日子」板块（v1.6.5）
              DaysScreen(),
              TodoScreen(),
              StatsScreen(),
            ],
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: DataHealthBanner()),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          Haptics.tap();
          setState(() => _index = i);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '账本',
          ),
          NavigationDestination(
            icon: urgent > 0
                ? Badge(
                    label: Text('$urgent'),
                    backgroundColor: context.palette.danger,
                    child: const Icon(Icons.event_note_outlined),
                  )
                : const Icon(Icons.event_note_outlined),
            selectedIcon: urgent > 0
                ? Badge(
                    label: Text('$urgent'),
                    backgroundColor: context.palette.danger,
                    child: const Icon(Icons.event_note),
                  )
                : const Icon(Icons.event_note),
            label: '日子',
          ),
          NavigationDestination(
            icon: alertCount > 0
                ? Badge(
                    label: Text('$alertCount'),
                    backgroundColor: context.palette.danger,
                    child: const Icon(Icons.checklist_rtl_outlined),
                  )
                : const Icon(Icons.checklist_rtl_outlined),
            selectedIcon: alertCount > 0
                ? Badge(
                    label: Text('$alertCount'),
                    backgroundColor: context.palette.danger,
                    child: const Icon(Icons.checklist_rtl),
                  )
                : const Icon(Icons.checklist_rtl),
            label: '待办',
          ),
          const NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: '统计',
          ),
        ],
      ),
    );
  }
}
