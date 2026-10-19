import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:ribei/data/countdown_dao.dart';
import 'package:ribei/data/milestone_dao.dart';
import 'package:ribei/data/todo_dao.dart';
import 'package:ribei/data/transaction_dao.dart';
import 'package:ribei/models/budget.dart';
import 'package:ribei/models/countdown_event.dart';
import 'package:ribei/models/milestone.dart';
import 'package:ribei/models/quick_entry.dart';
import 'package:ribei/models/todo_item.dart';
import 'package:ribei/models/transaction_record.dart';
import 'package:ribei/providers/countdown_provider.dart';
import 'package:ribei/providers/ledger_provider.dart';
import 'package:ribei/providers/milestone_provider.dart';
import 'package:ribei/providers/settings_provider.dart';
import 'package:ribei/providers/todo_provider.dart';
import 'package:ribei/screens/add_day_screen.dart';
import 'package:ribei/screens/add_transaction_screen.dart';
import 'package:ribei/screens/daily_chart_screen.dart';
import 'package:ribei/screens/days_screen.dart';
import 'package:ribei/screens/ledger_screen.dart';
import 'package:ribei/screens/share_bill_screen.dart';
import 'package:ribei/screens/stats_screen.dart';
import 'package:ribei/screens/todo_screen.dart';
import 'package:ribei/theme/app_theme.dart';
import 'package:ribei/utils/categories.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 把界面**渲染成 PNG**，用眼睛看 —— 这个项目没有真机，
/// 这是唯一能在电脑上"看到"改后长什么样的手段。
///
/// 用法（在 `E:\ribei` 下）：
/// ```powershell
/// flutter test tools\preview_screens.dart --update-goldens
/// ```
/// 图出在 `tools\preview_out\`（已 gitignore，不进仓库）。
/// 然后直接打开那几张 PNG 看。
///
/// ⚠️ 注意几点（都是踩过的）：
///  1. **必须挂真实主题**（`theme: AppTheme.light()`），否则 `context.palette`
///     走的是兜底值、顶栏是默认白条，看出来的配色是假的；
///  2. **中文字体要手动挂**（下面 `FontLoader('Roboto')` + 系统 `simhei.ttf`），
///     否则文字全是黑方块，字形和字距都看不出来；
///     图标仍然是方块 —— 测试环境没有 MaterialIcons 字体，忽略即可；
///  3. **provider 的 `load()` 得自己调**，真机上由主壳调；不调的话页面是空壳；
///  4. 测试环境没注册本地通知插件，`ReminderStatusBanner` 的权限复查会抛
///     LateInitializationError —— 与界面无关，下面用循环 `takeException()` 丢掉；
///  5. 数据用假 DAO 塞（`extends XxxDao` 只覆写 `all()`），不用真数据库。

// ------------------------------------------------------------------ 假 DAO

class _FakeCountdownDao extends CountdownDao {
  _FakeCountdownDao(this.items);
  final List<CountdownEvent> items;
  @override
  Future<List<CountdownEvent>> all() async => items;
}

class _FakeMilestoneDao extends MilestoneDao {
  _FakeMilestoneDao(this.items);
  final List<Milestone> items;
  @override
  Future<List<Milestone>> all() async => items;
}

class _FakeTxDao extends TransactionDao {
  _FakeTxDao(this.items);
  final List<TransactionRecord> items;
  @override
  Future<List<TransactionRecord>> all() async => items;
}

// ------------------------------------------------------------------ 样例数据

Future<CountdownProvider> _countdowns(DateTime now) async {
  final p = CountdownProvider(
    dao: _FakeCountdownDao(<CountdownEvent>[
      CountdownEvent(
        id: 1,
        title: '期末考试',
        targetDate: now.add(const Duration(days: 21)),
        pinned: true,
        createdAt: now,
      ),
      CountdownEvent(
        id: 2,
        title: '发工资',
        targetDate: now.add(const Duration(days: 4)),
        createdAt: now,
      ),
      CountdownEvent(
        id: 3,
        title: '项目上线',
        targetDate: now.add(const Duration(days: 36)),
        createdAt: now,
      ),
      CountdownEvent(
        id: 4,
        title: 'New Year',
        targetDate: now.add(const Duration(days: 56)),
        createdAt: now,
      ),
    ]),
  );
  await p.load();
  return p;
}

Future<MilestoneProvider> _milestones(DateTime now) async {
  final p = MilestoneProvider(
    dao: _FakeMilestoneDao(<Milestone>[
      Milestone(
        id: 5,
        title: '22岁生日',
        startDate: now.subtract(const Duration(days: 42)),
        createdAt: now,
      ),
      Milestone(
        id: 6,
        title: '在一起',
        startDate: now.subtract(const Duration(days: 126)),
        createdAt: now,
      ),
      Milestone(
        id: 7,
        title: 'iPhone 发布',
        startDate: now.subtract(const Duration(days: 6340)),
        createdAt: now,
      ),
    ]),
  );
  await p.load();
  return p;
}

/// 账本用的样例账目（账本页和"每天花了多少"大图共用）
List<TransactionRecord> _ledgerRecords(DateTime now) => <TransactionRecord>[
  TransactionRecord(
    id: 1,
    amount: 15,
    type: TxType.expense,
    category: '餐饮',
    note: '午饭',
    date: now,
    payMethod: PayMethod.wechat,
    createdAt: now,
  ),
  TransactionRecord(
    id: 2,
    amount: 200,
    type: TxType.expense,
    category: '购物',
    note: '日用品',
    date: now,
    payMethod: PayMethod.alipay,
    createdAt: now,
  ),
  TransactionRecord(
    id: 3,
    amount: 8000,
    type: TxType.income,
    category: '工资',
    date: now,
    payMethod: PayMethod.card,
    createdAt: now,
  ),
];

Future<LedgerProvider> _ledger(DateTime now) async {
  final p = LedgerProvider(dao: _FakeTxDao(_ledgerRecords(now)));
  await p.load();
  return p;
}

/// 待办用的样例（多选模式下看一眼）
class _FakeTodoDao extends TodoDao {
  _FakeTodoDao(this.items);
  final List<TodoItem> items;
  @override
  Future<List<TodoItem>> all() async => items;
}

List<TodoItem> _todoSamples(DateTime now) => <TodoItem>[
  TodoItem(
    id: 1,
    title: '交房租',
    dueAt: now.add(const Duration(hours: 3)),
    priority: TodoPriority.high,
    createdAt: now,
  ),
  TodoItem(
    id: 2,
    title: '买猫粮',
    dueAt: now.add(const Duration(days: 1)),
    createdAt: now,
  ),
  TodoItem(
    id: 3,
    title: '给妈妈打电话',
    dueAt: now.subtract(const Duration(days: 1)),
    createdAt: now,
  ),
];

// ------------------------------------------------------------------ 出图

void main() {
  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
    // 测试环境没有真机，通知插件的"平台实现"是空的 —— 不注册的话，
    // ReminderStatusBanner 一建就抛 LateInitializationError（满屏报错、测试判失败）。
    TestWidgetsFlutterBinding.ensureInitialized();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    // 再让这个 channel 一律回 true（"权限都正常"），
    // 否则 canScheduleExactNotifications 会返回 false、图上多一条红色的权限提示条
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (call) async => true,
        );
    // 系统中文字体挂到默认字族上，否则文字是黑方块
    final bytes = File(r'C:\Windows\Fonts\simhei.ttf').readAsBytesSync();
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
    await loader.load();
  });

  /// 拍一张：`file` 相对 tools/，所以会落在 tools/preview_out/
  Future<void> shoot(
    WidgetTester tester,
    Widget app,
    String name, {
    Size size = const Size(390, 844),
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(app);
    // 有些部件（如 ReminderStatusBanner）会去问系统通知权限，测试环境没有这个插件、
    // 必然抛 LateInitializationError。它在**首帧构建时**就抛，所以这里先把这些
    // 环境性异常丢干净，再继续 —— 否则 golden 比对那一步会被它打断（图其实已写出）。
    while (tester.takeException() != null) {}
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {}
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('preview_out/$name.png'),
    );
    // 环境性的异步异常（没注册通知插件）全部丢掉，再拆掉页面
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();
    }
  }

  for (final dark in <bool>[false, true]) {
    testWidgets('倒计时列表（${dark ? '深色' : '浅色'}）', (tester) async {
      final now = DateTime.now();
      await shoot(
        tester,
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CountdownProvider>.value(
              value: await _countdowns(now),
            ),
            ChangeNotifierProvider<MilestoneProvider>.value(
              value: await _milestones(now),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: const DaysScreen(),
          ),
        ),
        dark ? 'days_dark' : 'days_light',
      );
    });
  }

  testWidgets('记一笔', (tester) async {
    // 这个文件在 tools/ 下（不是 test/），分析器不把它当测试，
    // 所以下面这个 @visibleForTesting 的 API 会报警 —— 这里确实是在测试里用，忽略。
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final now = DateTime.now();
    final settings = SettingsProvider();
    await settings.load();
    await settings.addQuickEntry(
      QuickEntry(
        type: TxType.expense,
        category: '餐饮',
        amount: 15,
        note: '午饭',
        payMethod: PayMethod.wechat,
      ),
    );
    final ledger = await _ledger(now);
    Widget app() => MultiProvider(
      providers: [
        ChangeNotifierProvider<LedgerProvider>.value(value: ledger),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const AddTransactionScreen(),
      ),
    );
    await shoot(tester, app(), 'add_transaction');
    // 红线 22 那台老机型（368×816 + 高输入法）：日期行会不会被自带键盘顶掉
    await shoot(
      tester,
      app(),
      'add_transaction_small',
      size: const Size(368, 816),
    );
  });

  testWidgets('添加日子', (tester) async {
    final now = DateTime.now();
    await shoot(
      tester,
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CountdownProvider>.value(
            value: await _countdowns(now),
          ),
          ChangeNotifierProvider<MilestoneProvider>.value(
            value: await _milestones(now),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const AddDayScreen(),
        ),
      ),
      'add_day',
    );
  });

  // 预算卡的几档颜色各出一张（同一份账 215 元，换不同的预算方案）
  const budgetCases = <String, BudgetPlan>{
    // 绿：在预算内、红线都没碰
    'ledger': BudgetPlan(total: 3000, tiers: <double>[1000, 2000]),
    // 黄：跨过 1 条红线
    'ledger_yellow': BudgetPlan(total: 3000, tiers: <double>[100, 2000]),
    // 橙：跨过 2 条
    'ledger_orange': BudgetPlan(total: 3000, tiers: <double>[100, 200]),
    // 红：超预算但没超过一成
    'ledger_red': BudgetPlan(total: 200, tiers: <double>[100, 200]),
    // 黑：超预算一成以上（215 / 190 = 113%）
    'ledger_black': BudgetPlan(total: 190, tiers: <double>[100]),
  };
  for (final entry in budgetCases.entries) {
    testWidgets('账本（预算档位 ${entry.key}）', (tester) async {
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final now = DateTime.now();
      final settings = SettingsProvider();
      await settings.load();
      await settings.setBudget(entry.value);
      await shoot(
        tester,
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LedgerProvider>.value(
              value: await _ledger(now),
            ),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: const LedgerScreen(),
          ),
        ),
        entry.key,
      );
    });
  }

  testWidgets('统计', (tester) async {
    final now = DateTime.now();
    await shoot(
      tester,
      ChangeNotifierProvider<LedgerProvider>.value(
        value: await _ledger(now),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const StatsScreen(),
        ),
      ),
      'stats',
    );
  });

  testWidgets('账本：每天花了多少（大图）', (tester) async {
    final now = DateTime.now();
    await shoot(
      tester,
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: DailyChartScreen(month: now, records: _ledgerRecords(now)),
      ),
      'daily_chart',
    );
  });

  testWidgets('倒计时：长按进入多选', (tester) async {
    final now = DateTime.now();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CountdownProvider>.value(
            value: await _countdowns(now),
          ),
          ChangeNotifierProvider<MilestoneProvider>.value(
            value: await _milestones(now),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const DaysScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 长按一行 → 进多选，再点另一行凑成"已选 2 项"
    await tester.longPress(find.text('发工资'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('项目上线'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('preview_out/days_selecting.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('待办：长按进入多选', (tester) async {
    final now = DateTime.now();
    final todos = TodoProvider(dao: _FakeTodoDao(_todoSamples(now)));
    await todos.load();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      ChangeNotifierProvider<TodoProvider>.value(
        value: todos,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const TodoScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('preview_out/todo_plain.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('待办：长按进入多选', (tester) async {
    final now = DateTime.now();
    final todos = TodoProvider(dao: _FakeTodoDao(_todoSamples(now)));
    await todos.load();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      ChangeNotifierProvider<TodoProvider>.value(
        value: todos,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const TodoScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('交房租'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('preview_out/todo_selecting.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('添加日子（编辑一个纪念日）', (tester) async {
    // 纪念日那条分支少了"重复 / 提醒"两行，得单独看一眼
    final now = DateTime.now();
    await shoot(
      tester,
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CountdownProvider>.value(
            value: await _countdowns(now),
          ),
          ChangeNotifierProvider<MilestoneProvider>.value(
            value: await _milestones(now),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: AddDayScreen(
            milestone: Milestone(
              id: 1,
              title: '在一起',
              startDate: now.subtract(const Duration(days: 126)),
              note: '从这天开始',
              createdAt: now,
            ),
          ),
        ),
      ),
      'add_day_milestone',
    );
  });

  testWidgets('分享账单', (tester) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final now = DateTime.now();
    await shoot(
      tester,
      ChangeNotifierProvider<LedgerProvider>.value(
        value: await _ledger(now),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const ShareBillScreen(),
        ),
      ),
      'share_bill',
    );
  });
}
