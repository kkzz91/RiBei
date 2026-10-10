"""补上「公历 → 农历月/日」的反推，并接进新建倒计时页面。"""
import io

LUNAR = r'E:\ribei\lib\utils\lunar_date.dart'
SCREEN = r'E:\ribei\lib\screens\add_countdown_screen.dart'

FROM_SOLAR = """  /// 公历 → 农历月/日。月为负表示闰月。
  ///
  /// 用户在公历模式下选了一个日期时，用这个给出农历字段的合理起点。
  static (int, int) fromSolar(DateTime solarDate) {
    try {
      final lunar = Lunar.fromDate(
        DateTime(solarDate.year, solarDate.month, solarDate.day),
      );
      return (lunar.getMonth(), lunar.getDay());
    } catch (_) {
      return (1, 1);
    }
  }

  /// 公历 → 农历，用于在界面上标注「= 农历八月十五」"""

SCREEN_INIT_OLD = """    // 农历字段：老数据没有就按当前选择的公历日期反推
    if (e != null && e.isLunar) {
      _lunarMonth = e.lunarMonth;
      _lunarDay = e.lunarDay;
    } else {
      final lunar = LunarDate.describe(_date);
      _lunarMonth = 1;
      _lunarDay = 1;
      // 反推月/日，失败就用默认
      final parts = _guessLunar(_date);
      _lunarMonth = parts.$1;
      _lunarDay = parts.$2;
      if (lunar.isEmpty) {
        // 忽略：仅用于初始化
      }
    }
  }

  /// 用 lunar 包把这个公历日反推成农历月/日
  static (int, int) _guessLunar(DateTime solar) {
    try {
      // 借 nextOccurrence 的逆运算：直接用 LunarDate.describe 拿不到数字，
      // 所以这里通过构造一次 Lunar 来取
      final midnight = DateTime(solar.year, solar.month, solar.day);
      final desc = LunarDate.describe(midnight);
      if (desc.isEmpty) return (1, 1);
      // describe 返回「八月十五」这种形式，无法直接解析成数字，
      // 因此改用保守默认值，用户可自行调整
      return (1, 1);
    } catch (_) {
      return (1, 1);
    }
  }"""

SCREEN_INIT_NEW = """    // 农历字段：老数据没有就从当前公历日期反推，给用户一个合理起点
    if (e != null && e.isLunar) {
      _lunarMonth = e.lunarMonth;
      _lunarDay = e.lunarDay;
    } else {
      final (month, day) = LunarDate.fromSolar(_date);
      _lunarMonth = month;
      _lunarDay = day;
    }
  }"""

SCREEN_SYNC_OLD = """  /// 公历改了以后，农历字段跟着变（让用户有个合理的起点）
  void _syncLunarFromSolar(DateTime solar) {
    // LunarDate 只提供了「描述」，这里用月/日近似：拿不到就保持原值
    final desc = LunarDate.describe(solar);
    if (desc.isEmpty) return;
    // 不解析文本，交给用户在下拉里选；这里只保证 lunar 模式有合法值
  }"""

SCREEN_SYNC_NEW = """  /// 公历改了以后，农历字段跟着变（给用户一个合理起点）
  void _syncLunarFromSolar(DateTime solar) {
    final (month, day) = LunarDate.fromSolar(solar);
    _lunarMonth = month;
    _lunarDay = day;
  }"""


def patch(path, pairs, label):
    with io.open(path, encoding='utf-8') as f:
        src = f.read()
    for i, (old, new) in enumerate(pairs, 1):
        n = src.count(old)
        if n != 1:
            print('  !! %s 规则 %d 命中 %d 次' % (label, i, n))
            continue
        src = src.replace(old, new, 1)
        print('  == %s 规则 %d ok' % (label, i))
    with io.open(path, 'w', encoding='utf-8') as f:
        f.write(src)


patch(
    LUNAR,
    [("  /// 公历 → 农历，用于在界面上标注「= 农历八月十五」", FROM_SOLAR)],
    'lunar_date',
)
patch(
    SCREEN,
    [
        (SCREEN_INIT_OLD, SCREEN_INIT_NEW),
        (SCREEN_SYNC_OLD, SCREEN_SYNC_NEW),
    ],
    'add_countdown',
)
