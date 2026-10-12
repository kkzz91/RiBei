import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:ribei/providers/countdown_provider.dart';
import 'package:ribei/providers/milestone_provider.dart';
import 'package:ribei/screens/add_day_screen.dart';
import 'package:ribei/theme/milestone_themes.dart';

/// 「添加日子」这一页的回归。
///
/// 两件事：
///   ① 整页在两种尺寸下都能渲染（它内部有 GridView / AnimatedSize / Stack，
///      约束给错了就会在 release 下静默炸掉 —— 和红线 28 ④ 同理，
///      只是这里没有海报那种无限循环，所以是"报错"而不是"卡死"）；
///   ② **背景主题选择器默认是收起来的**（用户要求：别再一上来就把 8 套全铺开），
///      点一下才展开，选完自动收回去。
void main() {
  // 这一页要用 `formatFullDate`（`DateFormat(..., 'zh_CN')`）——
  // 真机上由 `main.dart` 初始化，测试里得自己来，否则一 build 就抛 LocaleDataException。
  setUpAll(() => initializeDateFormatting('zh_CN'));

  Widget harness() => MultiProvider(
    providers: [
      ChangeNotifierProvider<CountdownProvider>(
        create: (_) => CountdownProvider(),
      ),
      ChangeNotifierProvider<MilestoneProvider>(
        create: (_) => MilestoneProvider(),
      ),
    ],
    child: const MaterialApp(home: AddDayScreen()),
  );

  for (final size in const <Size>[Size(390, 844), Size(360, 640)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('添加日子页渲染不报错（$tag）', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(harness());
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('背景主题选择器：默认收起，点一下才展开 8 套，选完收回', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // 收起态：只有"当前背景"那一行
    expect(find.text('当前背景'), findsOneWidget);
    expect(find.text('换一个'), findsOneWidget);
    expect(find.text('收起'), findsNothing);

    // 展开（这一行在列表里偏下，先滚进视野再点）
    await tester.ensureVisible(find.text('换一个'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('换一个'));
    await tester.pumpAndSettle();

    expect(find.text('收起'), findsOneWidget);
    // 8 套主题的名字都在（当前那套会同时出现在收起行里，所以用 findsWidgets）
    for (final style in milestoneThemeStyles) {
      expect(find.text(style.label), findsWidgets, reason: style.label);
    }
    expect(tester.takeException(), isNull);

    // 选一套 → 自动收回去
    await tester.ensureVisible(find.text('薄荷'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('薄荷'));
    await tester.pumpAndSettle();

    expect(find.text('换一个'), findsOneWidget);
    expect(find.text('收起'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
