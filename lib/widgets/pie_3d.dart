import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 饼图的一个扇区
class PieSlice {
  const PieSlice({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;
}

/// 饼的几何。单独拿出来是为了能**单测"画得下"这条不变量**（见 [Pie3D.geometryFor]）。
class PieGeometry {
  const PieGeometry({
    required this.center,
    required this.outerRadius,
    required this.padTop,
    required this.padBottom,
    required this.padSide,
  });

  /// 饼面的圆心（不是方框中心：下方还要放厚度，所以面会偏上一点）
  final Offset center;
  final double outerRadius;
  final double padTop;
  final double padBottom;
  final double padSide;
}

/// 立体饼图（甜甜圈形）。
///
/// 为什么不用 fl_chart 的 PieChart：
/// ① fl_chart 不支持真 3D；② 它的点击回调做不了"被点的扇区抬起来"，
/// 因为它每帧都按 `PieChartSectionData.radius` 重新布局，会抖。
/// 所以这一个自己画，几何和命中判定都在自己手里。
///
/// 立体感由三件事叠出来：
/// - **厚度**：同一组扇形向下逐像素平移重复填充，越往下越暗，形成挤出的侧面；
/// - **投影**：饼下方一层模糊椭圆，把饼"抬"离卡片；
/// - **高光**：饼面上盖一层左上→右下的白色斜向渐变（逐个扇区裁剪）。
///
/// 交互：点一下某扇区 → 它**外圈变粗并向外挪一点**（像抬起来）、中间显示详情；
/// 再点同一块 → 收回。长按或按住滑动也会实时切换。
///
/// 刻意**不用"整块平移出去"**做高亮：那样下方扇区会往下跑，
/// 既容易压到卡片下面的文字，观感上也像"沉下去"。改成**半径变大**就没有方向问题。
class Pie3D extends StatefulWidget {
  const Pie3D({
    super.key,
    required this.slices,
    required this.size,
    required this.centerIdle,
    required this.centerFor,
    this.holeRadius = 54,
    this.depth = 16,
  });

  final List<PieSlice> slices;

  /// 组件是正方形的，边长为 [size]
  final double size;

  /// 没选中任何扇区时，中心显示什么（一般是"总支出 + 金额"）
  final Widget centerIdle;

  /// 选中某个扇区时，中心显示什么（这一类的图标/名称/金额/占比）
  final Widget Function(PieSlice slice, int index) centerFor;

  /// 中间那个洞的半径
  final double holeRadius;

  /// 挤出厚度（像素）
  final double depth;

  /// 选中那块外圈向外长这么多（"抬起来"的主要表现）
  static const grow = 9.0;

  /// 再向外挪一点点，制造"脱开"的感觉。刻意很小，避免往下压到文字
  static const popDistance = 5.0;

  /// 高亮用的是 `easeOutBack`，会过冲（大约到 1.09）。
  /// 留边距时按 1.1 算，才不会因为"弹过头"而越界。
  static const overshoot = 1.1;

  /// 高亮时外圈最多外扩多少（含过冲）
  static const maxHighlight = (grow + popDistance) * overshoot;

  /// 按给定的尺寸算出饼的几何。
  ///
  /// **公开是为了能单测下面这条不变量**：饼面 + 挤出厚度 + 高亮外扩 + 投影
  /// 全部必须落在方框之内。曾经就是这里没留够 —— 底部扇区一被选中就画到框外，
  /// 压到了卡片下面的那行说明文字。
  static PieGeometry geometryFor({
    required double size,
    required double depth,
  }) {
    final padTop = maxHighlight + 3;
    // 下方还要多让出一层"挤出的厚度"，外加投影一点位置
    final padBottom = depth + maxHighlight + 6;
    final padSide = maxHighlight + 3;
    final radius = math.min(
      (size - padTop - padBottom) / 2,
      (size - 2 * padSide) / 2,
    );
    return PieGeometry(
      // 面心放在上边距之下一个半径处：这样"面 + 下方厚度"整体是居中的
      center: Offset(size / 2, padTop + radius),
      outerRadius: radius,
      padTop: padTop,
      padBottom: padBottom,
      padSide: padSide,
    );
  }

  /// 命中测试：点 [point] 落在哪个扇区；不在饼上返回 -1。
  ///
  /// 纯函数（不依赖任何 widget 状态），所以能直接写单元测试。
  /// 角度约定和绘制一致：从 12 点钟方向开始、顺时针增长。
  static int hitTestSlice({
    required Offset point,
    required Offset center,
    required double outerRadius,
    required double innerRadius,
    required List<double> sweeps,
    double startDegrees = -90,
  }) {
    if (sweeps.isEmpty) return -1;
    final delta = point - center;
    final dist = delta.distance;
    // 洞里面、或者饼外面
    if (dist < innerRadius || dist > outerRadius) return -1;

    final degrees = math.atan2(delta.dy, delta.dx) * 180 / math.pi;
    var relative = (degrees - startDegrees) % 360;
    if (relative < 0) relative += 360;

    var acc = 0.0;
    for (var i = 0; i < sweeps.length; i++) {
      if (relative >= acc && relative < acc + sweeps[i]) return i;
      acc += sweeps[i];
    }
    // 浮点误差导致刚好落在末尾时，算最后一块
    return sweeps.length - 1;
  }

  /// 环形扇区（甜甜圈的一块）。
  ///
  /// ⚠️ **整圈必须单独处理**：`Path.arcTo` 会把 sweep 规整到 `[0, 360)`，
  /// 传 360°（2π）等于传 0° —— **画出来是空的**，于是整个饼消失。
  /// 收入通常只有「生活费」一类、正好是整圈，就会撞上这个坑；
  /// 支出分类多所以看不出来。这里对整圈改用两个整圆 + `evenOdd` 得到圆环。
  ///
  /// 公开可见是为了能单测 —— 这个函数出过一次事，值得钉住。
  static Path ringSector(
    Offset c,
    double rOut,
    double rIn,
    double startRad,
    double sweepRad,
  ) {
    if (sweepRad >= 2 * math.pi - 1e-6) {
      return Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: c, radius: rOut))
        ..addOval(Rect.fromCircle(center: c, radius: rIn));
    }
    final path = Path();
    path.arcTo(
      Rect.fromCircle(center: c, radius: rOut),
      startRad,
      sweepRad,
      true,
    );
    path.arcTo(
      Rect.fromCircle(center: c, radius: rIn),
      startRad + sweepRad,
      -sweepRad,
      false,
    );
    path.close();
    return path;
  }

  @override
  State<Pie3D> createState() => _Pie3DState();
}

class _Pie3DState extends State<Pie3D> with SingleTickerProviderStateMixin {
  /// 当前选中的扇区下标，-1 表示没有
  int _selected = -1;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  late final PieGeometry _geo = Pie3D.geometryFor(
    size: widget.size,
    depth: widget.depth,
  );

  List<double> get _sweeps {
    final total = widget.slices.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) return const <double>[];
    return [for (final s in widget.slices) 360.0 * s.value / total];
  }

  @override
  void didUpdateWidget(covariant Pie3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切了支出/收入、或换了月份，扇区集合就变了 ——
    // 旧的选中下标可能指到不存在的块上，清掉重来
    final changed =
        widget.slices.length != oldWidget.slices.length ||
        (widget.slices.isNotEmpty &&
            oldWidget.slices.isNotEmpty &&
            widget.slices.first.label != oldWidget.slices.first.label);
    if (changed) {
      _controller.value = 0;
      _selected = -1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _select(int index) async {
    if (index == _selected) return;
    if (index < 0) {
      // 先收回动画，再真正清掉选中状态
      await _controller.reverse();
      if (mounted) setState(() => _selected = -1);
      return;
    }
    setState(() => _selected = index);
    _controller.forward(from: 0);
  }

  /// 点一下：点同一块就取消，点别块就切过去
  void _onTap(Offset local) {
    if (_sweeps.isEmpty) return;
    final hit = Pie3D.hitTestSlice(
      point: local,
      center: _geo.center,
      outerRadius: _geo.outerRadius,
      innerRadius: widget.holeRadius,
      sweeps: _sweeps,
    );
    _select(hit == _selected ? -1 : hit);
  }

  /// 长按 / 按住滑动：只负责选中，不做"点同一块取消"（否则滑动时会闪）
  void _forceSelect(Offset local) {
    if (_sweeps.isEmpty) return;
    final hit = Pie3D.hitTestSlice(
      point: local,
      center: _geo.center,
      outerRadius: _geo.outerRadius,
      innerRadius: widget.holeRadius,
      sweeps: _sweeps,
    );
    if (hit >= 0) _select(hit);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final selectedSlice = _selected >= 0 && _selected < widget.slices.length
        ? widget.slices[_selected]
        : null;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _onTap(d.localPosition),
        onLongPressStart: (d) => _forceSelect(d.localPosition),
        onLongPressMoveUpdate: (d) => _forceSelect(d.localPosition),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(widget.size),
              painter: _Pie3DPainter(
                slices: widget.slices,
                sweeps: _sweeps,
                selected: _selected,
                popProgress: _controller,
                center: _geo.center,
                outerRadius: _geo.outerRadius,
                innerRadius: widget.holeRadius,
                depth: widget.depth,
                surfaceColor: p.card,
                shadowAlpha: p.isDark ? 0.38 : 0.13,
              ),
            ),
            // 中心信息要对齐到饼面的圆心（不是整个方框的中心）
            Transform.translate(
              offset: Offset(0, _geo.center.dy - widget.size / 2),
              child: SizedBox(
                width: widget.holeRadius * 1.85,
                height: widget.holeRadius * 1.85,
                child: Center(
                  // 洞只有 100 出头，金额长了会撑破 —— 缩下来比截断好看
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: selectedSlice == null
                          ? KeyedSubtree(
                              key: const ValueKey<String>('idle'),
                              child: widget.centerIdle,
                            )
                          : KeyedSubtree(
                              key: ValueKey<String>('s${selectedSlice.label}'),
                              child: widget.centerFor(
                                selectedSlice,
                                _selected,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pie3DPainter extends CustomPainter {
  _Pie3DPainter({
    required this.slices,
    required this.sweeps,
    required this.selected,
    required this.popProgress,
    required this.center,
    required this.outerRadius,
    required this.innerRadius,
    required this.depth,
    required this.surfaceColor,
    required this.shadowAlpha,
  }) : super(repaint: popProgress);

  final List<PieSlice> slices;
  final List<double> sweeps;
  final int selected;
  final Animation<double> popProgress;
  final Offset center;
  final double outerRadius;
  final double innerRadius;
  final double depth;
  final Color surfaceColor;
  final double shadowAlpha;

  /// 高亮进度：`easeOutBack` 会略微过冲，看起来像"弹"出来
  double get _pop =>
      Curves.easeOutBack.transform(popProgress.value.clamp(0.0, 1.0));

  /// 选中那块的外圈半径（其余扇区不变）
  double _radiusOf(int i) =>
      i == selected ? outerRadius + Pie3D.grow * _pop : outerRadius;

  /// 选中那块向外挪一点
  Offset _offsetOf(int i, List<double> starts) {
    if (i != selected) return Offset.zero;
    final mid = starts[i] + sweeps[i] * math.pi / 360;
    return Offset(math.cos(mid), math.sin(mid)) * (Pie3D.popDistance * _pop);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0 || sweeps.length != slices.length) return;

    final starts = <double>[];
    var acc = -math.pi / 2; // 从 12 点钟开始
    for (final sweepDeg in sweeps) {
      starts.add(acc);
      acc += sweepDeg * math.pi / 180;
    }

    Path sectorAt(int k, {double? radius, Offset extra = Offset.zero}) =>
        Pie3D.ringSector(
          center + extra + _offsetOf(k, starts),
          radius ?? _radiusOf(k),
          innerRadius,
          starts[k],
          sweeps[k] * math.pi / 180,
        );

    // ---------- ① 投影 ----------
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, depth / 2 + 3),
        width: outerRadius * 2.0,
        height: outerRadius * 1.02,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: shadowAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, depth * 0.55),
    );

    // ---------- ② 侧面（挤出）----------
    // 从最底下的一层往上画，靠近饼面的层最后画、压在上面
    for (var layer = depth; layer >= 1; layer--) {
      final t = layer / depth;
      for (var k = 0; k < slices.length; k++) {
        canvas.drawPath(
          sectorAt(k, extra: Offset(0, layer)),
          Paint()
            ..color = Color.lerp(
              slices[k].color,
              Colors.black,
              0.10 + 0.28 * t,
            )!
            ..isAntiAlias = true,
        );
      }
    }

    // ---------- ③ 顶面 ----------
    // 先画没选中的，再画选中的 —— 保证抬起来的那块压在邻块上面
    for (var k = 0; k < slices.length; k++) {
      if (k == selected) continue;
      canvas.drawPath(
        sectorAt(k),
        Paint()
          ..color = slices[k].color
          ..isAntiAlias = true,
      );
    }
    if (selected >= 0 && selected < slices.length) {
      // 抬起来的那块先垫一层浅影，边界才看得清
      canvas.drawPath(
        sectorAt(selected, radius: _radiusOf(selected) + 1.5),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
          ..isAntiAlias = true,
      );
      canvas.drawPath(
        sectorAt(selected),
        Paint()
          ..color = slices[selected].color
          ..isAntiAlias = true,
      );
    }

    // 扇区之间的分隔线（用卡片底色，看起来像"切开的"）
    for (var k = 0; k < slices.length; k++) {
      canvas.drawPath(
        sectorAt(k),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = surfaceColor
          ..isAntiAlias = true,
      );
    }

    // ---------- ④ 高光 ----------
    // 逐个扇区裁剪再画渐变（而不是把路径并成一个）：
    // 整圈的圆环用的是 evenOdd，几个路径一并会互相 XOR，
    // 抬起来那块和邻块的重叠处会被挖掉一块。
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.20),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));
    for (var k = 0; k < slices.length; k++) {
      canvas.save();
      canvas.clipPath(sectorAt(k));
      canvas.drawRect(Offset.zero & size, glossPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _Pie3DPainter old) =>
      old.selected != selected ||
      old.slices != slices ||
      old.sweeps != sweeps ||
      old.surfaceColor != surfaceColor ||
      old.shadowAlpha != shadowAlpha;
}
