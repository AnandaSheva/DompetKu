import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dompet_sheva/app/providers/app_providers.dart';
import 'package:dompet_sheva/app/providers/financial_calendar_providers.dart';
import 'package:dompet_sheva/app/providers/planning_providers.dart';
import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/app_models.dart';

import 'helpers/financial_calendar_fixture.dart';

void main() {
  test(
    'multiple months share the existing subscriptions and react to updates',
    () async {
      var transactionListeners = 0;
      var billListeners = 0;
      final transactions = StreamController<List<TransactionDetail>>();
      final bills = StreamController<List<RecurringBillEntry>>();
      final container = ProviderContainer(
        overrides: [
          transactionDetailsProvider.overrideWith((ref) {
            transactionListeners++;
            return transactions.stream;
          }),
          recurringBillsProvider.overrideWith((ref) {
            billListeners++;
            return bills.stream;
          }),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await transactions.close();
        await bills.close();
      });
      final november = financialCalendarProvider(DateTime(2026, 11));
      final december = financialCalendarProvider(DateTime(2026, 12));
      container.listen(november, (_, _) {});
      container.listen(december, (_, _) {});
      expect(container.read(november).isLoading, isTrue);
      transactions.add([]);
      bills.add([calendarBill()]);
      await container.read(transactionDetailsProvider.future);
      await container.read(recurringBillsProvider.future);
      await container.pump();
      expect(transactionListeners, 1);
      expect(billListeners, 1);
      expect(
        container.read(november).requireValue.day(16).bills.single.isProjected,
        isFalse,
      );
      expect(
        container.read(december).requireValue.day(16).bills.single.isProjected,
        isTrue,
      );

      final updated = Completer<void>();
      container.listen(november, (_, value) {
        final day = value.asData?.value.day(16);
        if (day?.expense == 250000 &&
            day!.bills.isEmpty &&
            !updated.isCompleted) {
          updated.complete();
        }
      });
      transactions.add([
        calendarTransaction(type: 'expense', amount: 250000, date: calendarNow),
      ]);
      bills.add([calendarBill(due: DateTime(2026, 12, 16))]);
      await updated.future;
      await container.pump();
      expect(container.read(november).requireValue.day(16).expense, 250000);
      expect(container.read(november).requireValue.day(16).bills, isEmpty);
      expect(
        container.read(december).requireValue.day(16).bills.single.isProjected,
        isFalse,
      );
    },
  );

  test(
    'calendar data follows the account storage scope and remains isolated',
    () async {
      final parent = ProviderContainer();
      final aliceDb = AppDatabase(NativeDatabase.memory());
      final bobDb = AppDatabase(NativeDatabase.memory());
      final alice = ProviderContainer(
        parent: parent,
        overrides: [databaseProvider.overrideWithValue(aliceDb)],
      );
      final bob = ProviderContainer(
        parent: parent,
        overrides: [databaseProvider.overrideWithValue(bobDb)],
      );
      addTearDown(() async {
        alice.dispose();
        bob.dispose();
        parent.dispose();
        await aliceDb.close();
        await bobDb.close();
      });
      await alice.read(appBootstrapProvider.future);
      await bob.read(appBootstrapProvider.future);
      final wallet = (await aliceDb.walletsDao.getAll()).first;
      final category = (await aliceDb.categoriesDao.getByType('expense')).first;
      await aliceDb.transactionsDao.add(
        TransactionEntriesCompanion.insert(
          type: 'expense',
          amount: 50000,
          categoryId: Value(category.id),
          walletId: wallet.id,
          date: calendarNow,
          createdAt: calendarNow,
          updatedAt: calendarNow,
        ),
      );
      await aliceDb.recurringBillsDao.add(
        RecurringBillEntriesCompanion.insert(
          title: 'Tagihan Alice',
          amount: 250000,
          categoryId: category.id,
          walletId: wallet.id,
          nextDueDate: DateTime(2026, 11, 16),
          frequency: 'monthly',
          anchorDay: 16,
          createdAt: calendarNow,
          updatedAt: calendarNow,
        ),
      );

      final provider = financialCalendarProvider(DateTime(2026, 11));
      for (final account in [alice, bob]) {
        account.listen(provider, (_, _) {});
        await account.read(transactionDetailsProvider.future);
        await account.read(recurringBillsProvider.future);
        await account.pump();
      }
      expect(alice.read(provider).requireValue.day(16).expense, 50000);
      expect(
        alice.read(provider).requireValue.day(16).bills.single.bill.title,
        'Tagihan Alice',
      );
      expect(bob.read(provider).requireValue.day(16).expense, 0);
      expect(bob.read(provider).requireValue.day(16).bills, isEmpty);
    },
  );
}
