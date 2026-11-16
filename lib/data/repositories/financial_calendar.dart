import '../../core/enums/transaction_type.dart';
import '../../core/formatters/date_formatter.dart';
import '../local/database/app_database.dart';
import 'app_models.dart';
import 'planning_repository.dart';

/// A calendar month, independent of the budget's custom monthly reset day.
class FinancialCalendarMonth {
  FinancialCalendarMonth._(this.month, this.days);

  factory FinancialCalendarMonth.fromData({
    required DateTime month,
    required List<TransactionDetail> transactions,
    required List<RecurringBillEntry> bills,
  }) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final dailyTransactions = <int, List<TransactionDetail>>{};
    final dailyBills = <int, List<CalendarBillOccurrence>>{};

    for (final detail in transactions) {
      final date = detail.transaction.date.toLocal();
      if (!date.isBefore(start) && date.isBefore(end)) {
        dailyTransactions.putIfAbsent(date.day, () => []).add(detail);
      }
    }

    for (final bill in bills) {
      if (!bill.isActive) continue;
      var due = DateFormatter.startOfDay(bill.nextDueDate);
      // Only project forward from the next unpaid occurrence. Past paid or
      // skipped occurrences cannot be reconstructed from the current schedule.
      while (due.isBefore(end)) {
        if (!due.isBefore(start)) {
          dailyBills
              .putIfAbsent(due.day, () => [])
              .add(
                CalendarBillOccurrence(
                  bill: bill,
                  date: due,
                  isProjected:
                      due != DateFormatter.startOfDay(bill.nextDueDate),
                ),
              );
        }
        due = PlanningRepository.nextDueDate(
          due,
          bill.frequency,
          bill.anchorDay,
        );
      }
    }

    final days = <FinancialCalendarDay>[];
    for (
      var number = 1;
      number <= DateTime(start.year, start.month + 1, 0).day;
      number++
    ) {
      final entries = dailyTransactions[number] ?? [];
      entries.sort((a, b) {
        final byDate = b.transaction.date.compareTo(a.transaction.date);
        return byDate != 0
            ? byDate
            : b.transaction.id.compareTo(a.transaction.id);
      });
      final occurrences = dailyBills[number] ?? [];
      occurrences.sort((a, b) => a.bill.title.compareTo(b.bill.title));
      days.add(
        FinancialCalendarDay(
          date: DateTime(start.year, start.month, number),
          transactions: List.unmodifiable(entries),
          bills: List.unmodifiable(occurrences),
        ),
      );
    }
    return FinancialCalendarMonth._(start, List.unmodifiable(days));
  }

  final DateTime month;
  final List<FinancialCalendarDay> days;

  FinancialCalendarDay day(int number) => days[number - 1];
}

class FinancialCalendarDay {
  const FinancialCalendarDay({
    required this.date,
    this.transactions = const [],
    this.bills = const [],
  });

  final DateTime date;
  final List<TransactionDetail> transactions;
  final List<CalendarBillOccurrence> bills;

  int get income => _total(TransactionType.income);
  int get expense => _total(TransactionType.expense);
  int get netCashflow => income - expense;
  int get scheduledAmount =>
      bills.fold<int>(0, (total, item) => total + item.bill.amount);
  bool get hasIncome =>
      transactions.any((item) => item.type == TransactionType.income);
  bool get hasExpense =>
      transactions.any((item) => item.type == TransactionType.expense);
  bool get hasTransfer =>
      transactions.any((item) => item.type == TransactionType.transfer);

  int _total(TransactionType type) => transactions
      .where((item) => item.type == type)
      .fold<int>(0, (total, item) => total + item.transaction.amount);
}

class CalendarBillOccurrence {
  const CalendarBillOccurrence({
    required this.bill,
    required this.date,
    required this.isProjected,
  });

  final RecurringBillEntry bill;
  final DateTime date;
  final bool isProjected;
}
