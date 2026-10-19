import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:ribei/data/transaction_dao.dart';
import 'package:ribei/models/transaction_record.dart';
import 'package:ribei/providers/countdown_provider.dart';
import 'package:ribei/providers/ledger_provider.dart';
import 'package:ribei/providers/settings_provider.dart';
import 'package:ribei/providers/todo_provider.dart';
import 'package:ribei/screens/ledger_screen.dart';
import 'package:ribei/theme/app_theme.dart';
import 'package:ribei/widgets/app_toast.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 回归：**顶栏按钮必须点得动**。
///
/// 用户 v1.6.19 报"顶栏的按钮都点不到、点了没反应：设置、倒计时都不行"。
/// 根因是 `AppToast` 那条浮层：它挂在**根 overlay** 上、位置正好压着右上角那几个按钮，
/// 而且（1）它本身会吃掉点击，（2）动画播完时如果组件已卸载就**永远不摘掉**，
/// 变成一块透明但吃点击的挡板。
///
/// 这组测试把「有提示条在场时顶栏还能不能点」直接钉住。
class _EmptyDao extends TransactionDao {
  @override
  Future<List<TransactionRecord>> all() async => const <TransactionRecord>[];
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
    // 设置页一进去就问通知权限，测试环境没有通知插件会抛 LateInitializationError；
    // 注册一个空实现 + 让那个 channel 一律回 true，见 tools/preview_screens.dart 里的说明
    TestWidgetsFlutterBinding.ensureInitialized();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          // 注意：`pendingNotificationRequests` 返回的是列表，不能一律回 true，
          // 否则插件里的 `as List<dynamic>?` 会抛 _TypeError（第一版就栽在这）
          (call) async =>
              call.method == 'pendingNotificationRequests' ? <dynamic>[] : true,
        );
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> pumpLedger(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final settings = SettingsProvider();
    await settings.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LedgerProvider>(
            create: (_) => LedgerProvider(dao: _EmptyDao()),
          ),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<CountdownProvider>(
            create: (_) => CountdownProvider(),
          ),
          ChangeNotifierProvider<TodoProvider>(create: (_) => TodoProvider()),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const LedgerScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 点了顶栏的设置之后，设置页应该真的开出来
  void expectOpenedSettings() {
    // 设置页顶栏标题就是「设置」（账本页那个是图标，没有文字）
    expect(
      find.text('设置'),
      findsOneWidget,
      reason: '点了设置应该已经跳进设置页',
    );
  }

  testWidgets('顶栏「设置」点得动', (WidgetTester tester) async {
    await pumpLedger(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expectOpenedSettings();
  });

  testWidgets('顶栏「搜索」点得动', (WidgetTester tester) async {
    await pumpLedger(tester);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    // 搜索页有一句"换个关键字试试"
    expect(find.textContaining('关键字'), findsWidgets);
  });

  testWidgets('提示条在场时，顶栏按钮照样点得动（这次 bug 的正主）', (WidgetTester tester) async {
    await pumpLedger(tester);

    // 弹一条提示，然后**立刻**去点顶栏的设置 —— 以前这一下会被提示条吃掉
    AppToast.show(tester.element(find.byType(LedgerScreen)), '已记下 · 餐饮 ¥15.00');
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expectOpenedSettings();
  });

  testWidgets('提示条淡出后不会留下吃点击的透明挡板', (WidgetTester tester) async {
    await pumpLedger(tester);
    AppToast.show(tester.element(find.byType(LedgerScreen)), '已记下');
    // 走完 260ms 淡出 + 1700ms 停留，再等一会儿
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expectOpenedSettings();
  });
}
