import 'package:flutter_test/flutter_test.dart';
import 'package:ribei/utils/formatters.dart';

void main() {
  group('系统键盘输金额的清洗', () {
    test('正常数字原样保留', () {
      expect(sanitizeAmountInput('12'), '12');
      expect(sanitizeAmountInput('12.5'), '12.5');
    });

    test('只留数字和一个点', () {
      expect(sanitizeAmountInput('abc1.2.3xyz'), '1.23');
      expect(sanitizeAmountInput('12a'), '12');
    });

    test('小数最多两位', () {
      expect(sanitizeAmountInput('1.234'), '1.23');
      expect(sanitizeAmountInput('1.999'), '1.99');
    });

    test('整数最多九位', () {
      expect(sanitizeAmountInput('1234567890'), '123456789');
    });

    test('空串归 0', () {
      expect(sanitizeAmountInput(''), '0');
      expect(sanitizeAmountInput('abc'), '0');
      // 单独一个点补成 "0."，是"正在敲 0.5"的合法中间态
      expect(sanitizeAmountInput('.'), '0.');
    });

    test('去掉多余的前导 0（否则会显示成 ¥01）', () {
      // 金额框初始显示的就是 '0'，用户再敲一位就成了 "01" —— 用户实测报过
      expect(sanitizeAmountInput('01'), '1');
      expect(sanitizeAmountInput('05'), '5');
      expect(sanitizeAmountInput('007'), '7');
      expect(sanitizeAmountInput('000'), '0');
      expect(sanitizeAmountInput('0'), '0');
      // 但 '0.5' 里那个 0 不是"多余的"，要留着
      expect(sanitizeAmountInput('0.5'), '0.5');
      expect(sanitizeAmountInput('00.5'), '0.5');
      expect(sanitizeAmountInput('0005.25'), '5.25');
    });

    test('先剥前导零、再截长度，不能把有效数字截没', () {
      // 反过来做的话 "0000000001" 会被截成 9 个 0 ⇒ 金额直接变成 0
      expect(sanitizeAmountInput('0000000001'), '1');
      expect(sanitizeAmountInput('00000000001234567890'), '123456789');
    });
  });
}
