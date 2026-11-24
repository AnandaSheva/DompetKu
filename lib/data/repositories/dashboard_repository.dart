import '../../core/enums/transaction_type.dart';
import '../../core/helpers/calculation_helper.dart';
import '../../core/helpers/monthly_period.dart';
import '../../core/helpers/stream_combiner.dart';
import '../local/database/app_database.dart';
import '../store/finance_store.dart';
import 'app_models.dart';

class DashboardRepository {
  const DashboardRepository(this._database);

  final FinanceStore _database;

  Stream<DashboardSummary> watchSummary() {
    return combineLatest<DashboardSummary>(
      [
        _database.transactionsDao.watchAll(),
        _database.categoriesDao.watchAll(),
        _database.walletsDao.watchAll(),
        _database.budgetsDao.watchAll(),
        _database.appSettingsDao.watchSettings(),
      ],
      (values) {
        return _summary(
          transactions: values[0] as List<TransactionEntry>,
          categories: values[1] as List<CategoryEntry>,
          wallets: values[2] as List<WalletEntry>,
          budgets: values[3] as List<BudgetEntry>,
          resetDay: (values[4] as AppSettingEntry?)?.monthlyResetDay ?? 1,
        );
      },
    );
  }

  DashboardSummary _summary({
    required List<TransactionEntry> transactions,
    required List<CategoryEntry> categories,
    required List<WalletEntry> wallets,
    required List<BudgetEntry> budgets,
    required int resetDay,
  }) {
    final now = DateTime.now();
    final period = MonthlyPeriod.containing(now, resetDay);
    final monthly = transactions.where(
      (item) =>
          !item.date.isBefore(period.start) && item.date.isBefore(period.end),
    );
    final monthKey = period.key;
    final categoriesById = {
      for (final category in categories) category.id: category,
    };
    final walletsById = {for (final wallet in wallets) wallet.id: wallet};

    final activeWallets = wallets.where((wallet) => wallet.deletedAt == null);
    final walletBalances = CalculationHelper.walletBalances(
      initialBalances: {
        for (final wallet in activeWallets) wallet.id: wallet.initialBalance,
      },
      transactions: transactions.map(
        (transaction) => (
          walletId: transaction.walletId,
          transferWalletId: transaction.transferWalletId,
          type: transaction.type,
          amount: transaction.amount,
        ),
      ),
    ).values;

    final monthlyIncome = monthly
        .where(
          (item) =>
              TransactionType.fromValue(item.type) == TransactionType.income,
        )
        .fold<int>(0, (total, item) => total + item.amount);
    final monthlyExpense = monthly
        .where(
          (item) =>
              TransactionType.fromValue(item.type) == TransactionType.expense,
        )
        .fold<int>(0, (total, item) => total + item.amount);

    final currentBudgets = budgets
        .where((budget) => budget.month == monthKey)
        .toList();
    final monthlyBudgetLimit = currentBudgets
        .where((budget) => budget.categoryId == null)
        .fold<int>(0, (total, budget) => total + budget.limitAmount);
    final categoryBudgetLimitTotal = currentBudgets
        .where((budget) => budget.categoryId != null)
        .fold<int>(0, (total, budget) => total + budget.limitAmount);
    final budgetLimit = monthlyBudgetLimit > 0
        ? monthlyBudgetLimit
        : categoryBudgetLimitTotal;

    final categoryTotals = <int, int>{};
    for (final transaction in monthly) {
      if (TransactionType.fromValue(transaction.type) !=
          TransactionType.expense) {
        continue;
      }
      final categoryId = transaction.categoryId;
      if (categoryId == null) continue;
      categoryTotals[categoryId] =
          (categoryTotals[categoryId] ?? 0) + transaction.amount;
    }

    final topCategoryId = categoryTotals.entries.isEmpty
        ? null
        : categoryTotals.entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key;

    return DashboardSummary(
      totalBalance: walletBalances.fold<int>(0, (total, item) => total + item),
      monthlyIncome: monthlyIncome,
      monthlyExpense: monthlyExpense,
      netCashflow: monthlyIncome - monthlyExpense,
      walletCount: walletBalances.length,
      budgetLimit: budgetLimit,
      budgetSpent: monthlyExpense,
      budgetCount: currentBudgets.length,
      hasMonthlyBudget: monthlyBudgetLimit > 0,
      categoryBudgetLimitTotal: categoryBudgetLimitTotal,
      monthlyPeriodLabel: MonthlyPeriod.label(period),
      topExpenseCategory: categoriesById[topCategoryId]?.name,
      recentTransactions: [
        for (final transaction in transactions.take(5))
          if (walletsById[transaction.walletId] != null)
            TransactionDetail(
              transaction: transaction,
              category: categoriesById[transaction.categoryId],
              wallet: walletsById[transaction.walletId]!,
              transferWallet: walletsById[transaction.transferWalletId],
            ),
      ],
    );
  }
}
