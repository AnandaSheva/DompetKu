import 'package:flutter_test/flutter_test.dart';
import 'package:dompet_sheva/data/notifications/native_bill_schedule.dart';

import 'helpers/financial_calendar_fixture.dart';

void main() {
  test(
    'plans H-1 and due day only for next active unpaid occurrences, with private payloads',
    () {
      final plans = NativeBillReminder.plan(
        bills: [
          calendarBill(id: 1, due: DateTime(2026, 12, 1)),
          calendarBill(id: 2, due: DateTime(2026, 12, 1)),
          calendarBill(id: 3, due: DateTime(2026, 12, 2), active: false),
          calendarBill(id: 4, due: DateTime(2026, 11, 14)),
        ],
        now: calendarNow,
        dataset: 'account-dataset',
      );
      expect(plans.map((p) => '${p.day}:${p.phase}'), [
        '2026-11-30:tomorrow',
        '2026-12-01:today',
      ]);
      expect(plans.every((p) => p.keys.length == 2), isTrue);
      final payload = plans.first.toMap().toString();
      expect(payload, isNot(contains('Internet rumah')));
      expect(payload, isNot(contains('250000')));
      expect(payload, isNot(contains('account-dataset')));
    },
  );

  test(
    'paying, skipping, pausing, or replacing a dataset invalidates old occurrence keys',
    () {
      List<NativeBillReminder> plan({
        DateTime? due,
        bool active = true,
        String dataset = 'first',
      }) => NativeBillReminder.plan(
        bills: [
          calendarBill(due: due ?? DateTime(2026, 11, 16), active: active),
        ],
        now: calendarNow,
        dataset: dataset,
      );
      final original = plan().single.keys.single;
      expect(plan(active: false), isEmpty);
      expect(
        plan(due: DateTime(2026, 12, 16)).expand((p) => p.keys),
        isNot(contains(original)),
      );
      expect(plan(dataset: 'replacement').single.keys.single, isNot(original));
      expect(plan().single.day, '2026-11-16');
    },
  );
}
