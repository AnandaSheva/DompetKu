import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/formatters/date_formatter.dart';
import '../local/database/app_database.dart';

String billReminderAccountKey(String uid) => _hash('dompetku-bills:$uid');
String _hash(String value) => sha256.convert(utf8.encode(value)).toString();
String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class BillReminderBatch {
  const BillReminderBatch({
    required this.day,
    required this.phase,
    required this.keys,
  });

  final String day;
  final String phase;
  final List<String> keys;

  /// Only the next unpaid schedule is authoritative. Calendar projections are
  /// deliberately excluded, as are paused, paid, skipped and overdue periods.
  static List<BillReminderBatch> forDay({
    required List<RecurringBillEntry> bills,
    required DateTime now,
    required String dataset,
  }) {
    final today = DateFormatter.startOfDay(now);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final groups = <String, List<String>>{'today': [], 'tomorrow': []};
    for (final bill in bills) {
      if (!bill.isActive) continue;
      final due = DateFormatter.startOfDay(bill.nextDueDate);
      final phase = due == today
          ? 'today'
          : due == tomorrow
          ? 'tomorrow'
          : null;
      if (phase == null) continue;
      groups[phase]!.add(_hash('$dataset:${bill.id}:${_dateKey(due)}:$phase'));
    }
    return [
      for (final group in groups.entries)
        if (group.value.isNotEmpty)
          BillReminderBatch(
            day: _dateKey(today),
            phase: group.key,
            keys: List.unmodifiable(group.value.toSet().toList()..sort()),
          ),
    ];
  }

  String toJson({required String accountKey, required int revision}) =>
      jsonEncode({
        'account': accountKey,
        'revision': revision,
        'day': day,
        'phase': phase,
        'keys': keys,
      });
}
