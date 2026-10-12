import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction_record.dart';
import '../providers/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/categories.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/pay_tag.dart';
import 'add_transaction_screen.dart';

/// 账本搜索：一个关键字翻出所有相关记录。
///
/// 匹配范围：备注、分类、以及金额数字（输入 12.5 能找出 12.5 元的记录）。
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final results = _query.isEmpty
        ? const <TransactionRecord>[]
        : context.watch<LedgerProvider>().search(_query);

    final expense = results
        .where((r) => r.isExpense)
        .fold<double>(0, (a, r) => a + r.amount);
    final income = results
        .where((r) => !r.isExpense)
        .fold<double>(0, (a, r) => a + r.amount);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: '搜备注、分类或金额',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintStyle: TextStyle(color: p.inkFaint, fontSize: 15),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: p.inkFaint,
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
          style: TextStyle(fontSize: 15.5, color: p.ink),
        ),
      ),
      body: _query.isEmpty
          ? const EmptyState(
              icon: Icons.search,
              title: '输入关键字开始搜索',
              hint: '备注、分类都能搜，也可以直接输金额',
            )
          : results.isEmpty
          ? const EmptyState(
              icon: Icons.search_off,
              title: '没有找到相关记录',
              hint: '换个关键字试试，或者只输金额的一部分',
            )
          : ListView(
              // 顶栏是彩色条，内容顶部留 14 不贴上去
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                // 结果汇总
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: p.jadeSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        size: 16,
                        color: p.jade,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '找到 ${results.length} 条',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                      const Spacer(),
                      if (expense > 0)
                        Text(
                          '支出 ${formatMoneyCompact(expense)}',
                          style: TextStyle(fontSize: 12, color: p.expense),
                        ),
                      if (expense > 0 && income > 0)
                        Text(
                          '  ·  ',
                          style: TextStyle(fontSize: 12, color: p.inkFaint),
                        ),
                      if (income > 0)
                        Text(
                          '收入 ${formatMoneyCompact(income)}',
                          style: TextStyle(fontSize: 12, color: p.income),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < results.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, indent: 62, endIndent: 14),
                        _ResultTile(
                          record: results[i],
                          query: _query,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  AddTransactionScreen(existing: results[i]),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.record,
    required this.query,
    required this.onTap,
  });

  final TransactionRecord record;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isExpense = record.isExpense;
    // 图标底色跟账本、记一笔保持一致（分类专属色）
    final tint = context.categoryColor(record.category);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                iconForCategory(record.category),
                size: 18,
                color: tint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Highlighted(
                    text: record.category,
                    query: query,
                    base: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        formatShortDate(record.date),
                        style: AppText.label(context).copyWith(fontSize: 11.5),
                      ),
                      if (record.note.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: _Highlighted(
                            text: record.note,
                            query: query,
                            base: AppText.label(
                              context,
                            ).copyWith(fontSize: 11.5),
                            maxLines: 1,
                          ),
                        ),
                      ],
                      if (PayMethod.isRecorded(record.payMethod)) ...[
                        const SizedBox(width: 7),
                        PayTag(method: record.payMethod, compact: true),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${isExpense ? '-' : '+'}${formatMoney(record.amount)}',
              style: AppText.amount(context).copyWith(
                color: isExpense ? p.ink : p.income,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 把命中的关键字高亮出来，让人一眼看到"为什么这条被搜出来"
class _Highlighted extends StatelessWidget {
  const _Highlighted({
    required this.text,
    required this.query,
    required this.base,
    this.maxLines,
  });

  final String text;
  final String query;
  final TextStyle base;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final lower = text.toLowerCase();
    final q = query.trim().toLowerCase();
    final index = q.isEmpty ? -1 : lower.indexOf(q);

    if (index < 0) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: base,
      );
    }

    return RichText(
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + q.length),
            style: TextStyle(
              color: p.jade,
              fontWeight: FontWeight.w800,
              backgroundColor: p.jade.withValues(alpha: 0.12),
            ),
          ),
          TextSpan(text: text.substring(index + q.length)),
        ],
      ),
    );
  }
}
