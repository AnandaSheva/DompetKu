import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dompet_sheva/app/theme/app_theme.dart';
import 'package:dompet_sheva/core/enums/analytics_period.dart';
import 'package:dompet_sheva/core/formatters/currency_formatter.dart';
import 'package:dompet_sheva/core/formatters/date_formatter.dart';
import 'package:dompet_sheva/data/repositories/app_models.dart';
import 'package:dompet_sheva/features/analytics/widgets/cashflow_chart_card.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets(
    'plots actual income and expense with a shared zero-based scale',
    (tester) async {
      await _open(tester, [
        _point(1, 1000000, 200000),
        _point(2, 0, 400000),
        _point(3, 0, 0),
      ]);
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;

      expect(find.text('Surplus'), findsOneWidget);
      expect(find.text(CurrencyFormatter.rupiah(400000)), findsOneWidget);
      expect(data.lineBarsData, hasLength(2));
      expect(data.lineBarsData.first.spots.map((spot) => spot.y), [
        1000000,
        0,
        0,
      ]);
      expect(data.lineBarsData.last.spots.map((spot) => spot.y), [
        200000,
        400000,
        0,
      ]);
      expect(data.lineBarsData.every((line) => !line.isCurved), true);
      expect(data.minY, 0);
      expect(data.maxY, greaterThanOrEqualTo(1000000));
    },
  );

  testWidgets('tooltip reports the exact cycle range and all three amounts', (
    tester,
  ) async {
    final point = DailyCashflow(
      date: DateTime(2026, 10, 20),
      endDate: DateTime(2026, 11, 15),
      income: 600000,
      expense: 800000,
    );
    await _open(tester, [point], period: AnalyticsPeriod.last3Months);
    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    final line = data.lineBarsData.first;
    final tooltip = data.lineTouchData.touchTooltipData.getTooltipItems([
      LineBarSpot(line, 0, line.spots.single),
    ]).single!;

    expect(tooltip.text, contains(DateFormatter.shortDateLabel(point.date)));
    expect(
      tooltip.text,
      contains(DateFormatter.shortDateLabel(DateTime(2026, 11, 14))),
    );
    expect(tooltip.text, contains(CurrencyFormatter.rupiah(600000)));
    expect(tooltip.text, contains(CurrencyFormatter.rupiah(800000)));
    expect(tooltip.text, contains(CurrencyFormatter.rupiah(-200000)));
  });

  for (final (income, expense, status) in [
    (200000, 500000, 'Defisit'),
    (500000, 500000, 'Seimbang'),
  ]) {
    testWidgets('$status still shows the actual financial activity', (
      tester,
    ) async {
      await _open(tester, [_point(1, income, expense)]);
      expect(find.text(status), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
      expect(
        find.text(CurrencyFormatter.rupiah(income - expense)),
        findsOneWidget,
      );
    });
  }

  testWidgets(
    'one day remains visible as a centered point without fabricated data',
    (tester) async {
      await _open(tester, [_point(1, 500000, 100000)]);
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;

      for (final line in data.lineBarsData) {
        expect(line.spots, hasLength(1));
        expect(line.dotData.show, true);
        expect(line.spots.single.x, greaterThan(data.minX));
        expect(line.spots.single.x, lessThan(data.maxX));
      }
    },
  );

  testWidgets('empty cashflow does not render a misleading line', (
    tester,
  ) async {
    await _open(tester, [_point(1, 0, 0)]);
    expect(find.byType(LineChart), findsNothing);
    expect(
      find.text('Belum ada pemasukan atau pengeluaran pada periode ini.'),
      findsOneWidget,
    );
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('large amounts fit a narrow ${theme.brightness.name} card', (
      tester,
    ) async {
      await _open(
        tester,
        [_point(1, 1500000000, 800000000)],
        theme: theme,
        width: 320,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(LineChart), findsOneWidget);
    });
  }
}

DailyCashflow _point(int day, int income, int expense) => DailyCashflow(
  date: DateTime(2026, 11, day),
  endDate: DateTime(2026, 11, day + 1),
  income: income,
  expense: expense,
);

Future<void> _open(
  WidgetTester tester,
  List<DailyCashflow> points, {
  ThemeData? theme,
  AnalyticsPeriod period = AnalyticsPeriod.currentMonth,
  double width = 420,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              CashflowChartCard(
                summary: AnalyticsSummary(
                  expenseByCategory: const [],
                  incomeByCategory: const [],
                  dailyCashflow: points,
                  weeklyExpense: const [],
                  topExpenses: const [],
                ),
                period: period,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
