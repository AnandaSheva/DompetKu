import '../formatters/date_formatter.dart';

class MonthlyPeriod {
  const MonthlyPeriod({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  String get key =>
      '${start.year.toString().padLeft(4, '0')}-'
      '${start.month.toString().padLeft(2, '0')}';

  static MonthlyPeriod containing(DateTime date, int resetDay) {
    _validateResetDay(resetDay);
    final thisMonthStart = startForMonth(date.year, date.month, resetDay);
    final start = date.isBefore(thisMonthStart)
        ? startForMonth(date.year, date.month - 1, resetDay)
        : thisMonthStart;
    return MonthlyPeriod(
      start: start,
      end: startForMonth(start.year, start.month + 1, resetDay),
    );
  }

  static DateTime startForMonth(int year, int month, int resetDay) {
    _validateResetDay(resetDay);
    final normalizedMonth = DateTime(year, month);
    final lastDay = DateTime(
      normalizedMonth.year,
      normalizedMonth.month + 1,
      0,
    ).day;
    return DateTime(
      normalizedMonth.year,
      normalizedMonth.month,
      resetDay.clamp(1, lastDay).toInt(),
    );
  }

  static DateTime shiftStart(DateTime start, int monthOffset, int resetDay) {
    final targetMonth = DateTime(start.year, start.month + monthOffset);
    return startForMonth(targetMonth.year, targetMonth.month, resetDay);
  }

  static String label(MonthlyPeriod period) {
    final lastDay = period.end.subtract(const Duration(days: 1));
    return '${DateFormatter.shortDateLabel(period.start)} – '
        '${DateFormatter.shortDateLabel(lastDay)}';
  }

  static void _validateResetDay(int resetDay) {
    if (resetDay < 1 || resetDay > 31) {
      throw ArgumentError.value(resetDay, 'resetDay', 'Harus antara 1 dan 31.');
    }
  }
}
