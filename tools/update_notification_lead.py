"""通知服务：提前天数改为按事件配置 + 重复事件用"下一次" + 通知 ID 段调整。"""
import io

PATH = r'E:\ribei\lib\services\notification_service.dart'

RULES = [
    # 1) 固定 4 档 -> 按事件配置
    (
        """  /// 目标日期前第几天推送（含当天）。顺序即通知 ID 的槽位。
  static const leadOffsets = <int>[3, 2, 1, 0];""",
        """  /// 单个倒计时最多排多少天提醒（含当天）。实际天数由每个事件自己配。
  static const maxLeadDays = 60;

  /// 倒计时通知 ID 的槽位步长：id * slotStride + slot
  static const _slotStride = 100;""",
    ),
    # 2) 待办 ID 段上移，避免与倒计时的新号段相撞
    (
        """  static const _todoIdBase = 100000;
  static const _testId = 999999;""",
        """  /// 待办通知 ID 段（倒计时占 eventId*100+slot，正常用量远不到这里）
  static const _todoIdBase = 1000000;
  static const _testId = 2000000;""",
    ),
    # 3) 排期循环：提前 lead 天 -> 当天
    (
        """    final mode = await _scheduleMode();
    var scheduled = 0;
    var skipped = 0;
    for (var slot = 0; slot < leadOffsets.length; slot++) {
      final moment = _countdownMoment(event, leadOffsets[slot]);
      if (moment == null) {
        skipped++;
        continue;
      }
      await _plugin.zonedSchedule(
        id: id * 10 + slot,
        title: _countdownTitle(event, leadOffsets[slot]),
        body: _countdownBody(event, leadOffsets[slot]),
        scheduledDate: moment,
        notificationDetails: _countdownDetails,
        androidScheduleMode: mode,
        payload: 'countdown:$id',
      );
      scheduled++;
    }
    return ScheduleOutcome(scheduled: scheduled, skipped: skipped);
  }

  Future<void> cancelCountdown(int eventId) async {
    for (var slot = 0; slot < leadOffsets.length; slot++) {
      await _plugin.cancel(id: eventId * 10 + slot);
    }
  }""",
        """    final mode = await _scheduleMode();
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
  }""",
    ),
    # 4) 重复事件要按"下一次"算提醒时刻
    (
        """  tz.TZDateTime? _countdownMoment(CountdownEvent event, int daysBefore) {
    final t = event.targetDate;""",
        """  tz.TZDateTime? _countdownMoment(CountdownEvent event, int daysBefore) {
    // 重复事件用 effectiveTarget —— 它给出的才是"下一次"的日子
    final t = event.effectiveTarget;""",
    ),
    # 5) 通知正文也用下一次的日子
    (
        """    final date = formatFullDate(event.targetDate);""",
        """    final date = formatFullDate(event.effectiveTarget);""",
    ),
]


def main():
    with io.open(PATH, encoding='utf-8') as f:
        src = f.read()
    for i, (old, new) in enumerate(RULES, 1):
        n = src.count(old)
        if n != 1:
            print('  !! 规则 %d 命中 %d 次，跳过' % (i, n))
            continue
        src = src.replace(old, new, 1)
        print('  == 规则 %d 已替换' % i)
    with io.open(PATH, 'w', encoding='utf-8') as f:
        f.write(src)


main()
