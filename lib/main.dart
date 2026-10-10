import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/countdown_provider.dart';
import 'providers/ledger_provider.dart';
import 'providers/milestone_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/todo_provider.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'utils/haptics.dart';
import 'utils/startup_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 未捕获异常不要静默吞掉，记下来，界面起来后显示。
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    StartupLog.record(details.exceptionAsString());
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    StartupLog.record('$error');
    return true;
  };

  // 启动期每一步都隔离失败：任何一步挂了也只是降级，绝不让 App 直接闪退。
  await StartupLog.guard('日期本地化', () => initializeDateFormatting('zh_CN'));
  await StartupLog.guard('通知服务', NotificationService.instance.init);

  runApp(const RibeiApp());
}

class RibeiApp extends StatelessWidget {
  const RibeiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => LedgerProvider()..load()),
        ChangeNotifierProvider(create: (_) => CountdownProvider()..load()),
        ChangeNotifierProvider(create: (_) => TodoProvider()..load()),
        ChangeNotifierProvider(create: (_) => MilestoneProvider()..load()),
      ],
      // MultiProvider 的 child 读不到它上面刚注册的 Provider，
      // 所以主题相关的东西必须放到下一层。
      child: const _ThemedApp(),
    );
  }
}

class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    // 触感开关/强度同步给静态入口，避免每个调用点都要传 context。
    Haptics.enabled = settings.hapticsEnabled;
    Haptics.strength = settings.hapticStrength;

    return MaterialApp(
      title: '日贝',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      // 首次启动先过一遍说明页（重点是"提醒要手动开权限"）。
      // 偏好还没读出来时先给一个空壳，避免先闪一下主界面再跳教程。
      home: !settings.ready
          ? const _Splash()
          : settings.onboardingSeen
          ? const MainShell()
          : const OnboardingScreen(),
      // 启动出错时在顶部挂一条醒目提示，方便截图反馈
      builder: (context, child) {
        if (StartupLog.problems.isEmpty) return child!;
        return Column(
          children: [
            Container(
              width: double.infinity,
              color: context.palette.danger,
              padding: EdgeInsets.fromLTRB(
                14,
                MediaQuery.paddingOf(context).top + 10,
                14,
                10,
              ),
              child: Text(
                '⚠ 启动异常，请截图反馈\n${StartupLog.problems.join('\n')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
            ),
            Expanded(child: child!),
          ],
        );
      },
    );
  }
}

/// 偏好读出来之前的极简启动壳。
///
/// 之前首页是"直接进主界面"，冷启动时会先画一帧没数据的页面。
/// 现在只是等几十毫秒，画个品牌名即可。
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [p.jade, p.jadeDeep],
                ),
                borderRadius: BorderRadius.circular(19),
              ),
              child: const Icon(
                Icons.hourglass_bottom_rounded,
                color: Colors.white,
                size: 29,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '日贝',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: p.ink,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
