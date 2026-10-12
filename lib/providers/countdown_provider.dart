import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/countdown_dao.dart';
import '../models/countdown_event.dart';
import '../services/notification_service.dart';

class CountdownProvider extends ChangeNotifier {
  CountdownProvider({CountdownDao? dao}) : _dao = dao ?? const CountdownDao();

  final CountdownDao _dao;

  List<CountdownEvent> _events = const <CountdownEvent>[];
  bool _ready = false;
  String? _loadError;

  List<CountdownEvent> get events => _events;
  bool get ready => _ready;

  /// 上次读取失败的原因；正常时是 null。理由同 LedgerProvider.loadError
  String? get loadError => _loadError;

  /// 未到期的事件，按 [sort] 排序。
  ///
  /// 排序一律用 `daysLeft`（即 effectiveTarget）而不是存的 target_date ——
  /// 重复事件实际要倒数到的是"下一次"，和存的锚点不是一回事。
  List<CountdownEvent> upcomingBy(int sort) {
    final list = _events.where((e) => !e.isPast).toList();
    list.sort((a, b) => CountdownSort.compare(sort, a, b));
    return list;
  }

  /// 已过期（只有非重复事件会过期），按 [sort] 排序。
  ///
  /// 「剩余天数」在这里的含义是"过去多久了"：刚结束的排在前面，
  /// 所以用倒序 —— 和进行中那一段的观感保持一致（离现在近的在上面）。
  List<CountdownEvent> archivedBy(int sort) {
    final list = _events.where((e) => e.isPast).toList();
    if (sort == CountdownSort.byDays) {
      list.sort((a, b) => b.daysLeft.compareTo(a.daysLeft));
    } else {
      list.sort((a, b) => CountdownSort.compare(sort, a, b));
    }
    return list;
  }

  /// 已进入提醒窗口的事件数
  int get urgentCount => _events.where((e) => e.isUrgentWindow).length;

  Future<void> load() async {
    try {
      _events = await _dao.all();
      _loadError = null;
    } catch (error) {
      _loadError = '$error';
      AppDatabase.instance.note('倒计时读取失败：$error');
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> save(CountdownEvent event) async {
    var saved = event;
    if (event.id == null) {
      final id = await _dao.insert(event);
      saved = event.copyWith(id: id);
    } else {
      await _dao.update(event);
    }
    await load();
    await NotificationService.instance.scheduleCountdown(saved);
  }

  Future<void> remove(int id) async {
    await _dao.delete(id);
    await NotificationService.instance.cancelCountdown(id);
    await load();
  }

  /// 取消**所有**倒计时的置顶（理由同 MilestoneProvider.unpinAll：
  /// 置顶全局最多一个，长按菜单和编辑页的开关必须守同一条规矩）。
  Future<void> unpinAll() async {
    final changed = _events.where((e) => e.pinned && e.id != null).toList();
    if (changed.isEmpty) return;
    for (final e in changed) {
      await _dao.update(e.copyWith(pinned: false));
    }
    await load();
  }

  /// 清空全部倒计时，返回删掉的条数。
  ///
  /// 重点是**逐条取消各自的闹钟** —— 不能用「取消所有待推送通知」那种写法，
  /// 那会连待办的提醒一起抹掉（本项目踩过这个坑，见接手说明红线 4）。
  Future<int> clearAll() async {
    for (final event in _events) {
      final id = event.id;
      if (id != null) {
        await NotificationService.instance.cancelCountdown(id);
      }
    }
    final deleted = await _dao.deleteAll();
    await load();
    return deleted;
  }
}
