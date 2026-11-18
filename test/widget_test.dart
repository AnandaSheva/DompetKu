import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dompet_sheva/app/app.dart';
import 'package:dompet_sheva/app/providers/app_providers.dart';
import 'package:dompet_sheva/app/providers/auth_providers.dart';
import 'package:dompet_sheva/app/providers/planning_providers.dart';
import 'package:dompet_sheva/app/theme/app_theme.dart';
import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/app_models.dart';
import 'package:dompet_sheva/data/repositories/security_repository.dart';
import 'package:dompet_sheva/features/dashboard/dashboard_page.dart';
import 'package:dompet_sheva/features/analytics/analytics_page.dart';
import 'package:dompet_sheva/features/settings/settings_page.dart';
import 'package:dompet_sheva/features/wallets/wallets_page.dart';
import 'package:dompet_sheva/features/security/app_lock_gate.dart';
import 'package:dompet_sheva/shared/widgets/premium_bottom_nav.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets('bottom navigation opens analytics and settings opens wallets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_withOverrides(const DompetShevaApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PremiumBottomNav), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'DompetKu',
    );
    final nav = find.byType(PremiumBottomNav);
    expect(
      find.descendant(of: nav, matching: find.text('Dompet')),
      findsNothing,
    );
    await tester.tap(find.descendant(of: nav, matching: find.text('Analitik')));
    await tester.pumpAndSettle();
    expect(find.byType(AnalyticsPage), findsOneWidget);
    expect(tester.widget<PremiumBottomNav>(nav).currentIndex, 2);
    await tester.scrollUntilVisible(find.text('Ringkasan & Budget'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Ringkasan & Budget'), findsOneWidget);

    await tester.tap(
      find.descendant(of: nav, matching: find.text('Pengaturan')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Analitik & Budget'), findsNothing);
    await tester.ensureVisible(find.text('Dompet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dompet'));
    await tester.pumpAndSettle();
    expect(find.byType(WalletsPage), findsOneWidget);
    expect(find.byTooltip('Tambah dompet'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(tester.widget<PremiumBottomNav>(nav).currentIndex, 3);
    await tester.tap(find.descendant(of: nav, matching: find.text('Analitik')));
    await tester.pumpAndSettle();
    expect(find.byType(AnalyticsPage), findsOneWidget);
  });

  testWidgets('Dashboard hierarchy renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      _withOverrides(
        MaterialApp(theme: AppTheme.light, home: const DashboardPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Total Saldo'), findsOneWidget);
    expect(find.text('DompetKu'), findsOneWidget);
    expect(find.text('Ringkasan periode'), findsOneWidget);
    expect(find.text('Riwayat terbaru'), findsOneWidget);
  });

  testWidgets(
    'native app lock covers the Navigator including notification routes',
    (tester) async {
      await tester.pumpWidget(_withOverrides(const FinanceApp(), locked: true));
      await tester.pumpAndSettle();
      final navigator = find.byType(Navigator).first;
      expect(
        find.ancestor(of: navigator, matching: find.byType(AppLockGate)),
        findsOneWidget,
      );
      tester
          .state<NavigatorState>(navigator)
          .push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const Scaffold(body: Text('Halaman dari notifikasi')),
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('Masukkan PIN untuk membuka DompetKu'), findsOneWidget);
    },
  );
}

Widget _withOverrides(Widget child, {bool locked = false}) {
  final now = DateTime(2026, 7, 2, 9);
  final settings = AppSettingEntry(
    id: 1,
    userName: null,
    currency: 'IDR',
    themeMode: 'system',
    hideBalance: false,
    onboardingCompleted: true,
    monthlyResetDay: 1,
    createdAt: now,
    updatedAt: now,
  );
  final summary = DashboardSummary(
    totalBalance: 0,
    monthlyIncome: 0,
    monthlyExpense: 0,
    netCashflow: 0,
    walletCount: 4,
    budgetLimit: 0,
    budgetSpent: 0,
    recentTransactions: const [],
    topExpenseCategory: null,
  );
  final analytics = AnalyticsSummary(
    expenseByCategory: const [],
    incomeByCategory: const [],
    dailyCashflow: [
      for (var index = 0; index < 7; index++)
        DailyCashflow(date: now, income: 0, expense: 0),
    ],
    weeklyExpense: const [],
    topExpenses: const [],
  );

  return ProviderScope(
    overrides: [
      accountPlatformProvider.overrideWithValue(false),
      appBootstrapProvider.overrideWith((ref) async {}),
      appSettingsProvider.overrideWith((ref) => Stream.value(settings)),
      dashboardSummaryProvider.overrideWith((ref) => Stream.value(summary)),
      transactionDetailsProvider.overrideWith((ref) => Stream.value([])),
      walletBalancesProvider.overrideWith((ref) => Stream.value([])),
      analyticsSummaryProvider.overrideWith((ref) => Stream.value(analytics)),
      budgetProgressProvider.overrideWith((ref) => Stream.value([])),
      categoriesProvider.overrideWith((ref) => Stream.value([])),
      recurringBillsProvider.overrideWith((ref) => Stream.value([])),
      savingsGoalsProvider.overrideWith((ref) => Stream.value([])),
      securitySettingsProvider.overrideWith(
        (ref) async => SecuritySettings(
          pinEnabled: locked,
          biometricEnabled: false,
          autoLockMinutes: 1,
          pinLength: 6,
        ),
      ),
    ],
    child: child,
  );
}
