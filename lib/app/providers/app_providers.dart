import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/enums/analytics_period.dart';
import '../../data/local/database/app_database.dart';
import '../../data/store/finance_store.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/app_models.dart';
import '../../data/repositories/backup_repository.dart';
import '../../data/repositories/bootstrap_repository.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/security_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/update_repository.dart';
import '../../data/repositories/wallet_repository.dart';

final databaseProvider = Provider<FinanceStore>((ref) {
  final database = AppDatabase.defaults();
  ref.onDispose(database.close);
  return database;
}, dependencies: []);

final bootstrapRepositoryProvider = Provider<BootstrapRepository>((ref) {
  return BootstrapRepository(ref.watch(databaseProvider));
}, dependencies: [databaseProvider]);

final appBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(bootstrapRepositoryProvider).ensureSeeded();
}, dependencies: [bootstrapRepositoryProvider]);

final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(databaseProvider));
}, dependencies: [databaseProvider]);

final appSettingsProvider = StreamProvider<AppSettingEntry?>((ref) {
  return ref.watch(settingsRepositoryProvider).watchSettings();
}, dependencies: [settingsRepositoryProvider]);

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(databaseProvider));
}, dependencies: [databaseProvider]);

final categoriesProvider = StreamProvider<List<CategoryEntry>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAll();
}, dependencies: [categoryRepositoryProvider]);

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(databaseProvider));
}, dependencies: [databaseProvider]);

final walletBalancesProvider = StreamProvider<List<WalletBalance>>((ref) {
  return ref.watch(walletRepositoryProvider).watchWalletBalances();
}, dependencies: [walletRepositoryProvider]);

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(databaseProvider));
}, dependencies: [databaseProvider]);

final transactionDetailsProvider = StreamProvider<List<TransactionDetail>>((
  ref,
) {
  return ref.watch(transactionRepositoryProvider).watchDetails();
}, dependencies: [transactionRepositoryProvider]);

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(databaseProvider));
}, dependencies: [databaseProvider]);

final dashboardSummaryProvider = StreamProvider<DashboardSummary>((ref) {
  return ref.watch(dashboardRepositoryProvider).watchSummary();
}, dependencies: [dashboardRepositoryProvider]);

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(databaseProvider));
}, dependencies: [databaseProvider]);

final budgetProgressProvider = StreamProvider<List<BudgetProgress>>((ref) {
  return ref.watch(budgetRepositoryProvider).watchProgress();
}, dependencies: [budgetRepositoryProvider]);

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(databaseProvider));
}, dependencies: [databaseProvider]);

final analyticsPeriodProvider =
    NotifierProvider<AnalyticsPeriodController, AnalyticsPeriod>(
      AnalyticsPeriodController.new,
    );

class AnalyticsPeriodController extends Notifier<AnalyticsPeriod> {
  @override
  AnalyticsPeriod build() {
    return AnalyticsPeriod.currentMonth;
  }

  void setPeriod(AnalyticsPeriod period) {
    state = period;
  }
}

final analyticsSummaryProvider = StreamProvider<AnalyticsSummary>((ref) {
  final period = ref.watch(analyticsPeriodProvider);
  return ref.watch(analyticsRepositoryProvider).watchSummary(period);
}, dependencies: [analyticsRepositoryProvider]);

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepository(ref.watch(databaseProvider));
}, dependencies: [databaseProvider]);

final securityRepositoryProvider = Provider<SecurityRepository>((ref) {
  return SecurityRepository();
});

final securitySettingsProvider = FutureProvider<SecuritySettings>((ref) {
  return ref.watch(securityRepositoryProvider).loadSettings();
});

final updateRepositoryProvider = Provider<UpdateRepository>((ref) {
  final repository = UpdateRepository();
  ref.onDispose(repository.close);
  return repository;
});
