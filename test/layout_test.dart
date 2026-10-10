import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:ribei/data/transaction_dao.dart';
import 'package:ribei/models/transaction_record.dart';
import 'package:ribei/providers/ledger_provider.dart';
import 'package:ribei/providers/settings_provider.dart';
import 'package:ribei/screens/add_transaction_screen.dart';
import 'package:ribei/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 空账本，够这一页用
class _EmptyDao extends TransactionDao {
  @override
  Future<List<TransactionRecord>> all() async => const <TransactionRecord>[];
}

/// 用户那台老机型的尺寸。
///
/// 实测数据来自用户发来的截图：屏幕约 **368×816 dp**，
/// 而且他的输入法（带手写面板）**一弹出来就占掉约 372 dp**。
/// 这就是问题所在 —— 键盘一出来，可用高度只剩 816-372-24(状态栏)-56(标题栏) ≈ 364 dp，
/// 而底部那块（金额+支付+常用+自带键盘）本身就要 356 dp，
/// **上半区被压成 0，备注框直接被挤出屏幕**。
const _deviceWidth = 368.0;
const _deviceHeight = 816.0;
const _keyboardHeight = 372.0;
const _dpr = 2.75;

Widget _wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
    ChangeNotifierProvider(create: (_) => LedgerProvider(dao: _EmptyDao())),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  setUpAll(() async {
    // 这一页的日期行用的是 zh_CN 的 intl 数据，不初始化会直接抛异常
    await initializeDateFormatting('zh_CN');
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  /// 布置成"老机型"的样子；[keyboard] 为 true 时连键盘一起模拟
  Future<void> pumpPhone(WidgetTester tester, {bool keyboard = false}) async {
    tester.view.physicalSize = const Size(
      _deviceWidth * _dpr,
      _deviceHeight * _dpr,
    );
    tester.view.devicePixelRatio = _dpr;
    tester.view.viewInsets = keyboard
        ? FakeViewPadding(bottom: _keyboardHeight * _dpr)
        : FakeViewPadding.zero;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const AddTransactionScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('老机型上不弹键盘时：备注框和自带键盘都在，且不溢出', (tester) async {
    await pumpPhone(tester);

    expect(find.byType(TextField), findsOneWidget, reason: '备注框应该在');
    // 自带数字键盘在场（用退格图标判断，比找数字可靠）
    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);

    // 备注框必须完整落在屏幕内
    final rect = tester.getRect(find.byType(TextField));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(_deviceHeight));
  });

  testWidgets('弹出键盘时：自带数字键盘要收起（否则两套键盘 + 高度不够）', (tester) async {
    await pumpPhone(tester);
    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);

    // 键盘弹出来
    tester.view.viewInsets = FakeViewPadding(bottom: _keyboardHeight * _dpr);
    await tester.pumpAndSettle();

    expect(
      find.byIcon(Icons.backspace_outlined),
      findsNothing,
      reason: '系统键盘在的时候，自带数字键盘必须收起来 —— '
          '不然用户会去点它，改的却是金额（用户实测反馈就是这样）',
    );
  });

  testWidgets('弹出键盘并点亮备注后：备注框真的看得见（这条是用户报的 bug）', (tester) async {
    await pumpPhone(tester, keyboard: true);

    // 用户点备注框
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    // ① 上半区（可滚动那块）必须有足够高度。
    //    这一条是**直接盯着故障机制**：键盘一弹出来，可用高度被扣掉，
    //    如果底部固定块还占着三百多 dp，这块视口就会被压成接近 0，
    //    里面的东西统统被裁掉 —— 用户就是这样"看不见备注"的。
    //    注意：只断言备注框的 getRect 是查不出来的（视口 0 高时它照样被布局在屏幕内，
    //    只是被裁掉看不见），所以必须看视口自身的高度。
    final viewportHeight = tester
        .getSize(find.byType(SingleChildScrollView))
        .height;
    expect(
      viewportHeight,
      greaterThanOrEqualTo(60),
      reason: '上半区至少得留得下备注框（约 52dp），否则用户就是在盲打',
    );

    // ② 备注框要完整落在视口里，不能被裁掉一半
    final viewportRect = tester.getRect(find.byType(SingleChildScrollView));
    final noteRect = tester.getRect(find.byType(TextField));
    expect(noteRect.height, greaterThan(0), reason: '不能被压成 0 高');
    expect(
      noteRect.top,
      greaterThanOrEqualTo(viewportRect.top - 0.5),
      reason: '备注框超出视口上沿 → 被裁掉',
    );
    expect(
      noteRect.bottom,
      lessThanOrEqualTo(viewportRect.bottom + 0.5),
      reason: '备注框超出视口下沿 → 被裁掉',
    );
  });

  testWidgets('弹出键盘后仍然能保存（金额 + 保存按钮不能被挤掉）', (tester) async {
    await pumpPhone(tester, keyboard: true);

    expect(find.text('保存'), findsOneWidget);
    expect(find.text('支出'), findsWidgets);
  });

  testWidgets('更窄的屏（320dp）分类格子也不溢出', (tester) async {
    tester.view.physicalSize = const Size(320 * _dpr, 640 * _dpr);
    tester.view.devicePixelRatio = _dpr;
    tester.view.viewInsets = FakeViewPadding.zero;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const AddTransactionScreen()));
    await tester.pumpAndSettle();

    // 有溢出的话 flutter_test 会把 RenderFlex overflow 当失败报出来，
    // 所以这里跑通本身就说明格子高度算得下。再确认分类名都在。
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('其他'), findsWidgets);
  });
}
