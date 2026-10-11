import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ribei/providers/countdown_provider.dart';
import 'package:ribei/providers/milestone_provider.dart';
import 'package:ribei/screens/countdown_detail_screen.dart';
import 'package:ribei/screens/milestone_detail_screen.dart';

/// 回归：**海报详情页必须能拿到"有界"的约束。**
///
/// 起因是一次真实事故（v1.6.1 埋的、v1.6.3 修）：海报被套在
/// `SingleChildScrollView` + `ConstrainedBox(minHeight)` 里，
/// 海报最外层的 `Stack` 于是拿到**无界高度**、`size` 变成无限大，
/// 背景图案里"按固定步长铺满画布"的循环永远转不完 → **整个 App 卡死**。
///
/// ⚠️ 这个 bug **只在 release 发作**：debug 下是 `assert(size.isFinite)` 直接报错，
/// 而 release 把断言关掉了，就变成静默死循环、只剩"点开就卡死"。
///
/// ⚠️ 注意这条测试**盖的是整条链路**：只测 `PosterScreen`（它自己给紧约束）或
/// 只测 `MilestoneCard`（单独渲染时约束正常）**都发现不了**这个 bug ——
/// 出问题的恰恰是"详情页把海报套起来"的那一层。所以别再把它简化掉。
void main() {
  const sizes = <Size>[Size(390, 844), Size(360, 640)];

  for (final size in sizes) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('纪念日详情页渲染不报错（$tag）', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        ChangeNotifierProvider<MilestoneProvider>(
          create: (_) => MilestoneProvider(),
          child: const MaterialApp(home: MilestoneDetailScreen(milestoneId: 1)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);

      // 收尾：把页面拆掉，让详情页那个"跨零点"定时器跟着 dispose，
      // 否则测试结束时会被判成 "A Timer is still pending"。
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('倒计时详情页渲染不报错（$tag）', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        ChangeNotifierProvider<CountdownProvider>(
          create: (_) => CountdownProvider(),
          child: const MaterialApp(home: CountdownDetailScreen(countdownId: 1)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
