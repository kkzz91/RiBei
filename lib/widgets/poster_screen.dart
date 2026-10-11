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
/// 版式抄的参考图 `E:\ribei\样图.jpg`：整屏海报铺满，左上角一个**返回箭头**，
/// 「分享 / 背景 / 编辑」三个**小药丸**贴在卡片下沿（参考图就是放在卡片下面）。
///
/// ⚠️ 那排按钮是**海报的一部分**（所以永远紧贴卡片、不会错位），
/// 但**分享截图时会临时隐藏**（`_capturing`）：分享出去的图里只有海报本身。
///
/// ⚠️ 海报**必须有界约束**：这里用 `Positioned.fill` 给的是紧约束。
/// 千万别在外面套 `SingleChildScrollView` / `ConstrainedBox(minHeight)` ——
/// `Stack` 拿到无界约束时 `size` 会变成无限大，背景图案的循环就永远转不完，
/// **release 下整个 App 卡死**（见红线 28 ④，踩过一次）。
///
/// ⚠️ **没有每秒重画**（用户原话"页面数秒都来了"）：只排一个**跨零点**的定时器。
class PosterScreen extends StatefulWidget {
  const PosterScreen({
    super.key,
    required this.style,
    required this.posterBuilder,
    required this.onEdit,
    required this.shareFileName,
    required this.shareText,
  });

  /// 决定按钮和返回箭头的配色、以及兜底背景色
  final MilestoneThemeStyle style;

  /// 拼出海报本体。第二个参数就是那排按钮：
  /// **分享截图时会传 null**（图里不要按钮），平时是排好的小药丸。
  final Widget Function(BuildContext context, Widget? actions) posterBuilder;

  final VoidCallback onEdit;

  /// 分享的临时文件名（不含扩展名和时间戳）
  final String shareFileName;
  final String shareText;

  @override
  State<PosterScreen> createState() => _PosterScreenState();
}

class _PosterScreenState extends State<PosterScreen> {
  final GlobalKey _cardKey = GlobalKey();
  Timer? _midnightTick;
  bool _sharing = false;

  /// 正在截图 ⇒ 把按钮藏起来，别截进分享图
  bool _capturing = false;

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
    Haptics.impact();
    setState(() {
      _sharing = true;
      _capturing = true;
    });

    try {
      // 等这一帧画完（按钮已经藏掉），再去截图
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

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
          '${now.year}${two(now.month)}${two(now.day)}-${now.hour}${two(now.minute)}';
      final file = File(
        path.join(dir.path, '${widget.shareFileName}-$stamp.png'),
      );
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      image.dispose();

      if (!mounted) return;
      setState(() {
        _sharing = false;
        _capturing = false;
      });

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'image/png')],
          text: widget.shareText,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sharing = false;
        _capturing = false;
      });
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
      // 兜底色：极窄机型上背景图案和屏幕边缘之间也不会露白
      backgroundColor: style.gradient.last,
      body: Stack(
        children: [
          // 海报**固定占满整屏**（这里是紧约束）。
          // 必须是紧约束：海报内部靠"有界高度"排版；松约束下海报最外层的
          // `Stack` 尺寸会变成无限大 —— release 下那是整个 App 卡死。
          Positioned.fill(
            child: RepaintBoundary(
              key: _cardKey,
              child: widget.posterBuilder(
                context,
                _capturing ? null : _actions(context, style),
              ),
            ),
          ),
          // 只有返回箭头是浮在上面的（它本来就不该进分享图）
          _backButton(context, style),
        ],
      ),
    );
  }

  /// 卡片下沿那排小药丸。参考图就是"分享 / 存为图片 / …"放在卡片下面。
  Widget _actions(BuildContext context, MilestoneThemeStyle style) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MiniPill(
          icon: Icons.ios_share,
          label: _sharing ? '生成中…' : '分享',
          style: style,
          filled: true,
          onTap: _sharing ? null : _share,
        ),
        const SizedBox(width: 8),
        _MiniPill(
          icon: Icons.palette_outlined,
          label: '背景',
          style: style,
          filled: false,
          onTap: widget.onEdit,
        ),
        const SizedBox(width: 8),
        _MiniPill(
          icon: Icons.edit_outlined,
          label: '编辑',
          style: style,
          filled: false,
          onTap: widget.onEdit,
        ),
      ],
    );
  }

  /// 左上角那个**指示箭头**（用户要求：不要"返回"两个字，就要一个箭头）。
  Widget _backButton(BuildContext context, MilestoneThemeStyle style) {
    return Positioned(
      left: 4,
      top: 0,
      child: SafeArea(
        child: Pressable(
          child: Material(
            color: Colors.black.withValues(alpha: style.isDark ? 0.24 : 0.14),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: style.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 卡片下面那排**小**药丸（比导航栏的按钮小一圈）。
class _MiniPill extends StatelessWidget {
  const _MiniPill({
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
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: fg),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
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
