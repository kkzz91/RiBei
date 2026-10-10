import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/countdown_provider.dart';
import '../providers/ledger_provider.dart';
import '../providers/todo_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../screens/data_health_screen.dart';

/// 数据读不出来时的**醒目**提示条。
///
/// 为什么必须有它（v1.5.3 加的）：
/// 以前数据库一旦打不开，`load()` 抛出的异常没人接，界面上就是"还没有记过一笔账" ——
/// **看起来跟"数据被删光了"一模一样**。用户的第一反应是卸载重装，
/// 而卸载会真的把数据删掉，把一个"读不出来"变成"永久丢失"。
///
/// 所以这里要做的只有一件事：**把"数据可能还在，千万别卸载"喊出来**，
/// 并给一个去看详情的入口。
class DataHealthBanner extends StatelessWidget {
  const DataHealthBanner({super.key, this.padding});

  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    // 注意别写成 <String>[ ... ]：那会要求每个元素都非空，
    // 而 loadError 本来就是可空的。先收集再过滤掉 null。
    final errors = [
      context.watch<LedgerProvider>().loadError,
      context.watch<CountdownProvider>().loadError,
      context.watch<TodoProvider>().loadError,
    ].whereType<String>().toList();
    if (errors.isEmpty) return const SizedBox.shrink();

    final p = context.palette;
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: p.danger.withValues(alpha: p.isDark ? 0.22 : 0.10),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Haptics.warn();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DataHealthScreen(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.danger.withValues(alpha: 0.45)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 19, color: p.danger),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '数据读取失败 —— 但多半没有丢',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: p.danger,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '千万不要卸载重装 —— 卸载会真的把数据删掉。'
                        '点这里看详情，并把里面的「导出备份」发我。',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: p.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: p.danger),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
