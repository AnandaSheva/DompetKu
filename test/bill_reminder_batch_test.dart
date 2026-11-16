import 'package:flutter_test/flutter_test.dart';

import 'package:dompet_sheva/data/notifications/bill_reminder_batch.dart';

import 'helpers/financial_calendar_fixture.dart';

void main() {
  test('only active next-unpaid bills on H-1 and H are selected', () {
    final batches = BillReminderBatch.forDay(
      bills: [
        calendarBill(due: DateTime(2026, 11, 16, 22)),
        calendarBill(id: 2, due: DateTime(2026, 11, 17), frequency: 'weekly'),
        calendarBill(id: 3, due: DateTime(2026, 11, 16), active: false),
        calendarBill(id: 4, due: DateTime(2026, 11, 15)),
        calendarBill(id: 5, due: DateTime(2026, 11, 18)),
      ],
      now: calendarNow,
      dataset: 'main',
    );
    expect(batches.map((item) => item.phase), ['today', 'tomorrow']);
    expect(batches.every((item) => item.keys.length == 1), isTrue);
    expect(batches.every((item) => item.day == '2026-11-16'), isTrue);
  });

  test('reminders follow real calendar boundaries including leap days', () {
    for (final (now, due) in [
      (DateTime(2026, 12, 31, 23, 59), DateTime(2027, 1, 1)),
      (DateTime(2024, 2, 28), DateTime(2024, 2, 29)),
      (DateTime(2023, 2, 28), DateTime(2023, 3, 1)),
    ]) {
      final batches = BillReminderBatch.forDay(
        bills: [calendarBill(due: due)],
        now: now,
        dataset: 'main',
      );
      expect(batches.single.phase, 'tomorrow');
    }
  });

  test(
    'tokens preserve occurrence identity and separate phase, dataset and account',
    () {
      final bill = calendarBill(due: DateTime(2026, 11, 17));
      BillReminderBatch batch(DateTime now, String dataset) =>
          BillReminderBatch.forDay(
            bills: [bill],
            now: now,
            dataset: dataset,
          ).single;
      final tomorrow = batch(calendarNow, 'main');
      final reordered = BillReminderBatch.forDay(
        bills: [bill, bill],
        now: calendarNow,
        dataset: 'main',
      ).single;
      expect(reordered.keys, tomorrow.keys);
      expect(batch(DateTime(2026, 11, 17), 'main').keys, isNot(tomorrow.keys));
      expect(batch(calendarNow, 'restored').keys, isNot(tomorrow.keys));
      expect(
        billReminderAccountKey('alice'),
        isNot(billReminderAccountKey('bob')),
      );
      final json = tomorrow.toJson(
        accountKey: billReminderAccountKey('alice'),
        revision: 1,
      );
      expect(json, isNot(contains('Internet rumah')));
      expect(json, isNot(contains('250000')));
      expect(json, isNot(contains('alice')));
    },
  );

  test('paid/skipped next periods do not generate reminder projections', () {
    final batches = BillReminderBatch.forDay(
      bills: [calendarBill(due: DateTime(2026, 12, 16))],
      now: calendarNow,
      dataset: 'main',
    );
    expect(batches, isEmpty);
  });
}
