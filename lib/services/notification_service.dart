import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/countdown_event.dart';
import '../models/todo_item.dart';
import '../utils/formatters.dart';

/// 单次排期的结果：排上了几条、因为时间已过跳过几条。
///
/// 区分这两个数很重要：界面上只显示"排定 0 条"会让人以为坏了，
/// 其实可能只是提醒时间都已经过去了。
class ScheduleOutcome {
  const ScheduleOutcome({required this.scheduled, required this.skipped});

  static const none = ScheduleOutcome(scheduled: 0, skipped: 0);

  final int scheduled;
  final int skipped;
}

class RescheduleReport {
  const RescheduleReport({required this.scheduled, required this.skipped});

  final int scheduled;
  final int skipped;

  String get summary => scheduled > 0
      ? '已排定 $scheduled 条提醒'
      : (skipped > 0 ? '没有待排的提醒（$skipped 条时间已过）' : '没有需要排定的提醒');
}

/// 提醒调度的真实状态，供设置页自检。
class ReminderDiagnostics {
  const ReminderDiagnostics({
    required this.channels,
    required this.pendingCount,
    required this.notificationsEnabled,
    required this.exactAlarmsAllowed,
  });

  final List<AndroidNotificationChannel> channels;
  final int pendingCount;
  final bool notificationsEnabled;
  final bool exactAlarmsAllowed;
}

/// 本地提醒调度中心。
///
/// 两类提醒，各用一个独立通知渠道：
///  * **倒计时**：目标日前 -3/-2/-1/当天 各排一条一次性通知
///  * **待办**：在设定的时刻排一条一次性通知
///
/// 全部由系统闹钟本地调度，不依赖服务器，也不要求 App 常驻后台。
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  // ---- 倒计时 ----
  static const _countdownChannelId = 'ribei_countdown';
  static const _countdownChannelName = '倒计时提醒';
  static const _countdownChannelDesc = '临近设定日期时，每天提醒你一次';

  /// 单个倒计时最多排多少天提醒（含当天）。实际天数由每个事件自己配。
  static const maxLeadDays = 60;

  /// 倒计时通知 ID 的槽位步长：id * slotStride + slot
  static const _slotStride = 100;

  // ---- 待办 ----
  static const _todoChannelId = 'ribei_todo';
  static const _todoChannelName = '待办提醒';
  static const _todoChannelDesc = '到设定的时间提醒你该做的事';

  /// 待办通知 ID 段（倒计时占 eventId*100+slot，正常用量远不到这里）
  static const _todoIdBase = 1000000;
  static const _testId = 2000000;

  /// 「两下短震」，比系统默认的单下更容易被察觉。
  static final _vibration = Int64List.fromList(<int>[0, 250, 150, 250]);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// 渠道 ID 固定不变。
  ///
  /// 曾经为了"让新的声音/震动设置生效"而换过渠道 ID 并删除旧渠道，
  /// 结果适得其反（删除渠道会连带影响系统的通知授权状态，并且闹钟指向被删渠道时会静默丢弃）。
  /// 现在**只创建、绝不删除**：渠道已存在时系统的行为是幂等的，不会出问题。
  String get countdownChannelId => _countdownChannelId;
  String get todoChannelId => _todoChannelId;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(_deviceLocation());

    await _plugin.initialize(
      settings: const InitializationSettings(
        // 必须是 drawable/ 下的裸资源名。
        // 插件用 getIdentifier(name, "drawable", 包名) 查找，写成 '@mipmap/ic_launcher'
        // 会查不到（返回 0），initialize 会回 result.error，在 runApp 之前抛异常导致闪退。
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );

    for (final channel in <AndroidNotificationChannel>[
      AndroidNotificationChannel(
        _countdownChannelId,
        _countdownChannelName,
        description: _countdownChannelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: _vibration,
      ),
      AndroidNotificationChannel(
        _todoChannelId,
        _todoChannelName,
        description: _todoChannelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: _vibration,
      ),
    ]) {
      await _android?.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  NotificationDetails get _countdownDetails => NotificationDetails(
    android: AndroidNotificationDetails(
      _countdownChannelId,
      _countdownChannelName,
      channelDescription: _countdownChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      // 每次投递都让插件把渠道配置重新下发一遍（系统允许时会被采纳）
      channelAction: AndroidNotificationChannelAction.update,
      enableVibration: true,
      vibrationPattern: _vibration,
    ),
  );

  NotificationDetails get _todoDetails => NotificationDetails(
    android: AndroidNotificationDetails(
      _todoChannelId,
      _todoChannelName,
      channelDescription: _todoChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      channelAction: AndroidNotificationChannelAction.update,
      enableVibration: true,
      vibrationPattern: _vibration,
    ),
  );

  // ---------- 权限 ----------

  Future<bool> ensurePermissions() async {
    final android = _android;
    if (android == null) return true;

    final notifications =
        await android.requestNotificationsPermission() ?? true;

    final canExact = await android.canScheduleExactNotifications() ?? false;
    if (!canExact) {
      await android.requestExactAlarmsPermission();
    }
    return notifications;
  }

  Future<bool> notificationsAllowed() async =>
      await _android?.areNotificationsEnabled() ?? true;

  Future<bool> canUseExactAlarms() async =>
      await _android?.canScheduleExactNotifications() ?? false;

  /// 单独申请「闹钟和提醒」权限（不弹通知权限框）。
  ///
  /// 系统可能在后台把它收回，届时提醒会静默降级成不精确闹钟 —— 延迟甚至不响。
  Future<bool> requestExactAlarms() async {
    final android = _android;
    if (android == null) return true;
    if (await android.canScheduleExactNotifications() ?? false) return true;
    await android.requestExactAlarmsPermission();
    return await android.canScheduleExactNotifications() ?? false;
  }

  /// 打开系统的通知设置页
  Future<void> openSystemSettings() async {
    await _plugin.openAppNotificationSettings();
  }

  // ---------- 倒计时 ----------

  Future<ScheduleOutcome> scheduleCountdown(CountdownEvent event) async {
    final id = event.id;
    if (id == null) return ScheduleOutcome.none;

    await cancelCountdown(id);
    if (!event.remindEnabled || event.isPast) return ScheduleOutcome.none;

    final mode = await _scheduleMode();
    final lead = event.safeLeadDays;
    var scheduled = 0;
    var skipped = 0;
    // 从「提前 lead 天」一路排到当天，共 lead+1 条
    for (var slot = 0; slot <= lead; slot++) {
      final daysBefore = lead - slot;
      final moment = _countdownMoment(event, daysBefore);
      if (moment == null) {
        skipped++;
        continue;
      }
      await _plugin.zonedSchedule(
        id: id * _slotStride + slot,
        title: _countdownTitle(event, daysBefore),
        body: _countdownBody(event, daysBefore),
        scheduledDate: moment,
        notificationDetails: _countdownDetails,
        androidScheduleMode: mode,
        payload: 'countdown:$id',
      );
      scheduled++;
    }
    return ScheduleOutcome(scheduled: scheduled, skipped: skipped);
  }

  /// 按最大可能槽位清，避免改了提前天数后残留旧闹钟
  Future<void> cancelCountdown(int eventId) async {
    for (var slot = 0; slot <= maxLeadDays; slot++) {
      await _plugin.cancel(id: eventId * _slotStride + slot);
    }
  }

  // ---------- 待办 ----------

  Future<ScheduleOutcome> scheduleTodo(TodoItem todo) async {
    final id = todo.id;
    if (id == null) return ScheduleOutcome.none;

    await cancelTodo(id);
    if (!todo.remindEnabled || todo.done) return ScheduleOutcome.none;

    final moment = tz.TZDateTime.from(todo.dueAt, tz.local);
    if (!moment.isAfter(tz.TZDateTime.now(tz.local))) {
      return const ScheduleOutcome(scheduled: 0, skipped: 1);
    }

    await _plugin.zonedSchedule(
      id: _todoIdBase + id,
      title: todo.title,
      body: todo.note.isEmpty ? '到点了，该做这件事了' : todo.note,
      scheduledDate: moment,
      notificationDetails: _todoDetails,
      androidScheduleMode: await _scheduleMode(),
      payload: 'todo:$id',
    );
    return const ScheduleOutcome(scheduled: 1, skipped: 0);
  }

  Future<void> cancelTodo(int todoId) async {
    await _plugin.cancel(id: _todoIdBase + todoId);
  }

  // ---------- 全量 ----------

  /// 按数据库重建两类提醒。
  ///
  /// **刻意不做「先清空全部再重建」**：一旦重建条件判错（例如提醒时间都已过去），
  /// 就会把全部闹钟抹掉，表现为"提醒莫名全部消失"。
  /// 逐条重排即可 —— `scheduleXxx` 内部会先取消自己那几条，不会影响别的。
  /// 条目删除时各自会取消自己的提醒，所以不会留下孤儿闹钟。
  Future<RescheduleReport> rescheduleAll({
    required Iterable<CountdownEvent> countdowns,
    required Iterable<TodoItem> todos,
  }) async {
    var scheduled = 0;
    var skipped = 0;
    for (final countdown in countdowns) {
      final r = await scheduleCountdown(countdown);
      scheduled += r.scheduled;
      skipped += r.skipped;
    }
    for (final todo in todos) {
      final r = await scheduleTodo(todo);
      scheduled += r.scheduled;
      skipped += r.skipped;
    }
    return RescheduleReport(scheduled: scheduled, skipped: skipped);
  }

  /// 自检：渠道、待推送条数、各项权限状态
  Future<ReminderDiagnostics> diagnostics() async {
    List<AndroidNotificationChannel> channels = const [];
    try {
      channels = await _android?.getNotificationChannels() ?? const [];
    } catch (_) {
      // 查询渠道失败不应该影响页面显示
    }
    return ReminderDiagnostics(
      channels: channels,
      pendingCount: (await _plugin.pendingNotificationRequests()).length,
      notificationsEnabled: await notificationsAllowed(),
      exactAlarmsAllowed: await canUseExactAlarms(),
    );
  }

  /// 立刻推一条，用于验证通知本身是否正常
  Future<void> showTest() async {
    await _plugin.show(
      id: _testId,
      title: '日贝 · 通知测试',
      body: '这条能响，只说明通知本身没问题；到点提醒还受后台限制影响。',
      notificationDetails: _countdownDetails,
    );
  }

  // ---------- 内部 ----------

  tz.TZDateTime? _countdownMoment(CountdownEvent event, int daysBefore) {
    // 重复事件用 effectiveTarget —— 它给出的才是"下一次"的日子
    final t = event.effectiveTarget;
    final day = DateTime(
      t.year,
      t.month,
      t.day,
    ).subtract(Duration(days: daysBefore));
    final moment = tz.TZDateTime(
      tz.local,
      day.year,
      day.month,
      day.day,
      event.remindHour,
      event.remindMinute,
    );
    return moment.isAfter(tz.TZDateTime.now(tz.local)) ? moment : null;
  }

  Future<AndroidScheduleMode> _scheduleMode() async {
    final canExact = await _android?.canScheduleExactNotifications() ?? false;
    // 没有精确闹钟权限时只能用不精确闹钟（会晚几分钟）。
    if (!canExact) return AndroidScheduleMode.inexactAllowWhileIdle;
    // 用 alarmClock（底层是 setAlarmClock）而不是 exactAllowWhileIdle：
    // 后者走 setExactAndAllowWhileIdle，在 Doze 下**每个 App 约 9 分钟只能响一次**，
    // 同一时刻有多条提醒时后面的会被系统推迟 —— 表现就是"经常性不响"。
    // setAlarmClock 不受这条限流约束，是可靠性最高的档位。
    return AndroidScheduleMode.alarmClock;
  }

  String _countdownTitle(CountdownEvent event, int daysBefore) =>
      daysBefore == 0
      ? '${event.title} · 就是今天'
      : '${event.title} · 还有 $daysBefore 天';

  String _countdownBody(CountdownEvent event, int daysBefore) {
    final date = formatFullDate(event.effectiveTarget);
    return daysBefore == 0
        ? '$date 到了，别忘了。'
        : '距离 $date 还有 $daysBefore 天，提前准备一下。';
  }

  /// 按设备当前 UTC 偏移推断时区，优先中国大陆。
  tz.Location _deviceLocation() {
    final offset = DateTime.now().timeZoneOffset;
    final locations = tz.timeZoneDatabase.locations;

    final shanghai = locations['Asia/Shanghai'];
    if (shanghai != null && shanghai.currentTimeZone.offset == offset) {
      return shanghai;
    }
    for (final location in locations.values) {
      if (location.currentTimeZone.offset == offset) return location;
    }
    return shanghai ?? tz.getLocation('UTC');
  }
}
