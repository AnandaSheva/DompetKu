import '../local/database/app_database.dart';
import 'bill_reminder_batch.dart';

/// One reminder per day/phase, based only on each bill's next unpaid occurrence.
/// No bill names, amounts, Google credentials, or raw UIDs enter Android alarms.
class NativeBillReminder {
  const NativeBillReminder({
    required this.day,
    required this.phase,
    required this.keys,
  });
  final String day;
  final String phase;
  final List<String> keys;

  Map<String, Object> toMap() => {'day': day, 'phase': phase, 'keys': keys};

  static List<NativeBillReminder> plan({
    required List<RecurringBillEntry> bills,
    required DateTime now,
    required String dataset,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final days = <DateTime>{};
    for (final bill in bills.where((bill) => bill.isActive)) {
      final due = DateTime(
        bill.nextDueDate.year,
        bill.nextDueDate.month,
        bill.nextDueDate.day,
      );
      for (final day in [DateTime(due.year, due.month, due.day - 1), due]) {
        if (!day.isBefore(today)) days.add(day);
      }
    }
    final sorted = days.toList()..sort();
    return [
      for (final day in sorted)
        for (final batch in BillReminderBatch.forDay(
          bills: bills,
          now: day,
          dataset: dataset,
        ))
          NativeBillReminder(
            day: batch.day,
            phase: batch.phase,
            keys: batch.keys,
          ),
    ];
  }
}
