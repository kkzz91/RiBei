import 'package:flutter_test/flutter_test.dart';
import 'package:ribei/models/budget.dart';

/// 月度预算：总额 + 用户自定义的几条金额红线。
/// 这里钉的是**判定**（跨过几条线、有没有超、进度条画多长）和**存取往返**。
void main() {
  group('跨红线判定', () {
    const plan = BudgetPlan(total: 5000, tiers: <double>[2000, 3000, 4500]);

    test('没设预算时一切归零，不会除零', () {
      final s = evaluateBudget(spent: 800, plan: BudgetPlan.none);
      expect(s.hasPlan, isFalse);
      expect(s.crossed, 0);
      expect(s.ratio, 0);
      expect(s.overBudget, isFalse);
      expect(s.barMax, 800, reason: '没设预算时进度条就按实际花销画');
    });

    test('刚好等于红线不算跨过（要"超过"）', () {
      expect(evaluateBudget(spent: 2000, plan: plan).crossed, 0);
      expect(evaluateBudget(spent: 2000.01, plan: plan).crossed, 1);
    });

    test('跨过几条就是几条', () {
      expect(evaluateBudget(spent: 1999, plan: plan).crossed, 0);
      expect(evaluateBudget(spent: 2500, plan: plan).crossed, 1);
      expect(evaluateBudget(spent: 3200, plan: plan).crossed, 2);
      expect(evaluateBudget(spent: 4999, plan: plan).crossed, 3);
    });

    test('超预算要单独标出来', () {
      final s = evaluateBudget(spent: 5100, plan: plan);
      expect(s.crossed, 3);
      expect(s.overBudget, isTrue);
      expect(s.remaining, closeTo(-100, 0.001));
      expect(s.nextTier, isNull, reason: '红线都跨完了就没有下一条');
    });

    test('下一条红线是"还没跨过的最小那条"', () {
      expect(evaluateBudget(spent: 0, plan: plan).nextTier, 2000);
      expect(evaluateBudget(spent: 2500, plan: plan).nextTier, 3000);
    });

    test('进度条不能把超支的部分切掉', () {
      expect(evaluateBudget(spent: 6000, plan: plan).barMax, 6000);
      // 红线比总额大时也一样
      const bigger = BudgetPlan(total: 1000, tiers: <double>[3000]);
      expect(evaluateBudget(spent: 500, plan: bigger).barMax, 3000);
      expect(evaluateBudget(spent: 100, plan: plan).barMax, 5000);
    });

    test('进度比例按总额算', () {
      expect(evaluateBudget(spent: 2500, plan: plan).ratio, closeTo(0.5, 1e-9));
    });
  });

  group('存取往返', () {
    test('总额和红线都能原样回来，并且红线是升序', () {
      const plan = BudgetPlan(total: 5000, tiers: <double>[3000, 2000]);
      final back = BudgetPlan.decode(plan.encode());
      expect(back.total, 5000);
      expect(back.tiers, <double>[2000, 3000]);
    });

    test('整数金额不会带出 ".0" 的尾巴', () {
      expect(const BudgetPlan(total: 3000).encode(), '3000|');
      expect(
        const BudgetPlan(total: 3000.5, tiers: <double>[2000]).encode(),
        '3000.5|2000',
      );
    });

    test('只设了红线、没设总额也能用', () {
      final back = BudgetPlan.decode('0|1000,2000');
      expect(back.total, 0);
      expect(back.tiers, <double>[1000, 2000]);
      expect(back.hasPlan, isTrue);
    });

    test('空串 / 脏数据不会炸', () {
      expect(BudgetPlan.decode('').total, 0);
      expect(BudgetPlan.decode('').tiers, isEmpty);
      expect(BudgetPlan.decode('abc|def,g').tiers, isEmpty);
      // 0 和负数直接丢掉（清空一条红线就是把它设成 0）
      expect(BudgetPlan.decode('0|0,-5,100').tiers, <double>[100]);
    });
  });
}
