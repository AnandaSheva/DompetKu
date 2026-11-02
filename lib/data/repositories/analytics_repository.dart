import 'dart:async';

import '../../core/constants/category_palette.dart';
import '../../core/enums/analytics_period.dart';
import '../../core/enums/transaction_type.dart';
import '../../core/formatters/date_formatter.dart';
import '../../core/helpers/monthly_period.dart';
import '../local/database/app_database.dart';
import 'app_models.dart';

class AnalyticsRepository {
  const AnalyticsRepository(this._database);

  final AppDatabase _database;

  Stream<AnalyticsSummary> watchSummary(AnalyticsPeriod period) {
    final controller = StreamController<AnalyticsSummary>();
    List<TransactionEntry>? transactions;
    List<CategoryEntry>? categories;
    var resetDay = 1;
    var settingsLoaded = false;

    void emit() {
      final currentTransactions = transactions;
      final currentCategories = categories;
      if (currentTransactions == null ||
          currentCategories == null ||
          !settingsLoaded) {
        return;
      }
      controller.add(
        _summary(currentTransactions, currentCategories, period, resetDay),
      );
    }

    final transactionSub = _database.transactionsDao.watchAll().listen((value) {
      transactions = value;
      emit();
    });
    final categorySub = _database.categoriesDao.watchAll().listen((value) {
      categories = value;
      emit();
    });
    final settingsSub = _database.appSettingsDao.watchSettings().listen((
      value,
    ) {
      resetDay = value?.monthlyResetDay ?? 1;
      settingsLoaded = true;
      emit();
    });

    controller.onCancel = () async {
      await transactionSub.cancel();
      await categorySub.cancel();
      await settingsSub.cancel();
    };

    return controller.stream;
  }

  AnalyticsSummary _summary(
    List<TransactionEntry> transactions,
    List<CategoryEntry> categories,
    AnalyticsPeriod period,
    int resetDay,
  ) {
    final now = DateTime.now();
    final start = period.startDate(now, resetDay);
    final end = period == AnalyticsPeriod.currentMonth
        ? MonthlyPeriod.containing(now, resetDay).end
        : null;
    final categoriesById = {
      for (final category in categories) category.id: category,
    };
    final filtered = transactions
        .where(
          (item) =>
              (start == null || !item.date.isBefore(start)) &&
              (end == null || item.date.isBefore(end)),
        )
        .toList();

    return AnalyticsSummary(
      expenseByCategory: _categoryAmounts(
        filtered,
        categoriesById,
        TransactionType.expense,
      ),
      incomeByCategory: _categoryAmounts(
        filtered,
        categoriesById,
        TransactionType.income,
      ),
      dailyCashflow: _cashflowSeries(filtered, period, now, resetDay),
      weeklyExpense: _expenseBuckets(filtered, period, now, resetDay),
      topExpenses: _categoryAmounts(
        filtered,
        categoriesById,
        TransactionType.expense,
      ).take(5).toList(),
    );
  }

  List<CategoryAmount> _categoryAmounts(
    List<TransactionEntry> transactions,
    Map<int, CategoryEntry> categories,
    TransactionType type,
  ) {
    final totals = <int, int>{};
    for (final transaction in transactions) {
      if (TransactionType.fromValue(transaction.type) != type) continue;
      final categoryId = transaction.categoryId;
      if (categoryId == null) continue;
      totals[categoryId] = (totals[categoryId] ?? 0) + transaction.amount;
    }

    final items = [
      for (final entry in totals.entries)
        if (categories[entry.key] != null)
          CategoryAmount(
            label: categories[entry.key]!.name,
            amount: entry.value,
            colorValue: categories[entry.key]!.colorValue,
          ),
    ];

    items.sort((a, b) => b.amount.compareTo(a.amount));
    return items;
  }

  List<DailyCashflow> _cashflowSeries(
    List<TransactionEntry> transactions,
    AnalyticsPeriod period,
    DateTime now,
    int resetDay,
  ) {
    switch (period) {
      case AnalyticsPeriod.currentMonth:
        final start = MonthlyPeriod.containing(now, resetDay).start;
        final today = DateFormatter.startOfDay(now);
        final days = today.difference(start).inDays + 1;
        return [
          for (var index = 0; index < days; index++)
            _cashflowForRange(
              start.add(Duration(days: index)),
              start.add(Duration(days: index + 1)),
              transactions,
            ),
        ];
      case AnalyticsPeriod.last3Months:
        return _monthlyCashflow(
          transactions,
          MonthlyPeriod.shiftStart(
            MonthlyPeriod.containing(now, resetDay).start,
            -2,
            resetDay,
          ),
          now,
          resetDay,
          customCycles: true,
        );
      case AnalyticsPeriod.yearToDate:
        return _monthlyCashflow(
          transactions,
          DateTime(now.year),
          now,
          resetDay,
        );
      case AnalyticsPeriod.allTime:
        if (transactions.isEmpty) return const [];
        return _monthlyCashflow(
          transactions,
          _allTimeChartStart(transactions, now),
          now,
          resetDay,
        );
    }
  }

  List<DailyCashflow> _monthlyCashflow(
    List<TransactionEntry> transactions,
    DateTime start,
    DateTime now,
    int resetDay, {
    bool customCycles = false,
  }) {
    return [
      for (final monthStart in _monthStarts(
        start,
        now,
        resetDay,
        customCycles: customCycles,
      ))
        _cashflowForRange(
          monthStart,
          customCycles
              ? MonthlyPeriod.shiftStart(monthStart, 1, resetDay)
              : _nextMonth(monthStart),
          transactions,
        ),
    ];
  }

  DailyCashflow _cashflowForRange(
    DateTime start,
    DateTime end,
    List<TransactionEntry> transactions,
  ) {
    var income = 0;
    var expense = 0;

    for (final transaction in transactions) {
      if (transaction.date.isBefore(start) || !transaction.date.isBefore(end)) {
        continue;
      }
      switch (TransactionType.fromValue(transaction.type)) {
        case TransactionType.income:
          income += transaction.amount;
        case TransactionType.expense:
          expense += transaction.amount;
        case TransactionType.transfer:
      }
    }

    return DailyCashflow(date: start, income: income, expense: expense);
  }

  List<CategoryAmount> _expenseBuckets(
    List<TransactionEntry> transactions,
    AnalyticsPeriod period,
    DateTime now,
    int resetDay,
  ) {
    switch (period) {
      case AnalyticsPeriod.currentMonth:
        return _weeklyExpense(transactions, now, resetDay);
      case AnalyticsPeriod.last3Months:
        return _monthlyExpense(
          transactions,
          MonthlyPeriod.shiftStart(
            MonthlyPeriod.containing(now, resetDay).start,
            -2,
            resetDay,
          ),
          now,
          resetDay,
          customCycles: true,
        );
      case AnalyticsPeriod.yearToDate:
        return _monthlyExpense(transactions, DateTime(now.year), now, resetDay);
      case AnalyticsPeriod.allTime:
        if (transactions.isEmpty) return const [];
        return _monthlyExpense(
          transactions,
          _allTimeChartStart(transactions, now),
          now,
          resetDay,
        );
    }
  }

  List<CategoryAmount> _weeklyExpense(
    List<TransactionEntry> transactions,
    DateTime now,
    int resetDay,
  ) {
    final start = MonthlyPeriod.containing(now, resetDay).start;
    final buckets = <CategoryAmount>[];
    var bucketStart = start;
    var index = 1;

    while (!bucketStart.isAfter(now)) {
      final bucketEnd = bucketStart.add(const Duration(days: 7));
      buckets.add(
        _expenseForRange(bucketStart, bucketEnd, transactions, 'Minggu $index'),
      );
      bucketStart = bucketEnd;
      index += 1;
    }

    return buckets;
  }

  List<CategoryAmount> _monthlyExpense(
    List<TransactionEntry> transactions,
    DateTime start,
    DateTime now,
    int resetDay, {
    bool customCycles = false,
  }) {
    return [
      for (final monthStart in _monthStarts(
        start,
        now,
        resetDay,
        customCycles: customCycles,
      ))
        _expenseForRange(
          monthStart,
          customCycles
              ? MonthlyPeriod.shiftStart(monthStart, 1, resetDay)
              : _nextMonth(monthStart),
          transactions,
          _shortMonthLabel(monthStart),
        ),
    ];
  }

  CategoryAmount _expenseForRange(
    DateTime start,
    DateTime end,
    List<TransactionEntry> transactions,
    String label,
  ) {
    final amount = transactions
        .where(
          (transaction) =>
              !transaction.date.isBefore(start) &&
              transaction.date.isBefore(end) &&
              TransactionType.fromValue(transaction.type) ==
                  TransactionType.expense,
        )
        .fold<int>(0, (total, transaction) => total + transaction.amount);

    return CategoryAmount(
      label: label,
      amount: amount,
      colorValue: CategoryPalette.values[0],
    );
  }

  List<DateTime> _monthStarts(
    DateTime start,
    DateTime now,
    int resetDay, {
    bool customCycles = false,
  }) {
    final end = customCycles
        ? MonthlyPeriod.containing(now, resetDay).start
        : DateFormatter.startOfMonth(now);
    final starts = <DateTime>[];
    var cursor = customCycles
        ? MonthlyPeriod.shiftStart(start, 0, resetDay)
        : DateFormatter.startOfMonth(start);

    while (!cursor.isAfter(end)) {
      starts.add(cursor);
      cursor = customCycles
          ? MonthlyPeriod.shiftStart(cursor, 1, resetDay)
          : _nextMonth(cursor);
    }

    return starts;
  }

  DateTime _nextMonth(DateTime value) {
    return DateTime(value.year, value.month + 1);
  }

  DateTime _allTimeChartStart(
    List<TransactionEntry> transactions,
    DateTime now,
  ) {
    final earliest = transactions
        .map((transaction) => DateFormatter.startOfMonth(transaction.date))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final latestWindowStart = DateTime(now.year, now.month - 11);
    return earliest.isAfter(latestWindowStart) ? earliest : latestWindowStart;
  }

  String _shortMonthLabel(DateTime date) {
    const labels = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return labels[date.month - 1];
  }
}
