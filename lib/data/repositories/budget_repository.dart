import 'dart:async';

import 'package:drift/drift.dart';

import '../../core/enums/transaction_type.dart';
import '../../core/helpers/calculation_helper.dart';
import '../../core/helpers/monthly_period.dart';
import '../local/database/app_database.dart';
import '../store/finance_store.dart';
import 'app_models.dart';

class BudgetRepository {
  const BudgetRepository(this._database);

  final FinanceStore _database;

  Stream<List<BudgetProgress>> watchProgress() {
    final controller = StreamController<List<BudgetProgress>>();
    List<BudgetEntry>? budgets;
    List<TransactionEntry>? transactions;
    List<CategoryEntry>? categories;
    var resetDay = 1;
    var settingsLoaded = false;

    void emit() {
      final currentBudgets = budgets;
      final currentTransactions = transactions;
      final currentCategories = categories;
      if (currentBudgets == null ||
          currentTransactions == null ||
          currentCategories == null ||
          !settingsLoaded) {
        return;
      }
      controller.add(
        _progress(
          currentBudgets,
          currentTransactions,
          currentCategories,
          resetDay,
        ),
      );
    }

    final budgetSub = _database.budgetsDao.watchAll().listen((value) {
      budgets = value;
      emit();
    });
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
      await budgetSub.cancel();
      await transactionSub.cancel();
      await categorySub.cancel();
      await settingsSub.cancel();
    };

    return controller.stream;
  }

  Future<List<BudgetProgress>> getProgress() async {
    return _progress(
      await _database.budgetsDao.getAll(),
      await _database.transactionsDao.getAll(),
      await _database.categoriesDao.getAll(),
      (await _database.appSettingsDao.getSettings())?.monthlyResetDay ?? 1,
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
  ) {
    final categoriesById = {
      for (final category in categories) category.id: category,
    };

    return [
      for (final budget in budgets)
        BudgetProgress(
          budget: budget,
          label: budget.categoryId == null
              ? 'Budget bulanan'
              : categoriesById[budget.categoryId]?.name ?? 'Kategori',
          spent: _spentForBudget(budget, transactions, resetDay),
          status: CalculationHelper.budgetStatus(
            _spentForBudget(budget, transactions, resetDay),
            budget.limitAmount,
          ),
        ),
    ];
  }

  int _spentForBudget(
    BudgetEntry budget,
    List<TransactionEntry> transactions,
    int resetDay,
  ) {
    return transactions
        .where((transaction) {
          final month = MonthlyPeriod.containing(
            transaction.date,
            resetDay,
          ).key;
          final type = TransactionType.fromValue(transaction.type);
          final categoryMatches =
              budget.categoryId == null ||
              transaction.categoryId == budget.categoryId;
          return month == budget.month &&
              type == TransactionType.expense &&
              categoryMatches;
        })
        .fold<int>(0, (total, transaction) => total + transaction.amount);
  }
}
