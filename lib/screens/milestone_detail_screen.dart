import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/milestone.dart';
import '../providers/milestone_provider.dart';
import '../theme/app_theme.dart';
import '../theme/milestone_themes.dart';
import '../utils/haptics.dart';
import '../widgets/app_toast.dart';
import '../widgets/milestone_card.dart';
import 'edit_milestone_screen.dart';

/// 纪念日详情：全屏氛围卡 + 实时走动的时间 + 分享。
class MilestoneDetailScreen extends StatefulWidget {
  const MilestoneDetailScreen({super.key, required this.milestoneId});

  final int milestoneId;

  @override
  State<MilestoneDetailScreen> createState() => _MilestoneDetailScreenState();
}

class _MilestoneDetailScreenState extends State<MilestoneDetailScreen> {
  final GlobalKey _cardKey = GlobalKey();
  Timer? _ticker;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    // 每秒重画一次，让"第 N 天 / 时分秒"一直走动
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Milestone _milestone(MilestoneProvider provider) {
    for (final m in provider.items) {
      if (m.id == widget.milestoneId) return m;
    }
    return Milestone(
      title: '（已删除）',
      startDate: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  Future<void> _edit(Milestone milestone) async {
    Haptics.tap();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditMilestoneScreen(existing: milestone),
      ),
    );
  }

  Future<void> _share(Milestone milestone) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    Haptics.impact();

    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('卡片还没渲染好');

      final ratio = 1080 / boundary.size.width;
      final image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('图片编码失败');

      final dir = Directory(
        '${(await getTemporaryDirectory()).path}/ribei_share',
      );
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final stamp =
          '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}';
      final file = File(
        path.join(dir.path, '纪念日-${milestone.title}-$stamp.png'),
      );
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);

      if (!mounted) return;
      setState(() => _sharing = false);

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'image/png')],
          text: '「${milestone.title}」已经 ${milestone.elapsed.totalDays} 天',
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MilestoneProvider>();
    final milestone = _milestone(provider);
    final style = themeStyleOf(milestone.theme);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: style.gradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部操作条（浮在背景上）
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(
                  children: [
                    _RoundBtn(
                      icon: Icons.arrow_back,
                      color: style.text,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    _RoundBtn(
                      icon: Icons.edit_outlined,
                      color: style.text,
                      onTap: () => _edit(milestone),
                    ),
                    const SizedBox(width: 8),
                    _RoundBtn(
                      icon: _sharing ? Icons.hourglass_top : Icons.ios_share,
                      color: style.text,
                      onTap: _sharing ? null : () => _share(milestone),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Center(
                    child: RepaintBoundary(
                      key: _cardKey,
                      child: MilestoneCard(milestone: milestone),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}
