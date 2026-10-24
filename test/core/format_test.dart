import 'package:flutter_test/flutter_test.dart';
import 'package:musir/core/utils/format.dart';

void main() {
  test('formatDuration', () {
    expect(formatDuration(Duration.zero), '0:00');
    expect(formatDuration(const Duration(seconds: 65)), '1:05');
    expect(
      formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
    expect(formatDuration(const Duration(seconds: -5)), '0:00');
  });

  test('formatTotalDuration', () {
    expect(formatTotalDuration(const Duration(seconds: 30)), '30 sec');
    expect(formatTotalDuration(const Duration(minutes: 42)), '42 min');
    expect(formatTotalDuration(const Duration(hours: 1)), '1 hr');
    expect(
      formatTotalDuration(const Duration(hours: 1, minutes: 5)),
      '1 hr 5 min',
    );
  });

  test('pluralize', () {
    expect(pluralize(1, 'song'), '1 song');
    expect(pluralize(2, 'song'), '2 songs');
  });
}
