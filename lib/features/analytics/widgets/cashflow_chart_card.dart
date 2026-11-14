import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/enums/analytics_period.dart';
import '../../../core/formatters/currency_formatter.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../data/repositories/app_models.dart';

class CashflowChartCard extends StatelessWidget {
  const CashflowChartCard({
    super.key,
    required this.summary,
    required this.period,
  });

  final AnalyticsSummary summary;
  final AnalyticsPeriod period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final incomeColor = AppColors.readableAccent(
      AppColors.cashflowIncome,
      theme.brightness,
    );
    final expenseColor = AppColors.readableAccent(
      AppColors.cashflowExpense,
      theme.brightness,
    );
    final net = summary.netCashflow;
    final statusColor = net == 0
        ? theme.colorScheme.onSurfaceVariant
        : net > 0
        ? incomeColor
        : expenseColor;
    final hasActivity = summary.dailyCashflow.any(
      (item) => item.income != 0 || item.expense != 0,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Arus kas', style: theme.textTheme.titleLarge),
              ),
              Text(
                period == AnalyticsPeriod.currentMonth ? 'Harian' : 'Bulanan',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pemasukan dan pengeluaran sesuai periode yang dipilih.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Arus kas bersih', style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      CurrencyFormatter.rupiah(net),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  net == 0
                      ? 'Seimbang'
                      : net > 0
                      ? 'Surplus'
                      : 'Defisit',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _FlowMetric(
                  label: 'Pemasukan',
                  amount: summary.totalIncome,
                  color: incomeColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _FlowMetric(
                  label: 'Pengeluaran',
                  amount: summary.totalExpense,
                  color: expenseColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (hasActivity) ...[
            Text('Nominal (Rp)', style: theme.textTheme.labelSmall),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 230,
              child: _CashflowLines(
                items: summary.dailyCashflow,
                period: period,
                incomeColor: incomeColor,
                expenseColor: expenseColor,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Sentuh titik grafik untuk melihat rincian nominal.',
              style: theme.textTheme.bodySmall,
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Text(
                'Belum ada pemasukan atau pengeluaran pada periode ini.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Transfer antar dompet tidak dihitung.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _FlowMetric extends StatelessWidget {
  const _FlowMetric({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSpacing.metricDot,
                height: AppSpacing.metricDot,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(label, style: theme.textTheme.labelSmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              CurrencyFormatter.rupiah(amount),
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashflowLines extends StatelessWidget {
  const _CashflowLines({
    required this.items,
    required this.period,
    required this.incomeColor,
    required this.expenseColor,
  });

  final List<DailyCashflow> items;
  final AnalyticsPeriod period;
  final Color incomeColor;
  final Color expenseColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peak = items.fold<int>(
      0,
      (value, item) => math.max(value, math.max(item.income, item.expense)),
    );
    final rawStep = math.max(peak / 3, 1.0);
    final magnitude = math
        .pow(10, (math.log(rawStep) / math.ln10).floor())
        .toDouble();
    final step =
        [1, 2, 5, 10].firstWhere((value) => value * magnitude >= rawStep) *
        magnitude;
    final maxY = (peak * 1.1 / step).ceil() * step;
    final compact = NumberFormat.compact(locale: 'id_ID');
    final single = items.length == 1;

    LineChartBarData series(bool income, Color color) => LineChartBarData(
      spots: [
        for (var index = 0; index < items.length; index++)
          FlSpot(
            single ? 1 : index.toDouble(),
            (income ? items[index].income : items[index].expense).toDouble(),
          ),
      ],
      isCurved: false,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        checkToShowDot: (spot, _) => items.length <= 12 || spot.y > 0,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 2.5,
          color: color,
          strokeWidth: 1.5,
          strokeColor: theme.colorScheme.surface,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.05),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.lg, top: AppSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) => LineChart(
          LineChartData(
            minX: 0,
            maxX: single ? 2 : (items.length - 1).toDouble(),
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: step,
              getDrawingHorizontalLine: (value) => FlLine(
                color: theme.colorScheme.outline.withValues(alpha: 0.55),
                strokeWidth: 1,
                dashArray: value == 0 ? null : [4, 4],
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 46,
                  interval: step,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    space: AppSpacing.sm,
                    child: Text(
                      compact.format(value),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final index = single ? 0 : value.toInt();
                    if (value != value.roundToDouble() ||
                        (single && value != 1) ||
                        index < 0 ||
                        index >= items.length ||
                        (items.length > 4 &&
                            index != 0 &&
                            index != items.length ~/ 2 &&
                            index != items.length - 1)) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      space: AppSpacing.sm,
                      child: Text(
                        DateFormat(
                          period == AnalyticsPeriod.currentMonth
                              ? 'd MMM'
                              : 'MMM yy',
                          'id_ID',
                        ).format(items[index].date),
                        style: theme.textTheme.labelSmall,
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              series(true, incomeColor),
              series(false, expenseColor),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                maxContentWidth: math.max(
                  100,
                  math.min(240, constraints.maxWidth - 64),
                ),
                tooltipBorderRadius: BorderRadius.circular(AppRadius.md),
                getTooltipColor: (_) => AppColors.textPrimary,
                getTooltipItems: (spots) => [
                  for (var index = 0; index < spots.length; index++)
                    if (index == 0)
                      _tooltip(items[spots[index].spotIndex], theme)
                    else
                      null,
                ],
              ),
            ),
          ),
          duration: const Duration(milliseconds: 180),
        ),
      ),
    );
  }

  LineTooltipItem _tooltip(DailyCashflow item, ThemeData theme) {
    final end = item.endDate;
    final lastDay = end == null
        ? item.date
        : DateTime(end.year, end.month, end.day - 1);
    final label = lastDay == item.date
        ? DateFormatter.shortDateLabel(item.date)
        : '${DateFormatter.shortDateLabel(item.date)} – ${DateFormatter.shortDateLabel(lastDay)}';
    return LineTooltipItem(
      '$label\n'
      'Pemasukan: ${CurrencyFormatter.rupiah(item.income)}\n'
      'Pengeluaran: ${CurrencyFormatter.rupiah(item.expense)}\n'
      'Selisih: ${CurrencyFormatter.rupiah(item.netCashflow)}',
      theme.textTheme.labelSmall!.copyWith(
        color: AppColors.onDark,
        height: 1.5,
      ),
      textAlign: TextAlign.left,
    );
  }
}
