import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';
import '../theme/milestone_themes.dart';
import '../utils/haptics.dart';
import 'app_toast.dart';
import 'pressable.dart';

/// 海报详情页的外壳。**纪念日和倒计时共用**。
///
/// 版式抄的参考图 `E:\ribei\样图.jpg`：整屏海报铺满，
/// 「返回 / 编辑 / 分享」是**浮在上面**的圆角药丸按钮。
///
/// ⚠️ 按钮层在 `RepaintBoundary` **外面** ⇒ 分享出去的图里只有海报、没有按钮。
///
/// ⚠️ **没有每秒重画**（用户原话"页面数秒都来了"）：只排一个**跨零点**的定时器，
/// 到点了重画一次把天数翻过来，秒不必走。
class PosterScreen extends StatefulWidget {
  const PosterScreen({
    super.key,
    required this.poster,
    required this.style,
    required this.onEdit,
    required this.shareFileName,
    required this.shareText,
    this.editLabel = '编辑',
    this.bottomRightLabel = '背景',
  });

  /// 海报本体（自带背景图案），分享图截的就是它
  final Widget poster;

  /// 决定药丸按钮的配色和兜底背景色
  final MilestoneThemeStyle style;

  final VoidCallback onEdit;

  /// 分享的临时文件名（不含扩展名和时间戳）
  final String shareFileName;
  final String shareText;

  final String editLabel;
  final String bottomRightLabel;

  @override
  State<PosterScreen> createState() => _PosterScreenState();
}

class _PosterScreenState extends State<PosterScreen> {
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

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    Haptics.impact();

    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('海报还没渲染好');

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
        path.join(dir.path, '${widget.shareFileName}-$stamp.png'),
      );
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      image.dispose();

      if (!mounted) return;
      setState(() => _sharing = false);

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'image/png')],
          text: widget.shareText,
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
    final style = widget.style;

    return Scaffold(
      // 兜底色：极窄机型上背景图案和屏幕边缘之间也不露白
      backgroundColor: style.gradient.last,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // 海报**固定占满整屏**（这里给的是紧约束）。
              // 必须是紧约束：海报内部靠"有界高度 + MainAxisAlignment.center"
              // 把内容垂直居中，松约束下那个居中是**不生效**的（试过，内容全挤在顶上）。
              // 内容万一比屏幕还高，由海报内部的滚动兜住，不会被裁掉。
              Positioned.fill(
                child: RepaintBoundary(key: _cardKey, child: widget.poster),
              ),
              _topBar(context, style),
              _bottomBar(context, style),
            ],
          );
        },
      ),
    );
  }

  Widget _topBar(BuildContext context, MilestoneThemeStyle style) {
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
                label: widget.editLabel,
                style: style,
                filled: false,
                onTap: widget.onEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context, MilestoneThemeStyle style) {
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
                  onTap: _sharing ? null : _share,
                ),
              ),
              const SizedBox(width: 10),
              _Pill(
                icon: Icons.palette_outlined,
                label: widget.bottomRightLabel,
                style: style,
                filled: false,
                onTap: widget.onEdit,
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
/// 否则铺一层白 —— 深色主题上白得很淡、浅色主题上白得明显，两种都保证字看得清。
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: filled
              ? style.accent
              : Colors.white.withValues(alpha: style.isDark ? 0.16 : 0.58),
          borderRadius: BorderRadius.circular(26),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
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
      ),
    );
  }
}
