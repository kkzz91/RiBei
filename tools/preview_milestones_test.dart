// 把纪念日卡片按 8 套主题渲染成 PNG —— 本机没有真机，这是唯一能"看见"效果的办法。
//
// 用法（必须在 E:\ribei 目录下跑）：
//   flutter test tools/preview_milestones_test.dart
// 产物：
//   build/preview/themes.png   8 套主题拼成一张对照图
//   build/preview/one.png      单套主题按真机尺寸（390x844）渲染
//
// 为什么放在 tools/ 而不是 test/：`flutter test` 会把 test/ 下所有文件都跑一遍，
// 这个脚本每次运行都要写文件、也不该算进"单测数量"那个门槛里。
//
// ⚠️ 已知问题（不影响产物）：两个用例都跑完、PNG 也都写出来之后，
// `flutter test` 这个进程**不会自己退出**（用例本身是过的、产物是完整的，
// 只是收尾时卡住；试过在 tearDownAll 里 exit(0)，不生效）。
// 所以**别用前台同步等它**，用后台方式跑、看到产物就结束进程：
//   $p = Start-Process C:\dev\flutter\bin\flutter.bat `
//        -ArgumentList "test","tools/preview_milestones_test.dart" -PassThru -NoNewWindow
//   Start-Sleep 55            # 第一张图约 45 秒、第二张再多 20 秒左右
//   Get-ChildItem build\preview\*.png
//   $p.Kill()
// 这个脚本只用来"出图看一眼"，不参与放行门槛（`flutter test` 不会跑到它，
// 因为它不在 test/ 目录下）。
//
// 注意：flutter_test 默认字体**不含汉字**（会画成一排方块），
// 所以这里从系统里装一份中文字体进来（缺失时跳过，图案和版式照样能看）。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ribei/models/countdown_event.dart';
import 'package:ribei/models/milestone.dart';
import 'package:ribei/theme/milestone_themes.dart';
import 'package:ribei/widgets/countdown_poster.dart';
import 'package:ribei/widgets/milestone_card.dart';

const _cjkFontPath = r'C:\Windows\Fonts\Deng.ttf';

Milestone _sample(int theme, String title) {
  final start = DateTime.now().subtract(const Duration(days: 126));
  return Milestone(
    title: title,
    startDate: DateTime(start.year, start.month, start.day),
    note: '第一次见面',
    theme: theme,
    createdAt: start,
  );
}

void _log(String s) => File(
  'build/preview/run.log',
).writeAsStringSync('$s\n', mode: FileMode.append);

Future<void> _loadCjkFont() async {
  final file = File(_cjkFontPath);
  if (!file.existsSync()) {
    _log('font: 缺失，跳过');
    return;
  }
  _log('font: 开始读取'); 
  final bytes = file.readAsBytesSync();
  final loader = FontLoader('CJK')
    ..addFont(
      Future<ByteData>.value(
        ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes),
      ),
    );
  await loader.load();
  _log('font: 装载完成 ${bytes.lengthInBytes} 字节');
}

Widget _root(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(fontFamily: 'CJK', useMaterial3: true),
  home: child,
);

Future<void> _shoot(WidgetTester tester, GlobalKey key, String path) async {
  _log('shoot: pump 开始');
  // 用 pump 而不是 pumpAndSettle —— 这里没有任何动画，settle 只会白等
  await tester.pump(const Duration(milliseconds: 16));
  _log('shoot: pump 完成');
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  _log('shoot: boundary=${boundary.size} needsPaint=${boundary.debugNeedsPaint}');
  final image = await boundary.toImage(pixelRatio: 1);
  _log('shoot: toImage ${image.width}x${image.height}');
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  _log('shoot: png ${data?.lengthInBytes} 字节');
  File(path).writeAsBytesSync(data!.buffer.asUint8List());
  // 用完就释放，别让 ui.Image 挂着（实测不释放会让这个测试进程收不了尾）
  image.dispose();
  _log('shoot: 已写入 $path');
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadCjkFont();
  });

  testWidgets('8 套主题拼成一张对照图', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(780, 792));

    final key = GlobalKey();
    await tester.pumpWidget(
      _root(
        Scaffold(
          body: RepaintBoundary(
            key: key,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Wrap(
                children: [
                  for (
                    var i = 0;
                    i < milestoneThemeStyles.length;
                    i++
                  )
                    SizedBox(
                      width: 192,
                      height: 390,
                      child: FittedBox(
                        child: SizedBox(
                          width: 390,
                          height: 780,
                          child: MilestoneCard(
                            milestone: _sample(i, milestoneThemeStyles[i].label),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await _shoot(tester, key, 'build/preview/themes.png');
  });

  testWidgets('倒计时海报（同一套版式）', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));

    // 目标日放在 126 天后，和参考图那个数对上，好对比
    final target = DateTime.now().add(const Duration(days: 126));
    final key = GlobalKey();
    await tester.pumpWidget(
      _root(
        Scaffold(
          body: RepaintBoundary(
            key: key,
            child: CountdownPoster(
              event: CountdownEvent(
                title: '期末考试',
                targetDate: DateTime(target.year, target.month, target.day),
                note: '别熬夜',
                theme: MilestoneTheme.deepBlue,
                createdAt: DateTime.now(),
              ),
            ),
          ),
        ),
      ),
    );
    await _shoot(tester, key, 'build/preview/countdown.png');
  });
}
