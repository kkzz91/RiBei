import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/categories.dart';

/// 支付方式的小标签：小图标 + 名字。
///
/// 老账目（支付方式这个字段出现之前记的）是不显示标签的 ——
/// 由 [PayMethod.isRecorded] 决定，调用方不用自己判断。
class PayTag extends StatelessWidget {
  const PayTag({super.key, required this.method, this.compact = false});

  final int method;

  /// 更小一号，用在搜索结果的密集行里
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!PayMethod.isRecorded(method)) return const SizedBox.shrink();
    final p = context.palette;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 1 : 2.5,
      ),
      decoration: BoxDecoration(
        color: p.paper,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PayMethod.iconOf(method),
            size: compact ? 9 : 10.5,
            color: p.inkFaint,
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            PayMethod.labelOf(method),
            style: TextStyle(
              fontSize: compact ? 9.5 : 10.5,
              fontWeight: FontWeight.w600,
              color: p.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
