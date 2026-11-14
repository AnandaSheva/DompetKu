import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/backup_repository.dart';
import 'package:dompet_sheva/data/repositories/bootstrap_repository.dart';

void main() {
  late AppDatabase db;
  late BackupRepository repo;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = BackupRepository(db);
    await BootstrapRepository(db).ensureSeeded();
  });
  tearDown(() => db.close());

  test('invalid import does not delete existing data', () async {
    final payload = await repo.exportPayload();
    payload['transactions'] = [
      {'id': 1, 'type': 'expense', 'amount': 1.5},
    ];
    await expectLater(
      repo.restoreImport(
        BackupImportPreview(
          payload: payload,
          transactions: 1,
          wallets: 0,
          categories: 0,
          budgets: 0,
        ),
      ),
      throwsFormatException,
    );
    expect(await db.walletsDao.getAll(), hasLength(4));
  });

  test(
    'quick templates and transfer references survive backup restore',
    () async {
      final now = DateTime.now();
      final wallets = await db.walletsDao.getAll();
      await db.seedDao.insertQuickTemplates([
        QuickTemplateEntriesCompanion.insert(
          title: 'Transfer',
          transactionType: 'transfer',
          walletId: Value(wallets.first.id),
          iconKey: 'transfer',
          colorValue: 0xff2563eb,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      await db.transactionsDao.add(
        TransactionEntriesCompanion.insert(
          type: 'transfer',
          amount: 10000,
          walletId: wallets.first.id,
          transferWalletId: Value(wallets.last.id),
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final preview = repo.previewFromJson(
        jsonEncode(await repo.exportPayload()),
      );
      await repo.restoreImport(preview);
      expect(await db.getQuickTemplates(), hasLength(1));
      final restored = (await db.transactionsDao.getAll()).single;
      expect(restored.type, 'transfer');
      expect(restored.walletId, wallets.first.id);
      expect(restored.transferWalletId, wallets.last.id);
    },
  );

  Future<void> seedPlanning() async {
    final now = DateTime(2026, 11, 14);
    final wallet = (await db.walletsDao.getAll()).first;
    final category = (await db.categoriesDao.getByType('expense')).first;
    await db.recurringBillsDao.add(
      RecurringBillEntriesCompanion.insert(
        id: const Value(101),
        title: 'Internet rumah',
        amount: 300000,
        categoryId: category.id,
        walletId: wallet.id,
        nextDueDate: DateTime(2026, 11, 30),
        frequency: 'monthly',
        anchorDay: 31,
        isActive: const Value(false),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.savingsGoalsDao.add(
      SavingsGoalEntriesCompanion.insert(
        id: const Value(202),
        name: 'Dana darurat',
        targetAmount: 10000000,
        savedAmount: const Value(1250000),
        targetDate: Value(DateTime(2027, 12, 31)),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test(
    'bills and savings goals survive backup restore with IDs and dates',
    () async {
      await seedPlanning();
      final billsBefore = await db.recurringBillsDao.getAll();
      final goalsBefore = await db.savingsGoalsDao.getAll();
      final preview = repo.previewFromJson(
        jsonEncode(await repo.exportPayload()),
      );
      expect(preview.recurringBills, 1);
      expect(preview.savingsGoals, 1);
      await repo.restoreImport(preview);
      expect(await db.recurringBillsDao.getAll(), billsBefore);
      expect(await db.savingsGoalsDao.getAll(), goalsBefore);
    },
  );

  test(
    'older backups without planning collections remain importable',
    () async {
      final payload = await repo.exportPayload();
      payload.remove('recurring_bills');
      payload.remove('savings_goals');
      await seedPlanning();
      final preview = repo.previewFromJson(jsonEncode(payload));
      expect(preview.recurringBills, 0);
      expect(preview.savingsGoals, 0);
      await repo.restoreImport(preview);
      expect(await db.recurringBillsDao.getAll(), isEmpty);
      expect(await db.savingsGoalsDao.getAll(), isEmpty);
      expect(await db.walletsDao.getAll(), hasLength(4));
    },
  );

  test(
    'reset removes both planning collections without foreign key failures',
    () async {
      await seedPlanning();
      await repo.resetData();
      expect(await db.recurringBillsDao.getAll(), isEmpty);
      expect(await db.savingsGoalsDao.getAll(), isEmpty);
      expect(await db.walletsDao.getAll(), hasLength(4));
    },
  );

  test(
    'invalid planning imports are rejected before replacing existing data',
    () async {
      await seedPlanning();
      final original = await repo.exportPayload();
      final billsBefore = await db.recurringBillsDao.getAll();
      final goalsBefore = await db.savingsGoalsDao.getAll();
      final invalidCases = <void Function(Map<String, dynamic>)>[
        (p) => p['recurring_bills'][0]['wallet_id'] = 999999,
        (p) =>
            p['recurring_bills'][0]['category_id'] = (p['categories'] as List)
                .firstWhere((c) => c['type'] == 'income')['id'],
        (p) => p['recurring_bills'][0]['amount'] = 1.5,
        (p) => p['recurring_bills'][0]['amount'] = 0,
        (p) => p['recurring_bills'][0]['amount'] = 9007199254740992,
        (p) => p['recurring_bills'][0]['title'] = 'a' * 81,
        (p) => p['recurring_bills'][0]['frequency'] = 'sometimes',
        (p) => p['recurring_bills'][0]['anchor_day'] = 32,
        (p) => p['recurring_bills'][0]['is_active'] = 'true',
        (p) => p['recurring_bills'][0]['next_due_date'] = 'invalid',
        (p) => p['recurring_bills'].add(
          Map<String, dynamic>.from(p['recurring_bills'][0]),
        ),
        (p) => p['savings_goals'][0]['saved_amount'] = -1,
        (p) => p['savings_goals'][0]['target_amount'] = 0,
        (p) => p['savings_goals'][0]['target_date'] = 'invalid',
        (p) => p['savings_goals'][0]['name'] = '',
        (p) => p['savings_goals'].add(
          Map<String, dynamic>.from(p['savings_goals'][0]),
        ),
        (p) => p['savings_goals'] = null,
      ];
      for (var index = 0; index < invalidCases.length; index++) {
        final payload =
            jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
        invalidCases[index](payload);
        await expectLater(
          repo.restoreImport(
            BackupImportPreview(
              payload: payload,
              transactions: 0,
              wallets: 0,
              categories: 0,
              budgets: 0,
            ),
          ),
          throwsFormatException,
          reason: 'Invalid case $index must fail before deleting data',
        );
        expect(await db.recurringBillsDao.getAll(), billsBefore);
        expect(await db.savingsGoalsDao.getAll(), goalsBefore);
      }
    },
  );
}
