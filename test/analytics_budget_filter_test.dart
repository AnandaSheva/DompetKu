import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dompet_sheva/app/providers/app_providers.dart';
import 'package:dompet_sheva/app/theme/app_theme.dart';
import 'package:dompet_sheva/core/enums/analytics_period.dart';
import 'package:dompet_sheva/core/enums/budget_status.dart';
import 'package:dompet_sheva/core/formatters/date_formatter.dart';
import 'package:dompet_sheva/core/helpers/monthly_period.dart';
import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/app_models.dart';
import 'package:dompet_sheva/data/repositories/budget_repository.dart';
import 'package:dompet_sheva/data/store/finance_store.dart';
import 'package:dompet_sheva/features/analytics/analytics_page.dart';
import 'package:dompet_sheva/shared/widgets/top_toast.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  tearDown(TopToast.dismiss);

  testWidgets('period chips filter budgets and show their months', (
    tester,
  ) async {
    final repository = _TestBudgetRepository();
    await _openPage(tester, repository);

    expect(repository.requestedPeriods.last, AnalyticsPeriod.currentMonth);
    await _scrollToBudget(tester, 'Budget Aktif');
    expect(find.text('Budget Lama'), findsNothing);
    expect(
      find.text(
        MonthlyPeriod.label(MonthlyPeriod.containing(DateTime.now(), 1)),
      ),
      findsOneWidget,
    );

    await _selectPeriod(tester, 'Semua');
    expect(repository.requestedPeriods.last, AnalyticsPeriod.allTime);
    await _scrollToBudget(tester, 'Budget Lama');
    expect(find.text('Budget Aktif'), findsOneWidget);
    expect(
      find.text(DateFormatter.monthLabel(repository.previousMonth)),
      findsOneWidget,
    );

    await _selectPeriod(tester, 'Bulan ini');
    expect(repository.requestedPeriods.last, AnalyticsPeriod.currentMonth);
    await _scrollToBudget(tester, 'Budget Aktif');
    expect(find.text('Budget Lama'), findsNothing);
  });

  testWidgets(
    'empty current month keeps history available without a reset action',
    (tester) async {
      final repository = _TestBudgetRepository(hasCurrentBudget: false);
      await _openPage(tester, repository);
      await _scrollToBudget(tester, 'Belum ada budget bulan ini');
      expect(find.text('Budget Lama'), findsNothing);
      expect(find.text('Reset'), findsNothing);

      await _selectPeriod(tester, 'Semua');
      await _scrollToBudget(tester, 'Budget Lama');
      expect(find.text('Reset'), findsNothing);
    },
  );

  testWidgets('editing a historical budget preserves its original month', (
    tester,
  ) async {
    final repository = _TestBudgetRepository();
    await _openPage(tester, repository);
    await _selectPeriod(tester, 'Semua');
    await _scrollToBudget(tester, 'Budget Lama');
    await tester.tap(find.text('Budget Lama'));
    await tester.pumpAndSettle();

    final scope = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Cakupan',
    );
    expect(tester.widget<TextField>(scope).enabled, false);
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Batas budget',
      ),
      '200000',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(repository.savedId, 2);
    expect(
      repository.savedMonth,
      DateFormatter.monthKey(repository.previousMonth),
    );
    expect(repository.savedLimit, 200000);
    TopToast.dismiss();
  });
}

Future<void> _openPage(
  WidgetTester tester,
  _TestBudgetRepository repository,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final now = DateTime.now();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        budgetRepositoryProvider.overrideWithValue(repository),
        analyticsSummaryProvider.overrideWith(
          (ref) => Stream.value(
            const AnalyticsSummary(
              expenseByCategory: [],
              incomeByCategory: [],
              dailyCashflow: [],
              weeklyExpense: [],
              topExpenses: [],
            ),
          ),
        ),
        categoriesProvider.overrideWith((ref) => Stream.value([])),
        appSettingsProvider.overrideWith(
          (ref) => Stream.value(
            AppSettingEntry(
              id: 1,
              currency: 'IDR',
              themeMode: 'system',
              hideBalance: false,
              onboardingCompleted: true,
              monthlyResetDay: 1,
              createdAt: now,
              updatedAt: now,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: AnalyticsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectPeriod(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _scrollToBudget(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

class _TestBudgetRepository extends BudgetRepository {
  _TestBudgetRepository({this.hasCurrentBudget = true}) : super(_UnusedStore());

  final bool hasCurrentBudget;
  final now = DateTime.now();
  final requestedPeriods = <AnalyticsPeriod?>[];
  DateTime get previousMonth => DateTime(now.year, now.month - 1);
  int? savedId;
  String? savedMonth;
  int? savedLimit;

  @override
  Stream<List<BudgetProgress>> watchProgress({AnalyticsPeriod? period}) {
    requestedPeriods.add(period);
    return Stream.value([
      if (hasCurrentBudget) _budget(1, 'Budget Aktif', now),
      if (period != AnalyticsPeriod.currentMonth)
        _budget(2, 'Budget Lama', previousMonth),
    ]);
  }

  BudgetProgress _budget(int id, String label, DateTime month) =>
      BudgetProgress(
        budget: BudgetEntry(
          id: id,
          month: DateFormatter.monthKey(month),
          limitAmount: 100000,
          createdAt: now,
          updatedAt: now,
        ),
        label: label,
        spent: 10000,
        status: BudgetStatus.safe,
      );

  @override
  Future<void> save({
    int? id,
    int? categoryId,
    required String month,
    required int limitAmount,
  }) async {
    savedId = id;
    savedMonth = month;
    savedLimit = limitAmount;
  }
}

class _UnusedStore implements FinanceStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected storage access: ${invocation.memberName}',
  );
}
