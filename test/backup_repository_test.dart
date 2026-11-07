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
}
