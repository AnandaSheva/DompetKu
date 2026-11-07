import '../local/database/app_database.dart';

/// Storage boundary shared by local Drift and account-scoped Firestore.
/// Drift row objects remain the app's existing immutable value objects.
abstract interface class FinanceStore {
  TransactionsStore get transactionsDao;
  CategoriesStore get categoriesDao;
  WalletsStore get walletsDao;
  BudgetsStore get budgetsDao;
  SettingsStore get appSettingsDao;
  SeedStore get seedDao;
  BackupStore get backupDao;
  Future<T> transaction<T>(Future<T> Function() action);
  Future<List<QuickTemplateEntry>> getQuickTemplates();
  Future<void> close();
}

abstract interface class TransactionsStore {
  Stream<List<TransactionEntry>> watchAll();
  Future<List<TransactionEntry>> getAll();
  Future<TransactionEntry?> getById(int id);
  Future<int> add(TransactionEntriesCompanion entry);
  Future<void> updateEntry(TransactionEntriesCompanion entry);
  Future<int> deleteById(int id);
  Future<int> countByWallet(int walletId);
  Future<int> countByCategory(int categoryId);
}

abstract interface class CategoriesStore {
  Stream<List<CategoryEntry>> watchAll();
  Future<List<CategoryEntry>> getAll();
  Future<List<CategoryEntry>> getByType(String type);
  Future<int> countDuplicate({
    required String name,
    required String type,
    required String groupName,
    int? exceptId,
  });
  Future<int> add(CategoryEntriesCompanion entry);
  Future<void> updateEntry(CategoryEntriesCompanion entry);
  Future<int> deleteById(int id);
}

abstract interface class WalletsStore {
  Stream<List<WalletEntry>> watchAll();
  Future<List<WalletEntry>> getAll();
  Future<int> countDuplicate({required String name, int? exceptId});
  Future<int> add(WalletEntriesCompanion entry);
  Future<void> updateEntry(WalletEntriesCompanion entry);
  Future<int> deleteById(int id);
}

abstract interface class BudgetsStore {
  Stream<List<BudgetEntry>> watchAll();
  Future<List<BudgetEntry>> getAll();
  Future<BudgetEntry?> getById(int id);
  Future<int> countDuplicate({
    required String month,
    required int? categoryId,
    int? exceptId,
  });
  Future<int> add(BudgetEntriesCompanion entry);
  Future<void> updateEntry(BudgetEntriesCompanion entry);
  Future<int> deleteById(int id);
  Future<int> deleteByMonth(String month);
}

abstract interface class SettingsStore {
  Stream<AppSettingEntry?> watchSettings();
  Future<AppSettingEntry?> getSettings();
  Future<void> updateSettings(AppSettingEntriesCompanion entry);
}

abstract interface class SeedStore {
  Future<int> walletCount();
  Future<int> categoryCount();
  Future<int> settingsCount();
  Future<void> insertWallets(List<WalletEntriesCompanion> values);
  Future<void> insertCategories(List<CategoryEntriesCompanion> values);
  Future<void> insertQuickTemplates(List<QuickTemplateEntriesCompanion> values);
  Future<void> insertSettings(AppSettingEntriesCompanion value);
}

abstract interface class BackupStore {
  Future<void> clearUserData();
}
