import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';

Future<DateTime?> showCalendarMonthPicker(
  BuildContext context,
  DateTime selected,
) => showModalBottomSheet<DateTime>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _CalendarMonthPicker(selected: selected),
);

class _CalendarMonthPicker extends StatefulWidget {
  const _CalendarMonthPicker({required this.selected});
  final DateTime selected;

  @override
  State<_CalendarMonthPicker> createState() => _CalendarMonthPickerState();
}

class _CalendarMonthPickerState extends State<_CalendarMonthPicker> {
  late int _year = widget.selected.year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pilih bulan', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                IconButton(
                  tooltip: 'Tahun sebelumnya',
                  onPressed: _year > 2000
                      ? () => setState(() => _year--)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Center(
                    child: Text('$_year', style: theme.textTheme.titleLarge),
                  ),
                ),
                IconButton(
                  tooltip: 'Tahun berikutnya',
                  onPressed: _year < 2100
                      ? () => setState(() => _year++)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (var row = 0; row < 4; row++) ...[
              Row(
                children: [
                  for (var column = 0; column < 3; column++) ...[
                    if (column > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _monthButton(row * 3 + column + 1)),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthButton(int month) {
    final theme = Theme.of(context);
    final selected =
        _year == widget.selected.year && month == widget.selected.month;
    return OutlinedButton(
      onPressed: () => Navigator.pop(context, DateTime(_year, month)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        backgroundColor: selected ? theme.colorScheme.primaryContainer : null,
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
        ),
      ),
      child: Text(DateFormat('MMM', 'id_ID').format(DateTime(_year, month))),
    );
  }
}
