import 'package:flutter/material.dart';

/// 收支类型
class TxType {
  const TxType._();
  static const int expense = 0;
  static const int income = 1;
}

class TxCategory {
  const TxCategory(this.name, this.icon);

  final String name;
  final IconData icon;
}

/// 支出分类
const List<TxCategory> expenseCategories = <TxCategory>[
  TxCategory('餐饮', Icons.ramen_dining),
  TxCategory('交通', Icons.directions_bus_filled),
  TxCategory('购物', Icons.shopping_bag),
  TxCategory('居住', Icons.home_rounded),
  TxCategory('娱乐', Icons.sports_esports),
  TxCategory('医疗', Icons.medical_services),
  TxCategory('学习', Icons.menu_book),
  TxCategory('通讯', Icons.smartphone),
  TxCategory('人情', Icons.card_giftcard),
  TxCategory('其他', Icons.more_horiz),
];

/// 收入分类
const List<TxCategory> incomeCategories = <TxCategory>[
  TxCategory('生活费', Icons.savings),
  TxCategory('工资', Icons.account_balance_wallet),
  TxCategory('兼职', Icons.work_outline),
  TxCategory('奖学金', Icons.workspace_premium),
  TxCategory('红包', Icons.redeem),
  TxCategory('理财', Icons.trending_up),
  TxCategory('退款', Icons.assignment_return),
  TxCategory('其他', Icons.more_horiz),
];

List<TxCategory> categoriesOf(int type) =>
    type == TxType.income ? incomeCategories : expenseCategories;

/// 分类专属色。
///
/// 目的：**同一个分类在"记一笔"、账本流水、统计图表里都是同一个颜色**，
/// 让人一眼认出来（餐饮永远是那个橙，交通永远是那个蓝）。
///
/// 取色原则：中调、饱和度适中 —— 浅色底和深色底上都读得清，
/// 所以只定义一套，深色模式下统一往白里提亮一点（见 [categoryColorOf]）。
/// 刻意避开把整体配色搞花：页面背景、文字、边框仍是原来的玉青 + 暖纸底。
const Map<String, Color> _categoryColors = <String, Color>{
  // 支出
  '餐饮': Color(0xFFE07B39), // 橙
  '交通': Color(0xFF3A86C8), // 蓝
  '购物': Color(0xFFD45D8C), // 粉
  '居住': Color(0xFF2F8F7F), // 青绿
  '娱乐': Color(0xFF8A5CD1), // 紫
  '医疗': Color(0xFFD2484A), // 红
  '学习': Color(0xFF4F6BD8), // 靛蓝
  '通讯': Color(0xFF16A0A8), // 青
  '人情': Color(0xFFC9A227), // 金
  '其他': Color(0xFF8C857B), // 暖灰
  // 收入
  '生活费': Color(0xFF2E9E6B), // 翠绿
  '工资': Color(0xFF4B7BE5), // 宝蓝
  '兼职': Color(0xFFC77E2E), // 琥珀
  '奖学金': Color(0xFFD4A017), // 金黄
  '红包': Color(0xFFE0526B), // 玫红
  '理财': Color(0xFF1F9AA8), // 蓝绿
  '退款': Color(0xFF7E8CA8), // 石板灰
};

/// 找不到名字时的兜底色（比如历史数据里有已删掉的分类）
const Color _fallbackCategoryColor = Color(0xFF8C857B);

/// 按分类名取色。深色模式下提亮，否则在近黑底上会发闷。
///
/// 注意「其他」这个分类名在收支两边都有，会取到同一个灰 —— 这是有意的，
/// 和 [iconForCategory] 的处理方式一致，也符合"其他就该是中性色"的直觉。
Color categoryColorOf(String name, {required bool dark}) {
  final base = _categoryColors[name] ?? _fallbackCategoryColor;
  return dark ? Color.lerp(base, Colors.white, 0.22) ?? base : base;
}

/// 便捷写法：`context.categoryColor('餐饮')`
extension CategoryColorContext on BuildContext {
  Color categoryColor(String name) => categoryColorOf(
    name,
    dark: Theme.of(this).brightness == Brightness.dark,
  );
}

/// 按名字取图标；名字找不到时给个兜底，避免历史数据渲染崩掉。
IconData iconForCategory(String name) {
  for (final c in expenseCategories) {
    if (c.name == name) return c.icon;
  }
  for (final c in incomeCategories) {
    if (c.name == name) return c.icon;
  }
  return Icons.receipt_long;
}

/// 支付方式。
///
/// 存进数据库的是 [all] 里的下标，**只许往后加、不许调整已有顺序**，
/// 否则老账目的支付方式会集体错位。
class PayMethod {
  const PayMethod._();

  /// 未记录：这个字段出现之前记的账。
  /// 不在选择器里出现，界面上也不显示标签 —— 不替过去的数据瞎猜一个"微信"。
  static const unknown = -1;

  static const cash = 0;
  static const wechat = 1;
  static const alipay = 2;
  static const card = 3;
  static const other = 4;

  /// 新建账目时的默认选中项
  static const defaultMethod = wechat;

  /// 选择器里可选的全部项
  static const all = <int>[cash, wechat, alipay, card, other];

  static const labels = <int, String>{
    cash: '现金',
    wechat: '微信',
    alipay: '支付宝',
    card: '银行卡',
    other: '其他',
  };

  static const icons = <int, IconData>{
    cash: Icons.payments_outlined,
    wechat: Icons.chat_bubble_outline,
    alipay: Icons.account_balance_wallet_outlined,
    card: Icons.credit_card,
    other: Icons.more_horiz,
  };

  /// 这条账有没有记过支付方式（老数据没记过）
  static bool isRecorded(int value) => labels.containsKey(value);

  /// 名字；未记录返回空串，调用方据此决定要不要显示
  static String labelOf(int value) => labels[value] ?? '';

  static IconData iconOf(int value) => icons[value] ?? Icons.more_horiz;

  /// 兜底：未记录时用默认值，用于"点常用项直接记账"这类没得选的场景
  static int orDefault(int value) => isRecorded(value) ? value : defaultMethod;
}
