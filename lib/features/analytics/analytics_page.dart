import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/app_providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/enums/analytics_period.dart';
import '../../core/enums/budget_status.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../core/formatters/date_formatter.dart';
import '../../core/formatters/rupiah_input_formatter.dart';
import '../../core/helpers/monthly_period.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/app_models.dart';
import '../../shared/widgets/app_confirm_dialog.dart';
import '../../shared/widgets/app_form_actions.dart';
import '../../shared/widgets/app_icon_action_button.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/pressable_surface.dart';
import '../../shared/widgets/top_toast.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(analyticsSummaryProvider);
    final selectedPeriod = ref.watch(analyticsPeriodProvider);
    final settings = ref
        .watch(appSettingsProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final resetDay = settings?.monthlyResetDay ?? 1;
    final currentMonth = MonthlyPeriod.containing(DateTime.now(), resetDay);
    final budgets = ref.watch(budgetProgressProvider);
    final categories = ref
        .watch(categoriesProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <CategoryEntry>[],
        );

    return SafeArea(
      bottom: false,
      child: analytics.when(
        data: (summary) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.xl,
            AppSpacing.screen,
            AppSpacing.contentBottomInset,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Analitik',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                ),
                AppIconActionButton(
                  icon: Icons.add_rounded,
                  label: 'Tambah budget',
                  onPressed: () =>
                      _showBudgetDialog(context, ref, categories, resetDay),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Lihat pola pemasukan, pengeluaran, dan budget sesuai periode.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            _AnalyticsPeriodFilter(
              selected: selectedPeriod,
              onSelected: (period) {
                ref.read(analyticsPeriodProvider.notifier).setPeriod(period);
              },
            ),
            if (selectedPeriod == AnalyticsPeriod.currentMonth) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                MonthlyPeriod.label(currentMonth),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            if (summary.isEmpty)
              const EmptyState(
                icon: Icons.insights_rounded,
                title: 'Belum ada analitik',
                message:
                    'Tambahkan beberapa transaksi untuk melihat ringkasan pemasukan, pengeluaran, dan kategori.',
              )
            else ...[
              _ChartCard(
                title: 'Pengeluaran per kategori',
                subtitle:
                    'Distribusi pengeluaran berdasarkan periode yang dipilih.',
                child: _DonutChart(items: summary.expenseByCategory),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ChartCard(
                title: 'Arus kas',
                subtitle:
                    'Selisih pemasukan dan pengeluaran dari waktu ke waktu.',
                child: _LineChart(
                  items: summary.dailyCashflow,
                  period: selectedPeriod,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ChartCard(
                title: selectedPeriod == AnalyticsPeriod.currentMonth
                    ? 'Pengeluaran mingguan'
                    : 'Pengeluaran per bulan',
                subtitle: selectedPeriod == AnalyticsPeriod.currentMonth
                    ? 'Total pengeluaran per minggu dalam periode yang dipilih.'
                    : 'Total pengeluaran per bulan dalam periode yang dipilih.',
                child: _BarChart(
                  items: summary.weeklyExpense,
                  emptyMessage: selectedPeriod == AnalyticsPeriod.currentMonth
                      ? 'Belum ada pengeluaran mingguan pada periode ini.'
                      : 'Belum ada pengeluaran pada periode ini.',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _TopCategoryList(items: summary.topExpenses),
              const SizedBox(height: AppSpacing.xxl),
            ],
            budgets.when(
              data: (items) => _BudgetSection(
                items: items,
                period: selectedPeriod,
                currentMonth: currentMonth.key,
                onEdit: (item) =>
                    _showBudgetDialog(context, ref, categories, resetDay, item),
                onDelete: (item) => _confirmDeleteBudget(context, ref, item),
                onReset: () => _confirmResetBudget(context, ref, resetDay),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
        loading: () => const Center(child: Text('Memuat analitik')),
        error: (_, _) =>
            const Center(child: Text('Analitik belum bisa dimuat')),
      ),
    );
  }

  Future<void> _showBudgetDialog(
    BuildContext context,
    WidgetRef ref,
    List<CategoryEntry> categories, [
    int resetDay = 1,
    BudgetProgress? existing,
  ]) async {
    final result = await showModalBottomSheet<_BudgetFormResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _BudgetFormSheet(categories: categories, existing: existing),
    );
    if (result == null) return;

    try {
      await ref
          .read(budgetRepositoryProvider)
          .save(
            id: existing?.budget.id,
            categoryId: result.categoryId,
            month:
                existing?.budget.month ??
                MonthlyPeriod.containing(DateTime.now(), resetDay).key,
            limitAmount: result.limitAmount,
          );
      if (!context.mounted) return;
      TopToast.show(
        context,
        existing == null
            ? 'Budget berhasil disimpan.'
            : 'Budget berhasil diperbarui.',
        type: TopToastType.success,
      );
    } on ArgumentError catch (error) {
      if (!context.mounted) return;
      TopToast.show(
        context,
        error.message.toString(),
        type: TopToastType.warning,
      );
    }
  }

  Future<void> _confirmDeleteBudget(
    BuildContext context,
    WidgetRef ref,
    BudgetProgress item,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Hapus budget?',
      message: 'Budget yang dihapus tidak bisa dikembalikan.',
      confirmLabel: 'Hapus',
      danger: true,
    );
    if (!confirmed) return;
    await ref.read(budgetRepositoryProvider).delete(item.budget.id);
    if (!context.mounted) return;
    TopToast.show(
      context,
      'Budget berhasil dihapus.',
      type: TopToastType.success,
    );
  }

  Future<void> _confirmResetBudget(
    BuildContext context,
    WidgetRef ref,
    int resetDay,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Reset budget bulan ini?',
      message:
          'Semua budget untuk bulan ini akan dihapus. Transaksi tetap aman.',
      confirmLabel: 'Reset',
      danger: true,
    );
    if (!confirmed) return;
    await ref
        .read(budgetRepositoryProvider)
        .resetMonth(MonthlyPeriod.containing(DateTime.now(), resetDay).key);
    if (!context.mounted) return;
    TopToast.show(
      context,
      'Budget bulan ini direset.',
      type: TopToastType.success,
    );
  }
}

class _AnalyticsPeriodFilter extends StatelessWidget {
  const _AnalyticsPeriodFilter({
    required this.selected,
    required this.onSelected,
  });

  final AnalyticsPeriod selected;
  final ValueChanged<AnalyticsPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.hardEdge,
      child: Row(
        children: [
          for (final period in AnalyticsPeriod.values) ...[
            _PeriodChip(
              label: period.label,
              selected: selected == period,
              onTap: () => onSelected(period),
            ),
            if (period != AnalyticsPeriod.values.last)
              const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.brightness == Brightness.dark;

    return PressableSurface(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppColors.softBlue : AppColors.primary)
              : (isDark ? AppColors.darkSurfaceElevated : AppColors.surface),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : isDark
                ? AppColors.darkBorderSubtle
                : AppColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: selected
                ? (isDark ? AppColors.darkBackground : AppColors.onDark)
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.brightness == Brightness.dark;

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
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(height: 244, child: child),
        ],
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.items});

  final List<CategoryAmount> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _ChartEmptyState('Belum ada pengeluaran pada periode ini.');
    }

    final total = items.fold<int>(0, (value, item) => value + item.amount);
    final slices = _donutSlices(items, Theme.of(context).brightness);

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 44,
              sectionsSpace: 2,
              sections: [
                for (final item in slices)
                  PieChartSectionData(
                    value: item.amount.toDouble(),
                    title: '',
                    color: item.color,
                    radius: 42,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in slices) ...[
                _DonutLegendItem(item: item, total: total),
                if (item != slices.last) const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutLegendItem extends StatelessWidget {
  const _DonutLegendItem({required this.item, required this.total});

  final _DonutSlice item;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = total <= 0 ? 0 : ((item.amount / total) * 100).round();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: AppSpacing.md,
          height: AppSpacing.md,
          margin: const EdgeInsets.only(top: AppSpacing.xs),
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${CurrencyFormatter.rupiah(item.amount)} · $percent%',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

List<_DonutSlice> _donutSlices(
  List<CategoryAmount> items,
  Brightness brightness,
) {
  final top = items.take(4).toList();
  final rest = items.skip(4).fold<int>(0, (value, item) => value + item.amount);

  return [
    for (var index = 0; index < top.length; index++)
      _DonutSlice(
        label: top[index].label,
        amount: top[index].amount,
        color: _chartColor(top[index].colorValue, index, brightness),
      ),
    if (rest > 0)
      _DonutSlice(
        label: 'Kategori lainnya',
        amount: rest,
        color: AppColors.textTertiary,
      ),
  ];
}

Color _chartColor(int colorValue, int index, Brightness brightness) {
  final value = colorValue == 0
      ? AppColors.categoryPalette[index % AppColors.categoryPalette.length]
            .toARGB32()
      : colorValue;
  return AppColors.categoryColor(value, brightness);
}

class _DonutSlice {
  const _DonutSlice({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.items, required this.period});

  final List<DailyCashflow> items;
  final AnalyticsPeriod period;

  @override
  Widget build(BuildContext context) {
    if (items.every((item) => item.income == 0 && item.expense == 0)) {
      return const _ChartEmptyState('Belum ada arus kas pada periode ini.');
    }

    final theme = Theme.of(context);
    final isDark = theme.colorScheme.brightness == Brightness.dark;
    final spots = [
      for (var index = 0; index < items.length; index++)
        FlSpot(
          index.toDouble(),
          (items[index].income - items[index].expense).toDouble(),
        ),
    ];

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (!_shouldShowLineLabel(index, items.length)) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    _lineLabel(items[index].date, period),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: _lineMinY(spots),
        maxY: _lineMaxY(spots),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBorderRadius: BorderRadius.circular(AppRadius.md),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            getTooltipColor: (_) =>
                isDark ? AppColors.darkSurfaceElevated : AppColors.textPrimary,
            getTooltipItems: (spots) {
              return [
                for (final spot in spots)
                  LineTooltipItem(
                    CurrencyFormatter.rupiah(spot.y.round()),
                    theme.textTheme.labelLarge!.copyWith(
                      color: AppColors.onDark,
                    ),
                  ),
              ];
            },
          ),
        ),
        clipData: const FlClipData.none(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            dotData: const FlDotData(show: false),
            color: AppColors.primary,
            barWidth: 4,
          ),
        ],
      ),
    );
  }

  double _lineMinY(List<FlSpot> spots) {
    final value = spots.fold<double>(0, (minY, spot) {
      return spot.y < minY ? spot.y : minY;
    });
    return value == 0 ? -1 : value * 1.18;
  }

  double _lineMaxY(List<FlSpot> spots) {
    final value = spots.fold<double>(0, (maxY, spot) {
      return spot.y > maxY ? spot.y : maxY;
    });
    return value == 0 ? 1 : value * 1.18;
  }
}

bool _shouldShowLineLabel(int index, int length) {
  if (index < 0 || index >= length) return false;
  if (length <= 4) return true;
  return index == 0 || index == length ~/ 2 || index == length - 1;
}

String _lineLabel(DateTime date, AnalyticsPeriod period) {
  switch (period) {
    case AnalyticsPeriod.currentMonth:
      return '${date.day}';
    case AnalyticsPeriod.last3Months:
    case AnalyticsPeriod.yearToDate:
    case AnalyticsPeriod.allTime:
      return _shortMonthLabel(date);
  }
}

String _shortMonthLabel(DateTime date) {
  const labels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return labels[date.month - 1];
}

bool _shouldShowBarLabel(int index, int length) {
  if (index < 0 || index >= length) return false;
  if (length <= 6) return true;
  return index == 0 || index == length ~/ 2 || index == length - 1;
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.items, required this.emptyMessage});

  final List<CategoryAmount> items;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.brightness == Brightness.dark;
    final maxAmount = items.fold<int>(0, (current, item) {
      return item.amount > current ? item.amount : current;
    });

    if (maxAmount == 0) {
      return _ChartEmptyState(emptyMessage);
    }

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxAmount * 1.24,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.colorScheme.outline.withValues(alpha: 0.6),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (!_shouldShowBarLabel(index, items.length)) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    items[index].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBorderRadius: BorderRadius.circular(AppRadius.md),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            getTooltipColor: (_) =>
                isDark ? AppColors.darkSurfaceElevated : AppColors.textPrimary,
            tooltipBorder: BorderSide(
              color: isDark
                  ? AppColors.darkBorderSubtle
                  : AppColors.textPrimary.withValues(alpha: 0.08),
            ),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = items[groupIndex];
              return BarTooltipItem(
                '${item.label}\n${CurrencyFormatter.rupiah(item.amount)}',
                theme.textTheme.labelLarge!.copyWith(
                  color: AppColors.onDark,
                  height: 1.35,
                ),
              );
            },
          ),
        ),
        barGroups: [
          for (var index = 0; index < items.length; index++)
            BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: items[index].amount.toDouble(),
                  width: items.length > 8 ? 16 : 24,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  color: AppColors.readableAccent(
                    AppColors.expenseBlue,
                    theme.brightness,
                  ).withValues(alpha: 0.82),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TopCategoryList extends StatelessWidget {
  const _TopCategoryList({required this.items});

  final List<CategoryAmount> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.brightness == Brightness.dark;

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
          Text('Top 5 pengeluaran', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Kategori pengeluaran terbesar pada periode yang dipilih.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (items.isEmpty)
            Text(
              'Belum ada pengeluaran pada periode ini.',
              style: theme.textTheme.bodyMedium,
            )
          else
            for (final item in items.take(5)) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    CurrencyFormatter.rupiah(item.amount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }
}

class _BudgetSection extends StatelessWidget {
  const _BudgetSection({
    required this.items,
    required this.period,
    required this.currentMonth,
    required this.onEdit,
    required this.onDelete,
    required this.onReset,
  });

  final List<BudgetProgress> items;
  final AnalyticsPeriod period;
  final String currentMonth;
  final ValueChanged<BudgetProgress> onEdit;
  final ValueChanged<BudgetProgress> onDelete;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BudgetHeader(
          showReset: items.any((item) => item.budget.month == currentMonth),
          onReset: onReset,
          titleStyle: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        if (items.isEmpty)
          EmptyState(
            compact: true,
            icon: Icons.savings_rounded,
            title: period == AnalyticsPeriod.currentMonth
                ? 'Belum ada budget bulan ini'
                : 'Belum ada budget pada periode ini',
            message:
                'Tambahkan budget untuk memantau batas pengeluaran bulan ini.',
          )
        else
          for (final item in items) ...[
            _BudgetCard(
              item: item,
              onTap: () => onEdit(item),
              onLongPress: () => onDelete(item),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  final BudgetProgress item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.readableAccent(switch (item.status) {
      BudgetStatus.safe => AppColors.incomeBlue,
      BudgetStatus.nearLimit => AppColors.warningOrange,
      BudgetStatus.exceeded => AppColors.dangerRed,
    }, theme.brightness);

    return PressableSurface(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      item.status.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(color: color),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              DateFormatter.monthLabel(
                DateTime.parse('${item.budget.month}-01'),
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: item.ratio,
                minHeight: AppSpacing.sm,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${CurrencyFormatter.rupiah(item.spent)} dari ${CurrencyFormatter.rupiah(item.budget.limitAmount)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetFormSheet extends StatefulWidget {
  const _BudgetFormSheet({required this.categories, this.existing});

  final List<CategoryEntry> categories;
  final BudgetProgress? existing;

  @override
  State<_BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends State<_BudgetFormSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _scopeController;
  int? _categoryId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.existing?.budget.categoryId;
    _scopeController = TextEditingController(
      text: widget.existing?.label ?? 'Budget bulanan',
    );
    _amountController = TextEditingController(
      text: widget.existing == null
          ? ''
          : CurrencyFormatter.rupiah(widget.existing!.budget.limitAmount),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _scopeController.dispose();
    super.dispose();
  }

  Future<void> _chooseScope(List<CategoryEntry> categories) async {
    FocusScope.of(context).unfocus();
    final selection =
        await showModalBottomSheet<({int? categoryId, String name})>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          useSafeArea: true,
          builder: (context) => _BudgetScopePicker(
            categories: categories,
            selectedCategoryId: _categoryId,
          ),
        );
    if (!mounted || selection == null) return;
    setState(() {
      _categoryId = selection.categoryId;
      _scopeController.text = selection.name;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategories = widget.categories
        .where(
          (category) =>
              !category.isArchived &&
              (category.type == 'expense' || category.type == 'both'),
        )
        .toList();
    final editing = widget.existing != null;

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: kIsWeb ? AppSpacing.webMaxWidth : double.infinity,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    editing ? 'Edit budget' : 'Tambah budget',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tentukan batas pengeluaran untuk periode ini.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextField(
                    controller: _scopeController,
                    readOnly: true,
                    enabled: !editing,
                    enableInteractiveSelection: false,
                    decoration: const InputDecoration(
                      labelText: 'Cakupan',
                      helperText:
                          'Pilih budget bulanan atau kategori tertentu.',
                      suffixIcon: Icon(Icons.expand_more_rounded),
                    ),
                    onTap: () => _chooseScope(expenseCategories),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [RupiahInputFormatter()],
                    decoration: InputDecoration(
                      labelText: 'Batas budget',
                      hintText: 'Rp500.000',
                      helperText:
                          'Masukkan batas pengeluaran untuk periode budget ini.',
                      errorText: _error,
                    ),
                    onChanged: (_) {
                      if (_error != null) {
                        setState(() => _error = null);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppFormActions(
                    secondaryLabel: 'Batal',
                    primaryLabel: 'Simpan',
                    onSecondaryPressed: () => Navigator.pop(context),
                    onPrimaryPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final amount = CurrencyFormatter.parseRupiah(_amountController.text);
    if (amount <= 0) {
      setState(() => _error = 'Masukkan nominal budget terlebih dahulu.');
      return;
    }
    Navigator.pop(
      context,
      _BudgetFormResult(categoryId: _categoryId, limitAmount: amount),
    );
  }
}

class _BudgetScopePicker extends StatefulWidget {
  const _BudgetScopePicker({
    required this.categories,
    required this.selectedCategoryId,
  });

  final List<CategoryEntry> categories;
  final int? selectedCategoryId;

  @override
  State<_BudgetScopePicker> createState() => _BudgetScopePickerState();
}

class _BudgetScopePickerState extends State<_BudgetScopePicker> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyword = _searchController.text.trim().toLowerCase();
    final options = <({int? categoryId, String name})>[
      (categoryId: null, name: 'Budget bulanan'),
      for (final category in widget.categories)
        (categoryId: category.id, name: category.name),
    ].where((option) => option.name.toLowerCase().contains(keyword)).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: kIsWeb ? AppSpacing.webMaxWidth : double.infinity,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.65,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.sm,
                  AppSpacing.screen,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Pilih cakupan', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: 'Cari cakupan',
                        hintText: 'Ketik nama kategori atau budget bulanan',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Hapus pencarian',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  setState(_searchController.clear);
                                },
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: options.isEmpty
                          ? Center(
                              child: Text(
                                'Cakupan tidak ditemukan. Coba kata kunci lain.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium,
                              ),
                            )
                          : ListView.builder(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options[index];
                                final selected =
                                    option.categoryId ==
                                    widget.selectedCategoryId;
                                return ListTile(
                                  minTileHeight: 56,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                  ),
                                  title: Text(option.name),
                                  trailing: selected
                                      ? Icon(
                                          Icons.check_rounded,
                                          color: theme.colorScheme.primary,
                                        )
                                      : null,
                                  onTap: () => Navigator.pop(context, option),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetHeader extends StatelessWidget {
  const _BudgetHeader({
    required this.showReset,
    required this.onReset,
    required this.titleStyle,
  });

  final bool showReset;
  final VoidCallback onReset;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      'Budget',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: titleStyle,
    );

    if (!showReset) {
      return SizedBox(width: double.infinity, child: title);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final resetButton = SizedBox(
          width: 96,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.dangerRed,
              side: const BorderSide(color: AppColors.dangerRed),
            ),
            onPressed: onReset,
            child: const Text(
              'Reset',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );

        if (constraints.maxWidth < 280) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: AppSpacing.md),
              Align(alignment: Alignment.centerRight, child: resetButton),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: AppSpacing.md),
            resetButton,
          ],
        );
      },
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _BudgetFormResult {
  const _BudgetFormResult({
    required this.categoryId,
    required this.limitAmount,
  });

  final int? categoryId;
  final int limitAmount;
}
