import 'package:flutter_test/flutter_test.dart';

import 'package:dompet_sheva/data/repositories/financial_calendar.dart';

import 'helpers/financial_calendar_fixture.dart';

void main() {
  test('timestamp-based transactions use the device calendar day', () {
    final calendar = FinancialCalendarMonth.fromData(
      month: calendarNow,
      transactions: [
        calendarTransaction(
          type: 'income',
          amount: 5000,
          date: DateTime(2026, 11, 16, 0, 15).toUtc(),
        ),
      ],
      bills: [],
    );
    expect(calendar.day(16).income, 5000);
  });

  test('uses real month boundaries and includes empty and leap-year days', () {
    final february = FinancialCalendarMonth.fromData(
      month: DateTime(2024, 2, 20),
      transactions: [
        calendarTransaction(
          type: 'income',
          amount: 100,
          date: DateTime(2024, 1, 31, 23, 59),
        ),
        calendarTransaction(
          type: 'income',
          amount: 300,
          date: DateTime(2024, 2),
        ),
        calendarTransaction(
          type: 'expense',
          amount: 50,
          date: DateTime(2024, 2, 29, 23, 59, 59),
        ),
        calendarTransaction(
          type: 'expense',
          amount: 900,
          date: DateTime(2024, 3),
        ),
      ],
      bills: [],
    );
    expect(february.month, DateTime(2024, 2));
    expect(february.days, hasLength(29));
    expect(february.day(1).income, 300);
    expect(february.day(29).expense, 50);
    expect(february.day(15).transactions, isEmpty);
    expect(february.day(15).netCashflow, 0);
    expect(
      FinancialCalendarMonth.fromData(
        month: DateTime(2023, 2),
        transactions: [],
        bills: [],
      ).days,
      hasLength(28),
    );
  });

  test(
    'daily totals exclude transfers and scheduled bills and sort actual entries',
    () {
      final day = FinancialCalendarMonth.fromData(
        month: calendarNow,
        transactions: [
          calendarTransaction(
            type: 'income',
            amount: 1000000,
            date: DateTime(2026, 11, 16, 9),
          ),
          calendarTransaction(
            id: 2,
            type: 'expense',
            amount: 75000,
            date: DateTime(2026, 11, 16, 20),
          ),
          calendarTransaction(
            id: 3,
            type: 'transfer',
            amount: 500000,
            date: DateTime(2026, 11, 16, 10),
          ),
          calendarTransaction(
            id: 4,
            type: 'expense',
            amount: 25000,
            date: DateTime(2026, 11, 16, 20),
          ),
        ],
        bills: [calendarBill()],
      ).day(16);
      expect(day.income, 1000000);
      expect(day.expense, 100000);
      expect(day.netCashflow, 900000);
      expect(day.scheduledAmount, 250000);
      expect(day.transactions.map((entry) => entry.transaction.id), [
        4,
        2,
        3,
        1,
      ]);
      expect(day.hasIncome && day.hasExpense && day.hasTransfer, isTrue);
      expect(day.bills.single.isProjected, isFalse);
    },
  );

  test(
    'monthly schedules preserve the anchor across short months and years',
    () {
      final bill = calendarBill(due: DateTime(2023, 1, 31));
      for (final (month, expectedDay) in [
        (DateTime(2023, 2), 28),
        (DateTime(2023, 3), 31),
        (DateTime(2024, 2), 29),
      ]) {
        final calendar = FinancialCalendarMonth.fromData(
          month: month,
          transactions: [],
          bills: [bill],
        );
        final occurrences = calendar.days.expand((day) => day.bills);
        expect(
          occurrences.single.date,
          DateTime(month.year, month.month, expectedDay),
        );
        expect(occurrences.single.isProjected, isTrue);
        expect(calendar.day(expectedDay).expense, 0);
      }
    },
  );

  test('weekly schedules cross a year boundary without shifting weekdays', () {
    final calendar = FinancialCalendarMonth.fromData(
      month: DateTime(2027, 1),
      transactions: [],
      bills: [calendarBill(due: DateTime(2026, 12, 28), frequency: 'weekly')],
    );
    expect(
      calendar.days.expand((day) => day.bills).map((item) => item.date.day),
      [4, 11, 18, 25],
    );
    expect(calendar.day(4).bills.single.date.weekday, DateTime.monday);
  });

  test('yearly leap-day schedules return to February 29 in leap years', () {
    final bill = calendarBill(due: DateTime(2024, 2, 29), frequency: 'yearly');
    for (final year in [2025, 2028]) {
      final calendar = FinancialCalendarMonth.fromData(
        month: DateTime(year, 2),
        transactions: [],
        bills: [bill],
      );
      expect(
        calendar.days.expand((day) => day.bills).single.date,
        DateTime(year, 2, year == 2028 ? 29 : 28),
      );
    }
  });

  test(
    'paused and not-yet-started schedules do not create past occurrences',
    () {
      final calendar = FinancialCalendarMonth.fromData(
        month: calendarNow,
        transactions: [],
        bills: [
          calendarBill(active: false),
          calendarBill(id: 2, due: DateTime(2026, 12, 16)),
        ],
      );
      expect(calendar.days.expand((day) => day.bills), isEmpty);
    },
  );

  test(
    'advanced paid schedules keep the actual expense on its payment date',
    () {
      final calendar = FinancialCalendarMonth.fromData(
        month: calendarNow,
        transactions: [
          calendarTransaction(
            type: 'expense',
            amount: 250000,
            date: DateTime(2026, 11, 18),
            note: 'Tagihan Internet rumah (2026-11-16)',
          ),
        ],
        bills: [calendarBill(due: DateTime(2026, 12, 16))],
      );
      expect(calendar.day(16).bills, isEmpty);
      expect(calendar.day(16).expense, 0);
      expect(calendar.day(18).expense, 250000);
      expect(
        calendar.day(18).transactions.single.transaction.note,
        contains('Internet rumah'),
      );
    },
  );
}
