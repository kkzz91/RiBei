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
      // 单独一个点保留成 "."，是"正在敲 .5"的合法中间态
      expect(sanitizeAmountInput('.'), '.');
    });
  });
}
