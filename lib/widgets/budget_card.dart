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

    return Material(
      color: p.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: p.line),
      ),
      child: InkWell(
        onTap: () => _openEditor(context, plan),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: plan.hasPlan
              ? _planBody(context, status)
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

  Widget _planBody(BuildContext context, BudgetStatus status) {
    final p = context.palette;
    // 越过红线 → 橙；超预算 → 红；都还没到 → 玉青
    final color = status.overBudget
        ? p.danger
        : (status.crossed > 0 ? p.warn : p.jade);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('本月预算', style: AppText.label(context)),
            const Spacer(),
            if (status.plan.total > 0)
              Text(
                '${(status.ratio * 100).clamp(0, 999).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            const SizedBox(width: 6),
            Icon(Icons.edit_outlined, size: 16, color: p.inkFaint),
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
                color: p.ink,
              ),
            ),
            if (status.plan.total > 0) ...[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '/ ${formatMoney(status.plan.total)}',
                  style: TextStyle(fontSize: 13.5, color: p.inkSoft),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        _Bar(status: status, color: color),
        const SizedBox(height: 9),
        _StatusLine(status: status, color: color),
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

/// 进度条 + 红线刻度。
/// 刻度位置按 [BudgetStatus.barMax] 算（不是按总额），这样"红线比总额大"
/// 或者"已经花超了"的时候，条不会被切掉。
class _Bar extends StatelessWidget {
  const _Bar({required this.status, required this.color});

  final BudgetStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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
                  color: p.isDark ? p.jadeSoft : p.line,
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
                  child: Container(
                    width: 2,
                    height: 8,
                    color: p.isDark
                        ? Colors.black.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.9),
                  ),
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
  const _StatusLine({required this.status, required this.color});

  final BudgetStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final String text;
    if (status.overBudget) {
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
    return Row(
      children: [
        Icon(
          status.overBudget
              ? Icons.error_outline
              : (status.crossed > 0
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline),
          size: 15,
          color: color,
        ),
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
            style: TextStyle(fontSize: 11.5, color: p.inkFaint),
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
