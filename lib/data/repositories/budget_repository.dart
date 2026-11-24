import 'package:drift/drift.dart';

import '../../core/enums/analytics_period.dart';
import '../../core/enums/transaction_type.dart';
import '../../core/helpers/calculation_helper.dart';
import '../../core/helpers/monthly_period.dart';
import '../../core/helpers/stream_combiner.dart';
import '../local/database/app_database.dart';
import '../store/finance_store.dart';
import 'app_models.dart';

class BudgetRepository {
  const BudgetRepository(this._database, {this.clock});

  final FinanceStore _database;
  final DateTime Function()? clock;

  Stream<List<BudgetProgress>> watchProgress({AnalyticsPeriod? period}) {
    return combineLatest<List<BudgetProgress>>(
      [
        _database.budgetsDao.watchAll(),
        _database.transactionsDao.watchAll(),
        _database.categoriesDao.watchAll(),
        _database.appSettingsDao.watchSettings(),
      ],
      (values) {
        return _progress(
          values[0] as List<BudgetEntry>,
          values[1] as List<TransactionEntry>,
          values[2] as List<CategoryEntry>,
          (values[3] as AppSettingEntry?)?.monthlyResetDay ?? 1,
          period,
        );
      },
    );
  }

  Future<List<BudgetProgress>> getProgress({AnalyticsPeriod? period}) async {
    return _progress(
      await _database.budgetsDao.getAll(),
      await _database.transactionsDao.getAll(),
      await _database.categoriesDao.getAll(),
      (await _database.appSettingsDao.getSettings())?.monthlyResetDay ?? 1,
      period,
    );
  }

  Future<void> save({
    int? id,
    int? categoryId,
    required String month,
    required int limitAmount,
  }) async {
    if (limitAmount <= 0) {
      throw ArgumentError('Masukkan nominal terlebih dahulu.');
    }
    final duplicateCount = await _database.budgetsDao.countDuplicate(
      month: month,
      categoryId: categoryId,
      exceptId: id,
    );
    if (duplicateCount > 0) {
      throw ArgumentError('Budget untuk periode ini sudah ada.');
    }
    final now = DateTime.now();
    final existing = id == null ? null : await _database.budgetsDao.getById(id);
    final companion = BudgetEntriesCompanion(
      id: id == null ? const Value.absent() : Value(id),
      categoryId: Value(categoryId),
      month: Value(month),
      limitAmount: Value(limitAmount),
      createdAt: Value(existing?.createdAt ?? now),
      updatedAt: Value(now),
    );

    if (id == null) {
      await _database.budgetsDao.add(companion);
    } else {
      await _database.budgetsDao.updateEntry(companion);
    }
  }

  Future<void> delete(int id) async {
    await _database.budgetsDao.deleteById(id);
  }

  Future<void> resetMonth(String month) async {
    await _database.budgetsDao.deleteByMonth(month);
  }

  List<BudgetProgress> _progress(
    List<BudgetEntry> budgets,
    List<TransactionEntry> transactions,
    List<CategoryEntry> categories,
    int resetDay,
    AnalyticsPeriod? period,
  ) {
    final now = clock?.call() ?? DateTime.now();
    final start = period?.startDate(now, resetDay);
    final firstMonth = start == null
        ? null
        : MonthlyPeriod.containing(start, resetDay).key;
    final currentMonth = MonthlyPeriod.containing(now, resetDay).key;
    final categoriesById = {
      for (final category in categories) category.id: category,
    };

    final spent = _expenseTotals(transactions, resetDay);

    return [
      for (final budget in budgets)
        if (firstMonth == null ||
            (budget.month.compareTo(firstMonth) >= 0 &&
                budget.month.compareTo(currentMonth) <= 0))
          BudgetProgress(
            budget: budget,
            label: budget.categoryId == null
                ? 'Budget bulanan'
                : categoriesById[budget.categoryId]?.name ?? 'Kategori',
            spent: spent.of(budget),
            status: CalculationHelper.budgetStatus(
              spent.of(budget),
              budget.limitAmount,
            ),
          ),
    ];
  }

  /// Sums expenses per budget period in one pass, so each budget is a lookup
  /// instead of a scan over every transaction.
  _ExpenseTotals _expenseTotals(
    List<TransactionEntry> transactions,
    int resetDay,
  ) {
    final byMonth = <String, int>{};
    final byMonthAndCategory = <(String, int), int>{};
    for (final transaction in transactions) {
      if (TransactionType.fromValue(transaction.type) !=
          TransactionType.expense) {
        continue;
      }
      final month = MonthlyPeriod.containing(transaction.date, resetDay).key;
      byMonth[month] = (byMonth[month] ?? 0) + transaction.amount;
      final categoryId = transaction.categoryId;
      if (categoryId != null) {
        final key = (month, categoryId);
        byMonthAndCategory[key] =
            (byMonthAndCategory[key] ?? 0) + transaction.amount;
      }
    }
    return _ExpenseTotals(byMonth, byMonthAndCategory);
  }
}

class _ExpenseTotals {
  const _ExpenseTotals(this._byMonth, this._byMonthAndCategory);

  final Map<String, int> _byMonth;
  final Map<(String, int), int> _byMonthAndCategory;

  int of(BudgetEntry budget) {
    final categoryId = budget.categoryId;
    return categoryId == null
        ? _byMonth[budget.month] ?? 0
        : _byMonthAndCategory[(budget.month, categoryId)] ?? 0;
  }
}
