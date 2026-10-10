import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/milestone_dao.dart';
import '../models/milestone.dart';

class MilestoneProvider extends ChangeNotifier {
  MilestoneProvider({MilestoneDao? dao}) : _dao = dao ?? const MilestoneDao();

  final MilestoneDao _dao;

  List<Milestone> _items = const <Milestone>[];
  bool _ready = false;
  String? _loadError;

  List<Milestone> get items => _items;
  bool get ready => _ready;

  /// 上次读取失败的原因；正常时是 null。理由同 LedgerProvider.loadError
  String? get loadError => _loadError;

  Future<void> load() async {
    try {
      _items = await _dao.all();
      _loadError = null;
    } catch (error) {
      _loadError = '$error';
      AppDatabase.instance.note('纪念日读取失败：$error');
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> save(Milestone milestone) async {
    if (milestone.id == null) {
      await _dao.insert(milestone);
    } else {
      await _dao.update(milestone);
    }
    await load();
  }

  Future<void> remove(int id) async {
    await _dao.delete(id);
    await load();
  }
}
