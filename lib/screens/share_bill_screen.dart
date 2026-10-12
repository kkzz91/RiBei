import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/stats.dart';
import '../providers/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/haptics.dart';
import '../widgets/app_toast.dart';
import '../widgets/bill_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/pressable.dart';

/// 分享账单：把一段时间的账目画成一张好看的图，交给系统分享面板发出去。
///
/// 输出宽度固定约 1080px（微信朋友圈、群聊里都清楚），
/// 所以截图倍率是 `1080 / 卡片实际宽度` 算出来的，不写死。
class ShareBillScreen extends StatefulWidget {
  const ShareBillScreen({super.key});

  @override
  State<ShareBillScreen> createState() => _ShareBillScreenState();
}

class _ShareBillScreenState extends State<ShareBillScreen> {
  /// 0 = 本月，1 = 自选区间
  int _mode = 0;

  late DateTime _from;
  late DateTime _to;
  bool _sharing = false;

  final _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0); // 当月最后一天
  }

  void _pickMonth() {
    final now = DateTime.now();
    setState(() {
      _mode = 0;
      _from = DateTime(now.year, now.month, 1);
      _to = DateTime(now.year, now.month + 1, 0);
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: '选择要分享的日期区间',
      saveText: '就这段',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _mode = 1;
      _from = picked.start;
      _to = picked.end;
    });
  }

  /// 把卡片渲染成 PNG，写进缓存目录，再调系统分享面板。
  ///
  /// 两个坑：
  /// ① `toImage` 用的是 RepaintBoundary 自己的布局尺寸，**不受外层缩放影响**，
  ///    所以预览可以按屏幕宽度排版，输出仍按 [pixelRatio] 放大；
  /// ② 文件**不能**写进 `cacheDir/share_plus/` —— share_plus 自己会把文件复制到
  ///    那个目录，如果发现文件本来就在里面会直接抛 IOException。
  ///    所以这里写在 `ribei_share/` 下。
  Future<void> _share(BillSummary summary) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    Haptics.impact();

    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('还没渲染好，稍后再试');
      }

      final ratio = 1080 / boundary.size.width;
      final image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('图片编码失败');

      final dir = Directory('${(await getTemporaryDirectory()).path}/ribei_share');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('${dir.path}/日贝账单_${_stamp()}.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);

      if (!mounted) return;
      setState(() => _sharing = false);

      final result = await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'image/png')],
          text: '我的记账账单 · 日贝',
        ),
      );
      if (!mounted) return;
      if (result.status == ShareResultStatus.dismissed) {
        AppToast.show(
          context,
          '已取消分享。图片也留在手机里，需要时还能再发一次',
          icon: Icons.info_outline,
          tint: context.palette.inkSoft,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _sharing = false);
      AppToast.show(
        context,
        '生成图片失败：$error',
        icon: Icons.error_outline,
        tint: context.palette.danger,
      );
    }
  }

  String _stamp() {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${_from.year}${two(_from.month)}${two(_from.day)}'
        '-${_to.year}${two(_to.month)}${two(_to.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ledger = context.watch<LedgerProvider>();
    final summary = ledger.summarize(_from, _to);

    return Scaffold(
      appBar: AppBar(title: const Text('分享账单')),
      body: ListView(
        // 顶栏是彩色条，内容顶部留 14 不贴上去（原来 0，选范围的框直接粘在顶栏上）
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          // ---------- 选范围 ----------
          Row(
            children: [
              Expanded(
                child: _RangeTab(
                  label: '本月',
                  sub: _mode == 0 ? formatDateRange(_from, _to) : null,
                  selected: _mode == 0,
                  onTap: _pickMonth,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RangeTab(
                  label: '自己选几天',
                  sub: _mode == 1 ? formatDateRange(_from, _to) : null,
                  selected: _mode == 1,
                  onTap: _pickRange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (summary.isEmpty)
            const EmptyState(
              icon: Icons.image_outlined,
              title: '这段时间没有账目',
              hint: '换个日期区间再试试，或者先去记几笔',
            )
          else ...[
            Text(
              '效果预览（发出去的就是这张）',
              style: AppText.sectionTitle(context),
            ),
            const SizedBox(height: 10),
            // 预览 = 真正要截的那块，所见即所得
            RepaintBoundary(
              key: _cardKey,
              child: BillCard(summary: summary),
            ),
            const SizedBox(height: 18),
            Pressable(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _sharing ? null : () => _share(summary),
                icon: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.ios_share, size: 19),
                label: Text(_sharing ? '正在生成图片…' : '生成图片并分享'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '会调起系统分享面板，选微信就能发朋友圈或发给朋友。'
              '图片同时留在手机里，可以再发一次。',
              style: TextStyle(fontSize: 11.5, color: p.inkFaint, height: 1.7),
            ),
          ],
        ],
      ),
    );
  }
}

class _RangeTab extends StatelessWidget {
  const _RangeTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.sub,
  });

  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      scale: 0.97,
      child: GestureDetector(
        onTap: () {
          Haptics.tap();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? p.jade : p.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? p.jade : p.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? (p.isDark ? const Color(0xFF0B1F1A) : Colors.white)
                      : p.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub ?? '点这里选起止日期',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? (p.isDark
                            ? const Color(0xFF0B1F1A).withValues(alpha: 0.72)
                            : Colors.white.withValues(alpha: 0.82))
                      : p.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
