import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/budget.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/haptics.dart';

/// 账本页顶上的「本月预算」卡。
///
/// 用户要求（v1.6.15）："到账本那里搞一个月度预算……可以分几条红线，
/// 让用户自己设计，可以设计几个金额红线"。
///
/// 一共两个东西：**一个总额** + **若干条金额红线**（花到哪条就提醒一次）。
/// 都没设时只显示一行"设定月度预算"，点了就进编辑器。
class BudgetCard extends StatelessWidget {
  const BudgetCard({super.key, required this.monthExpense});

  /// 当前显示月份的实际支出
  final double monthExpense;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final plan = context.watch<SettingsProvider>().budget;
    final status = evaluateBudget(spent: monthExpense, plan: plan);
    final colors = tierSurface(p, status.level);

    return Material(
      // 用户 v1.6.18："要让**上面那个大框**变色，不只是那根条"。
      color: plan.hasPlan ? colors.bg : p.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: plan.hasPlan && status.level > 0
              ? Colors.transparent
              : p.line,
        ),
      ),
      child: InkWell(
        onTap: () => _openEditor(context, plan),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: plan.hasPlan
              ? _planBody(context, status, colors)
              : _emptyBody(context),
        ),
      ),
    );
  }

  Widget _emptyBody(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Icon(Icons.savings_outlined, size: 19, color: p.inkSoft),
        const SizedBox(width: 10),
        Text(
          '设定月度预算',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: p.ink,
          ),
        ),
        const Spacer(),
        Text(
          '超了会提醒你',
          style: TextStyle(fontSize: 12.5, color: p.inkFaint),
        ),
        const SizedBox(width: 2),
        Icon(Icons.chevron_right, size: 20, color: p.inkFaint),
      ],
    );
  }

  Widget _planBody(
    BuildContext context,
    BudgetStatus status,
    ({Color bg, Color ink, Color soft, Color accent}) colors,
  ) {
    // 进度条和刻度在深色底上要用白的，在淡底（0 档）上要用玉青那套
    final onLight = status.level == 0;
    final track = onLight
        ? (context.palette.isDark ? const Color(0xFF2C3A36) : Colors.white)
        : Colors.white.withValues(alpha: 0.25);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '本月预算',
              style: AppText.label(context).copyWith(color: colors.soft),
            ),
            const Spacer(),
            if (status.plan.total > 0)
              Text(
                '${(status.ratio * 100).clamp(0, 999).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: colors.accent,
                ),
              ),
            const SizedBox(width: 6),
            Icon(Icons.edit_outlined, size: 16, color: colors.soft),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoney(status.spent),
              style: TextStyle(
                fontSize: 24,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: colors.ink,
              ),
            ),
            if (status.plan.total > 0) ...[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '/ ${formatMoney(status.plan.total)}',
                  style: TextStyle(fontSize: 13.5, color: colors.soft),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        _Bar(
          status: status,
          color: colors.accent,
          track: track,
          tick: onLight ? Colors.black.withValues(alpha: 0.22) : Colors.black26,
        ),
        const SizedBox(height: 9),
        _StatusLine(
          status: status,
          color: colors.accent,
          soft: colors.soft,
        ),
      ],
    );
  }

  Future<void> _openEditor(BuildContext context, BudgetPlan plan) async {
    Haptics.tap();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: _BudgetSheet(plan: plan),
      ),
    );
  }
}

/// 五档强调色（进度条、百分比、底部那行图标用）。
///
/// 这是**语义色**，不走 `palette` —— 调色板里没有"黄"，而且这几档要的是
/// "一眼看出严重程度"，跟主题色追求的东西不一样。
Color tierBarColor(AppPalette p, int level) => switch (level) {
  0 => p.jade,
  1 => const Color(0xFFD4A017), // 黄
  2 => const Color(0xFFE0761A), // 橙
  3 => const Color(0xFFC62828), // 红
  _ => const Color(0xFF141414), // 黑
};

/// 每一档的**整卡配色**（用户 v1.6.18："要让上面那个大框变色，不只是那根条"）。
///
/// · **0 档（绿）故意做成淡的**：它上面紧挨着那张深绿的「本月结余」卡，
///   两张同色深卡糊在一起就没有层次了；而且"变脸"从跨第一条红线才开始，
///   那一下才够醒目。
/// · **1~4 档是实心深色 + 白字**：色值都压深了一档，保证白字在任何一档都读得清
///   （纯黄配白字是看不清的）。
({Color bg, Color ink, Color soft, Color accent}) tierSurface(
  AppPalette p,
  int level,
) => switch (level) {
  0 => (
    bg: p.isDark ? const Color(0xFF1B2C27) : const Color(0xFFE7F0ED),
    ink: p.ink,
    soft: p.inkSoft,
    accent: p.jade,
  ),
  1 => (
    bg: const Color(0xFF8A6A12),
    ink: Colors.white,
    soft: Colors.white70,
    accent: Colors.white,
  ),
  2 => (
    bg: const Color(0xFFA9550F),
    ink: Colors.white,
    soft: Colors.white70,
    accent: Colors.white,
  ),
  3 => (
    bg: const Color(0xFF9E2323),
    ink: Colors.white,
    soft: Colors.white70,
    accent: Colors.white,
  ),
  _ => (
    bg: const Color(0xFF121212),
    ink: Colors.white,
    soft: Colors.white70,
    accent: Colors.white,
  ),
};

/// 进度条 + 红线刻度。
/// 刻度位置按 [BudgetStatus.barMax] 算（不是按总额），这样"红线比总额大"
/// 或者"已经花超了"的时候，条不会被切掉。
class _Bar extends StatelessWidget {
  const _Bar({
    required this.status,
    required this.color,
    required this.track,
    required this.tick,
  });

  final BudgetStatus status;
  final Color color;
  final Color track;
  final Color tick;

  @override
  Widget build(BuildContext context) {
    final max = status.barMax;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final filled = max <= 0 ? 0.0 : (status.spent / max).clamp(0.0, 1.0) * w;
        return SizedBox(
          height: 8,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: track,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: filled,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              for (final tier in status.plan.tiers)
                Positioned(
                  left: (tier / max) * w - 1,
                  child: Container(width: 2, height: 8, color: tick),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 卡底那一行文字：剩多少 / 超多少 / 下一条红线还有多远
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.status,
    required this.color,
    required this.soft,
  });

  final BudgetStatus status;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    final String text;
    if (status.farOverBudget) {
      // 超了一成以上：别再说什么"还剩多少"
      text = '已超预算 ${formatMoney(-status.remaining)}，超出一成了';
    } else if (status.overBudget) {
      text = '已超预算 ${formatMoney(-status.remaining)}';
    } else if (status.crossed > 0) {
      text = '已过 ${status.crossed} 条红线'
          '${status.plan.total > 0 ? ' · 还剩 ${formatMoney(status.remaining)}' : ''}';
    } else if (status.nextTier != null) {
      final gap = status.nextTier! - status.spent;
      text = '离第一条红线还有 ${formatMoney(gap)}';
    } else {
      text = '还剩 ${formatMoney(status.remaining)}';
    }
    final icon = switch (status.level) {
      4 => Icons.dangerous_outlined,
      3 => Icons.error_outline,
      2 => Icons.warning_amber_rounded,
      1 => Icons.warning_amber_rounded,
      _ => Icons.check_circle_outline,
    };
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        if (status.plan.tiers.isNotEmpty)
          Text(
            '红线 ${status.plan.tiers.map(_compact).join(' / ')}',
            style: TextStyle(fontSize: 11.5, color: soft),
          ),
      ],
    );
  }

  static String _compact(double v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(0);
}

/// 预算编辑器：上面是总额，下面是**用户自己加的那几条红线**。
class _BudgetSheet extends StatefulWidget {
  const _BudgetSheet({required this.plan});

  final BudgetPlan plan;

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late final TextEditingController _total;
  late final List<TextEditingController> _tiers;

  @override
  void initState() {
    super.initState();
    _total = TextEditingController(
      text: widget.plan.total > 0 ? _plain(widget.plan.total) : '',
    );
    _tiers = widget.plan.tiers
        .map((v) => TextEditingController(text: _plain(v)))
        .toList();
    if (_tiers.isEmpty) _tiers.add(TextEditingController());
  }

  @override
  void dispose() {
    _total.dispose();
    for (final c in _tiers) {
      c.dispose();
    }
    super.dispose();
  }

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _save() async {
    final total = double.tryParse(sanitizeAmountInput(_total.text)) ?? 0;
    final tiers = <double>[];
    for (final c in _tiers) {
      final v = double.tryParse(sanitizeAmountInput(c.text)) ?? 0;
      if (v > 0) tiers.add(v);
    }
    await context.read<SettingsProvider>().setBudget(
      BudgetPlan(total: total, tiers: tiers),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('月度预算', style: AppText.sectionTitle(context)),
            const SizedBox(height: 4),
            Text(
              '设一个总额，再加几条红线 —— 花到哪条就给你个提醒',
              style: AppText.label(context),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('本月预算总额'),
            _AmountField(controller: _total, hint: '比如 3000，留空就是不设'),
            const SizedBox(height: 18),
            const _FieldLabel('金额红线（可加好几条）'),
            // 可能不止一屏，所以这块自己滚
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _tiers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => Row(
                  children: [
                    Expanded(
                      child: _AmountField(
                        controller: _tiers[i],
                        hint: '比如 ${(i + 1) * 1000}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '删掉这条',
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: p.inkFaint,
                      ),
                      onPressed: () => setState(() {
                        _tiers.removeAt(i).dispose();
                        if (_tiers.isEmpty) {
                          _tiers.add(TextEditingController());
                        }
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(
                  () => _tiers.add(TextEditingController()),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('加一条红线'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _save,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: AppText.label(context)),
  );
}

/// 只让输数字和小数点（复用记账那边那套清洗，口径一致）
class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(
        hintText: hint,
        prefixText: '¥ ',
        isDense: true,
      ),
    );
  }
}
