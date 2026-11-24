import '../enums/budget_status.dart';
import '../enums/transaction_type.dart';

class CalculationHelper {
  CalculationHelper._();

  static int walletBalance({
    required int walletId,
    required int initialBalance,
    required Iterable<
      ({int walletId, int? transferWalletId, String type, int amount})
    >
    transactions,
  }) {
    var balance = initialBalance;

    for (final transaction in transactions) {
      final type = TransactionType.fromValue(transaction.type);
      switch (type) {
        case TransactionType.income:
          if (transaction.walletId == walletId) {
            balance += transaction.amount;
          }
        case TransactionType.expense:
          if (transaction.walletId == walletId) {
            balance -= transaction.amount;
          }
        case TransactionType.transfer:
          if (transaction.walletId == walletId) {
            balance -= transaction.amount;
          }
          if (transaction.transferWalletId == walletId) {
            balance += transaction.amount;
          }
      }
    }

    return balance;
  }

  /// Computes the balance of several wallets in one pass over [transactions].
  /// Equivalent to calling [walletBalance] per wallet, in O(wallets + rows).
  static Map<int, int> walletBalances({
    required Map<int, int> initialBalances,
    required Iterable<
      ({int walletId, int? transferWalletId, String type, int amount})
    >
    transactions,
  }) {
    final balances = Map<int, int>.of(initialBalances);

    void add(int? walletId, int amount) {
      final current = balances[walletId];
      if (current != null) balances[walletId!] = current + amount;
    }

    for (final transaction in transactions) {
      switch (TransactionType.fromValue(transaction.type)) {
        case TransactionType.income:
          add(transaction.walletId, transaction.amount);
        case TransactionType.expense:
          add(transaction.walletId, -transaction.amount);
        case TransactionType.transfer:
          add(transaction.walletId, -transaction.amount);
          add(transaction.transferWalletId, transaction.amount);
      }
    }

    return balances;
  }

  static BudgetStatus budgetStatus(int spent, int limit) {
    if (limit <= 0) {
      return BudgetStatus.safe;
    }

    final ratio = spent / limit;
    if (ratio >= 1) {
      return BudgetStatus.exceeded;
    }
    if (ratio >= 0.8) {
      return BudgetStatus.nearLimit;
    }
    return BudgetStatus.safe;
  }
}
