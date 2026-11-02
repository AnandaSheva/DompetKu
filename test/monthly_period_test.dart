import 'package:flutter_test/flutter_test.dart';

import 'package:dompet_sheva/core/helpers/monthly_period.dart';

void main() {
  test('default reset day follows calendar months', () {
    final period = MonthlyPeriod.containing(DateTime(2026, 11, 2), 1);

    expect(period.start, DateTime(2026, 11, 1));
    expect(period.end, DateTime(2026, 12, 1));
    expect(period.key, '2026-11');
  });

  test('custom reset day rolls over on the selected day', () {
    final beforeReset = MonthlyPeriod.containing(DateTime(2026, 11, 9), 10);
    final onReset = MonthlyPeriod.containing(DateTime(2026, 11, 10), 10);

    expect(beforeReset.start, DateTime(2026, 10, 10));
    expect(beforeReset.end, DateTime(2026, 11, 10));
    expect(onReset.start, DateTime(2026, 11, 10));
    expect(onReset.end, DateTime(2026, 12, 10));
  });

  test('reset day is clamped to the last day of shorter months', () {
    final period = MonthlyPeriod.containing(DateTime(2026, 2, 28), 31);

    expect(period.start, DateTime(2026, 2, 28));
    expect(period.end, DateTime(2026, 3, 31));
  });

  test('rejects reset days outside 1 through 31', () {
    expect(
      () => MonthlyPeriod.containing(DateTime(2026, 11, 2), 0),
      throwsArgumentError,
    );
    expect(
      () => MonthlyPeriod.containing(DateTime(2026, 11, 2), 32),
      throwsArgumentError,
    );
  });
}
