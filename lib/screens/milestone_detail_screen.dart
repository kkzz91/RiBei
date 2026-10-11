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
import '../widgets/pressable.dart';
import 'edit_milestone_screen.dart';

/// 纪念日详情：整屏图案背景 + 中间一张日历纸卡片 + 一排药丸按钮。
///
/// 版式抄的参考图 `E:\ribei\样图.jpg`。
///
/// ⚠️ **不再每秒重画**（用户原话"页面数秒都来了"）。旧版挂了个
/// `Timer.periodic(1s)` 让"时分秒"一直走，代价是每秒重建整页 + 每秒重画背景图案。
/// 现在只排一个**跨零点**的定时器：天数会在零点自动翻，秒不必走。
class MilestoneDetailScreen extends StatefulWidget {
  const MilestoneDetailScreen({super.key, required this.milestoneId});

  final int milestoneId;

  @override
  State<MilestoneDetailScreen> createState() => _MilestoneDetailScreenState();
}

class _MilestoneDetailScreenState extends State<MilestoneDetailScreen> {
  final GlobalKey _cardKey = GlobalKey();
  Timer? _midnightTick;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _scheduleMidnightTick();
  }

  @override
  void dispose() {
    _midnightTick?.cancel();
    super.dispose();
  }

  /// 只在跨过零点时重画一次 —— 天数要跟着变，秒不用走。
  void _scheduleMidnightTick() {
    _midnightTick?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTick = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () {
        if (!mounted) return;
        setState(() {});
        _scheduleMidnightTick();
      },
    );
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

      // ⚠️ 不能写进 cacheDir/share_plus/ —— share_plus 自己会把要分享的文件
      // 复制进那个目录，发现文件本来就在里面会直接抛 IOException（红线 14）。
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
      // 兜底色：极窄机型上背景图案和屏幕边缘之间也不会露白
      backgroundColor: style.gradient.last,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // 海报本体（自带背景图案）——**分享图截的就是它**。
              // minHeight 撑满视口，这样图案铺满整屏；内容超出时会自然变高、可滚动。
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: MilestoneCard(milestone: milestone),
                  ),
                ),
              ),
              // 下面这两层按钮是**浮在**海报上的，不在 RepaintBoundary 里
              // ⇒ 分享出去的图里不会有按钮。
              _topBar(context, style, milestone),
              _bottomBar(context, style, milestone),
            ],
          );
        },
      ),
    );
  }

  Widget _topBar(
    BuildContext context,
    MilestoneThemeStyle style,
    Milestone milestone,
  ) {
    return Positioned(
      left: 12,
      right: 12,
      top: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              _Pill(
                icon: Icons.arrow_back,
                label: '返回',
                style: style,
                filled: false,
                onTap: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              _Pill(
                icon: Icons.edit_outlined,
                label: '编辑',
                style: style,
                filled: false,
                onTap: () => _edit(milestone),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(
    BuildContext context,
    MilestoneThemeStyle style,
    Milestone milestone,
  ) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: _Pill(
                  icon: _sharing ? Icons.hourglass_top : Icons.ios_share,
                  label: _sharing ? '生成中…' : '分享',
                  style: style,
                  filled: true,
                  onTap: _sharing ? null : () => _share(milestone),
                ),
              ),
              const SizedBox(width: 10),
              _Pill(
                icon: Icons.palette_outlined,
                label: '背景',
                style: style,
                filled: false,
                onTap: () => _edit(milestone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 参考图里那种圆角药丸按钮。
///
/// [filled] 用主题强调色打底（底色是浅色就配深字，反之配白字），
/// 否则用一层半透明底 —— 深色主题铺白、浅色主题铺白，两种都能保证字看得清。
class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.style,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final MilestoneThemeStyle style;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = filled
        ? (ThemeData.estimateBrightnessForColor(style.accent) == Brightness.dark
              ? Colors.white
              : const Color(0xFF1B1B1B))
        : style.text;

    return Pressable(
      child: Material(
        color: filled
            ? style.accent
            : Colors.white.withValues(alpha: style.isDark ? 0.14 : 0.55),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
