import io
p = r'E:\ribei\test\feature_test.dart'
src = io.open(p, encoding='utf-8').read()

old = """    test('提前天数被限制在合理范围内', () {
      expect(
        const CountdownEvent(
          title: 'x',
          targetDate: null ?? _never,
          createdAt: _never,
        ).safeLeadDays,
        3,
      );
    });"""

new = """    test('提前天数会被兜在合理范围内', () {
      final base = CountdownEvent(
        title: 'x',
        targetDate: DateTime.now().add(const Duration(days: 10)),
        createdAt: DateTime.now(),
      );
      expect(base.safeLeadDays, 3, reason: '默认就是 3 天');
      expect(base.copyWith(leadDays: 0).safeLeadDays, 1, reason: '至少 1 天');
      expect(base.copyWith(leadDays: 999).safeLeadDays, 60, reason: '上限 60 天');
      expect(base.copyWith(leadDays: 7).safeLeadDays, 7);
    });"""

n = src.count(old)
print('命中:', n)
if n == 1:
    src = src.replace(old, new, 1)
src = src.replace("\n\nfinal _never = DateTime(2000, 1, 1);\n", "\n")
io.open(p, 'w', encoding='utf-8').write(src)
print('已修复')
