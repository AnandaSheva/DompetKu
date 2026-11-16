import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers/app_providers.dart';
import '../../../app/providers/financial_calendar_providers.dart';
import '../../../app/providers/planning_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/enums/transaction_type.dart';
import '../../../core/formatters/currency_formatter.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../data/repositories/financial_calendar.dart';
import '../../../shared/helpers/category_icon_mapper.dart';
import '../../../shared/widgets/pressable_surface.dart';
import '../../planning/planning_page.dart';
import '../../transactions/widgets/transaction_tile.dart';
import 'calendar_month_picker.dart';

class FinancialCalendarCard extends ConsumerStatefulWidget {
  const FinancialCalendarCard({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  ConsumerState<FinancialCalendarCard> createState() =>
      _FinancialCalendarCardState();
}

class _FinancialCalendarCardState extends ConsumerState<FinancialCalendarCard>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late DateTime _today;
  late DateTime _selected;
  late DateTime _month;
  Timer? _midnightTimer;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _today = DateFormatter.startOfDay(_now);
    _selected = _today;
    _month = DateTime(_today.year, _today.month);
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshToday();
  }

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    final now = _now;
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(next.difference(now), _refreshToday);
  }

  void _refreshToday() {
    final today = DateFormatter.startOfDay(_now);
    if (today != _today) {
      setState(() {
        if (_selected == _today) {
          _selected = today;
          _month = DateTime(today.year, today.month);
        }
        _today = today;
      });
    }
    _scheduleMidnight();
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selected = date;
      _month = DateTime(date.year, date.month);
    });
  }

  void _moveMonth(int offset) {
    final month = DateTime(_month.year, _month.month + offset);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    _selectDate(
      DateTime(month.year, month.month, math.min(_selected.day, lastDay)),
    );
  }

  Future<void> _pickDate() async {
    final month = await showCalendarMonthPicker(context, _selected);
    if (month != null && mounted) {
      final lastDay = DateTime(month.year, month.month + 1, 0).day;
      _selectDate(
        DateTime(month.year, month.month, math.min(_selected.day, lastDay)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final calendar = ref.watch(financialCalendarProvider(_month));
    final data = calendar.asData?.value;
    final hidden =
        ref.watch(appSettingsProvider).asData?.value?.hideBalance ?? false;
    final incomeColor = AppColors.readableAccent(
      AppColors.cashflowIncome,
      theme.brightness,
    );
    final expenseColor = AppColors.readableAccent(
      AppColors.cashflowExpense,
      theme.brightness,
    );
    final billColor = AppColors.readableAccent(
      AppColors.warningOrange,
      theme.brightness,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
                child: Text(
                  'Kalender keuangan',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () {
                  _refreshToday();
                  _selectDate(_today);
                },
                child: const Text('Hari ini'),
              ),
            ],
          ),
          Text(
            'Transaksi harian dan jadwal tagihan.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _MonthButton(
                label: 'Bulan sebelumnya',
                icon: Icons.chevron_left_rounded,
                onPressed: _month.year == 2000 && _month.month == 1
                    ? null
                    : () => _moveMonth(-1),
              ),
              Expanded(
                child: TextButton(
                  onPressed: _pickDate,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        DateFormatter.monthLabel(_month),
                        style: theme.textTheme.titleMedium,
                      ),
                      const Icon(Icons.expand_more_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              _MonthButton(
                label: 'Bulan berikutnya',
                icon: Icons.chevron_right_rounded,
                onPressed: _month.year == 2100 && _month.month == 12
                    ? null
                    : () => _moveMonth(1),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (final label in [
                'Sen',
                'Sel',
                'Rab',
                'Kam',
                'Jum',
                'Sab',
                'Min',
              ])
                Expanded(
                  child: Center(
                    child: Text(label, style: theme.textTheme.labelSmall),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _CalendarGrid(
            month: _month,
            today: _today,
            selected: _selected,
            data: data,
            onSelected: _selectDate,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _CalendarLegend(label: 'Masuk', color: incomeColor),
              _CalendarLegend(label: 'Keluar', color: expenseColor),
              _CalendarLegend(label: 'Tagihan', color: billColor),
              _CalendarLegend(
                label: 'Transfer',
                color: theme.colorScheme.primary,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1),
          ),
          Text(
            DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_selected),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          calendar.when(
            data: (value) => _DailyDetails(
              day: value.day(_selected.day),
              today: _today,
              hidden: hidden,
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text('Memuat transaksi dan tagihan...'),
            ),
            error: (_, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Data kalender belum bisa dimuat.'),
                TextButton.icon(
                  onPressed: () {
                    ref.invalidate(transactionDetailsProvider);
                    ref.invalidate(recurringBillsProvider);
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PlanningPage()),
              ),
              icon: const Icon(Icons.event_repeat_rounded, size: 18),
              label: const Text('Kelola tagihan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
    icon: Icon(icon),
  );
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.today,
    required this.selected,
    required this.data,
    required this.onSelected,
  });

  final DateTime month;
  final DateTime today;
  final DateTime selected;
  final FinancialCalendarMonth? data;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final leading = month.weekday - 1;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final rows = (leading + count + 6) ~/ 7;
    return Column(
      children: [
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final number = row * 7 + column - leading + 1;
                      if (number < 1 || number > count) {
                        return const SizedBox(height: 52);
                      }
                      final date = DateTime(month.year, month.month, number);
                      return _CalendarDayCell(
                        day:
                            data?.day(number) ??
                            FinancialCalendarDay(date: date),
                        isToday: date == today,
                        selected: date == selected,
                        onTap: () => onSelected(date),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });

  final FinancialCalendarDay day;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final foreground = selected
        ? theme.colorScheme.onPrimary
        : isToday
        ? accent
        : theme.colorScheme.onSurface;
    final colors = <Color>[
      if (day.hasIncome)
        AppColors.readableAccent(AppColors.cashflowIncome, theme.brightness),
      if (day.hasExpense)
        AppColors.readableAccent(AppColors.cashflowExpense, theme.brightness),
      if (day.bills.isNotEmpty)
        AppColors.readableAccent(AppColors.warningOrange, theme.brightness),
      if (day.hasTransfer) accent,
    ];
    final keyDate = DateFormat('yyyy-MM-dd').format(day.date);
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(day.date)}${isToday ? ', hari ini' : ''}, ${day.transactions.length} transaksi, ${day.bills.length} tagihan',
      child: ExcludeSemantics(
        child: PressableSurface(
          key: ValueKey('calendar-day-$keyDate'),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: selected ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: isToday ? accent : Colors.transparent),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.date.day}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final color in colors)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: selected ? foreground : color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: AppSpacing.xs),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

class _DailyDetails extends StatelessWidget {
  const _DailyDetails({
    required this.day,
    required this.today,
    required this.hidden,
  });
  final FinancialCalendarDay day;
  final DateTime today;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _DayAmount(
                label: 'Pemasukan',
                amount: day.income,
                color: AppColors.cashflowIncome,
                hidden: hidden,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _DayAmount(
                label: 'Pengeluaran',
                amount: day.expense,
                color: AppColors.cashflowExpense,
                hidden: hidden,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Selisih: ${CurrencyFormatter.rupiah(day.netCashflow, hidden: hidden)}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (day.bills.isNotEmpty) ...[
          Text('Tagihan terjadwal', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${day.bills.length} tagihan · ${CurrencyFormatter.rupiah(day.scheduledAmount, hidden: hidden)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final occurrence in day.bills) ...[
            _BillOccurrenceTile(
              occurrence: occurrence,
              today: today,
              hidden: hidden,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            'Jadwal berikutnya adalah perkiraan. Tagihan dihitung sebagai pengeluaran setelah pembayaran dicatat.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text('Transaksi harian', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        if (day.transactions.isEmpty)
          Text(
            day.bills.isEmpty
                ? 'Belum ada transaksi atau tagihan pada tanggal ini.'
                : 'Belum ada transaksi pada tanggal ini.',
            style: theme.textTheme.bodyMedium,
          ),
        for (final detail in day.transactions) ...[
          TransactionTile(
            title:
                detail.category?.name ??
                (detail.type == TransactionType.transfer
                    ? 'Transfer antar dompet'
                    : 'Tanpa kategori'),
            subtitle: [
              detail.wallet.name,
              if (detail.transferWallet != null)
                'ke ${detail.transferWallet!.name}',
              if (detail.transaction.note?.isNotEmpty ?? false)
                detail.transaction.note!,
            ].join(' · '),
            timeLabel: DateFormat(
              'HH.mm',
              'id_ID',
            ).format(detail.transaction.date.toLocal()),
            amount: CurrencyFormatter.rupiah(
              detail.transaction.amount,
              hidden: hidden,
            ),
            type: switch (detail.type) {
              TransactionType.income => TransactionPreviewType.income,
              TransactionType.expense => TransactionPreviewType.expense,
              TransactionType.transfer => TransactionPreviewType.transfer,
            },
            icon: detail.type == TransactionType.transfer
                ? Icons.swap_horiz_rounded
                : categoryIconForEntry(detail.category),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (day.hasTransfer)
          Text(
            'Transfer antar dompet tidak dihitung dalam pemasukan atau pengeluaran.',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _DayAmount extends StatelessWidget {
  const _DayAmount({
    required this.label,
    required this.amount,
    required this.color,
    required this.hidden,
  });
  final String label;
  final int amount;
  final Color color;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                CurrencyFormatter.rupiah(amount, hidden: hidden),
                key: ValueKey('calendar-$label'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.readableAccent(color, theme.brightness),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillOccurrenceTile extends StatelessWidget {
  const _BillOccurrenceTile({
    required this.occurrence,
    required this.today,
    required this.hidden,
  });
  final CalendarBillOccurrence occurrence;
  final DateTime today;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bill = occurrence.bill;
    final overdue = !occurrence.isProjected && occurrence.date.isBefore(today);
    final color = AppColors.readableAccent(
      overdue ? AppColors.dangerRed : AppColors.warningOrange,
      theme.brightness,
    );
    final label = occurrence.isProjected
        ? 'Perkiraan jadwal berikutnya'
        : overdue
        ? 'Terlambat · belum dicatat dibayar'
        : occurrence.date == today
        ? 'Jatuh tempo hari ini'
        : 'Jatuh tempo';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.event_note_rounded, color: color, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  CurrencyFormatter.rupiah(bill.amount, hidden: hidden),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
