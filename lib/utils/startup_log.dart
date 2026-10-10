/// 启动阶段的失败记录。
///
/// `runApp` 之前出的错没有任何界面可以承载，表现就是「点开就闪退」，
/// 用户和开发者都看不到原因。这里把失败原因攒起来，等界面起来后显示出来。
class StartupLog {
  StartupLog._();

  static final List<String> problems = <String>[];

  /// 执行一步启动动作：失败不中断启动，只记下原因。
  static Future<void> guard(String label, Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      problems.add('$label 初始化失败：$error');
    }
  }

  static void record(String message) {
    final text = message.trim();
    if (text.isEmpty) return;
    problems.add(text);
  }
}
