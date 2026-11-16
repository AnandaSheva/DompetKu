import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dompet_sheva/app/providers/app_providers.dart';
import 'package:dompet_sheva/app/providers/planning_providers.dart';
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
    expect(tester.widget<TextField>(scope).enabled, isNot(false));
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
    expect(repository.savedCategoryId, 2);
    expect(
      repository.savedMonth,
      DateFormatter.monthKey(repository.previousMonth),
    );
    expect(repository.savedLimit, 200000);
    TopToast.dismiss();
  });

  for (final (scope, categoryId) in [
    ('Transportasi', 3),
    ('Budget bulanan', null),
  ]) {
    testWidgets('budget menu can change scope to $scope and edit its limit', (
      tester,
    ) async {
      final repository = _TestBudgetRepository();
      await _openPage(tester, repository);
      await _openBudgetMenu(tester, 'Budget Aktif');
      expect(find.text('Hapus budget'), findsOneWidget);
      await tester.tap(find.text('Edit budget'));
      await tester.pumpAndSettle();

      final scopeField = _field('Cakupan');
      expect(
        tester.widget<TextField>(scopeField).controller!.text,
        'Budget Aktif',
      );
      await tester.tap(scopeField);
      await tester.pumpAndSettle();
      await tester.enterText(
        _field('Cari cakupan'),
        scope == 'Transportasi' ? 'tRaNs' : 'bulanan',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(scope));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Batas budget'), '350000');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(repository.savedId, 1);
      expect(repository.savedCategoryId, categoryId);
      expect(repository.savedLimit, 350000);
      expect(repository.savedMonth, DateFormatter.monthKey(repository.now));
      expect(find.text('Budget berhasil diperbarui.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      TopToast.dismiss();
    });
  }

  testWidgets(
    'budget deletion requires confirmation and removes only its card',
    (tester) async {
      final repository = _TestBudgetRepository();
      await _openPage(tester, repository);
      await _selectPeriod(tester, 'Semua');
      await _openBudgetMenu(tester, 'Budget Aktif');
      await tester.tap(find.text('Hapus budget'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus budget?'), findsOneWidget);
      expect(repository.deletedIds, isEmpty);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(repository.deletedIds, isEmpty);
      expect(find.text('Budget Aktif'), findsOneWidget);

      await _openBudgetMenu(tester, 'Budget Aktif');
      await tester.tap(find.text('Hapus budget'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      expect(repository.deletedIds, [1]);
      expect(find.text('Budget Aktif'), findsNothing);
      expect(find.text('Budget Lama'), findsOneWidget);
      expect(find.text('Budget berhasil dihapus.'), findsOneWidget);
      TopToast.dismiss();
    },
  );

  testWidgets(
    'a failed budget deletion keeps the card and explains the error',
    (tester) async {
      final repository = _TestBudgetRepository(failDeletion: true);
      await _openPage(tester, repository);
      await _openBudgetMenu(tester, 'Budget Aktif');
      await tester.tap(find.text('Hapus budget'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      expect(repository.deletedIds, isEmpty);
      expect(find.text('Budget Aktif'), findsOneWidget);
      expect(
        find.text('Budget belum bisa dihapus. Coba lagi.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      TopToast.dismiss();
    },
  );

  testWidgets('a failed budget save shows an error without claiming success', (
    tester,
  ) async {
    final repository = _TestBudgetRepository(failSaving: true);
    await _openPage(tester, repository);
    await _openBudgetMenu(tester, 'Budget Aktif');
    await tester.tap(find.text('Edit budget'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(repository.savedId, isNull);
    expect(find.text('Budget belum bisa disimpan. Coba lagi.'), findsOneWidget);
    expect(find.text('Budget berhasil diperbarui.'), findsNothing);
    expect(tester.takeException(), isNull);
    TopToast.dismiss();
  });
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _openBudgetMenu(WidgetTester tester, String label) async {
  await _scrollToBudget(tester, label);
  await tester.tap(find.byTooltip('Kelola budget $label'));
  await tester.pumpAndSettle();
}

Future<void> _openPage(
  WidgetTester tester,
  _TestBudgetRepository repository,
) async {
  addTearDown(repository.close);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final now = DateTime.now();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transactionDetailsProvider.overrideWith((ref) => Stream.value([])),
        recurringBillsProvider.overrideWith((ref) => Stream.value([])),
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
        categoriesProvider.overrideWith(
          (ref) => Stream.value([
            for (final (id, name) in [
              (1, 'Budget Aktif'),
              (2, 'Budget Lama'),
              (3, 'Transportasi'),
            ])
              CategoryEntry(
                id: id,
                name: name,
                type: 'expense',
                groupName: 'Pengujian',
                iconKey: 'category',
                colorValue: 0xff2563eb,
                isDefault: false,
                isArchived: false,
                createdAt: now,
                updatedAt: now,
              ),
          ]),
        ),
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
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(label),
    250,
    scrollable: find.byType(Scrollable).first,
  );
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
  _TestBudgetRepository({
    this.hasCurrentBudget = true,
    this.failDeletion = false,
    this.failSaving = false,
  }) : super(_UnusedStore());

  final bool hasCurrentBudget;
  final bool failDeletion;
  final bool failSaving;
  final _changes = StreamController<void>.broadcast();
  final deletedIds = <int>[];
  final now = DateTime.now();
  final requestedPeriods = <AnalyticsPeriod?>[];
  DateTime get previousMonth => DateTime(now.year, now.month - 1);
  int? savedId;
  int? savedCategoryId;
  String? savedMonth;
  int? savedLimit;

  @override
  Stream<List<BudgetProgress>> watchProgress({AnalyticsPeriod? period}) async* {
    requestedPeriods.add(period);
    yield _items(period);
    yield* _changes.stream.map((_) => _items(period));
  }

  List<BudgetProgress> _items(AnalyticsPeriod? period) => [
    if (hasCurrentBudget && !deletedIds.contains(1))
      _budget(1, 'Budget Aktif', now),
    if (period != AnalyticsPeriod.currentMonth && !deletedIds.contains(2))
      _budget(2, 'Budget Lama', previousMonth),
  ];

  BudgetProgress _budget(int id, String label, DateTime month) =>
      BudgetProgress(
        budget: BudgetEntry(
          id: id,
          categoryId: id,
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
    if (failSaving) throw StateError('Storage unavailable');
    savedId = id;
    savedCategoryId = categoryId;
    savedMonth = month;
    savedLimit = limitAmount;
  }

  @override
  Future<void> delete(int id) async {
    if (failDeletion) throw StateError('Storage unavailable');
    deletedIds.add(id);
    _changes.add(null);
  }

  Future<void> close() => _changes.close();
}

class _UnusedStore implements FinanceStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected storage access: ${invocation.memberName}',
  );
}
