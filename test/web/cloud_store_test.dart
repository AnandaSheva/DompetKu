@TestOn('browser')
library;

// Browser tests do not launch main.dart's generated web plugin registrant.
// Register these existing transitive web implementations explicitly for tests.
// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Value;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:cloud_firestore_web/cloud_firestore_web.dart';

import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/backup_repository.dart';
import 'package:dompet_sheva/data/repositories/planning_repository.dart';
import 'package:dompet_sheva/data/repositories/transaction_repository.dart';
import 'package:dompet_sheva/data/repositories/wallet_repository.dart';
import 'package:dompet_sheva/data/store/cloud_finance_store.dart';
import 'package:dompet_sheva/data/store/finance_store.dart';
import 'package:dompet_sheva/core/enums/transaction_type.dart';

const options = FirebaseOptions(
  apiKey: 'demo-api-key',
  appId: '1:123456789:web:dompetku',
  messagingSenderId: '123456789',
  projectId: 'demo-dompetku',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FirebaseApp app;
  late FirebaseFirestore firestore;
  late FirebaseAuth auth;
  late CloudFinanceStore store;
  var sequence = 0;
  setUpAll(() {
    final registrar = Registrar();
    FirebaseCoreWeb.registerWith(registrar);
    FirebaseAuthWeb.registerWith(registrar);
    FirebaseFirestoreWeb.registerWith(registrar);
  });

  setUp(() async {
    app = await Firebase.initializeApp(
      name: 'test-${sequence++}',
      options: options,
    ).timeout(const Duration(seconds: 20));
    firestore = FirebaseFirestore.instanceFor(app: app);
    firestore.useFirestoreEmulator('127.0.0.1', 8080);
    firestore.settings = const Settings(persistenceEnabled: false);
    auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator('127.0.0.1', 9099);
    await auth.signInAnonymously().timeout(const Duration(seconds: 20));
    store = CloudFinanceStore(firestore, auth.currentUser!.uid);
    await store.initialize().timeout(const Duration(seconds: 40));
  });
  tearDown(() async {
    await firestore.enableNetwork();
    await store.close();
    await firestore.terminate();
    await auth.signOut();
    await app.delete();
  });

  test('seeds once and shares existing calculations for transfers', () async {
    final wallets = await store.walletsDao.getAll();
    expect(wallets, hasLength(4));
    final categories = (await store.categoriesDao.getByType('income'));
    final repo = TransactionRepository(store);
    await repo.save(
      type: TransactionType.income,
      amount: 100000,
      categoryId: categories.first.id,
      walletId: wallets.first.id,
      date: DateTime.now(),
    );
    await repo.save(
      type: TransactionType.transfer,
      amount: 30000,
      walletId: wallets.first.id,
      transferWalletId: wallets.last.id,
      date: DateTime.now(),
    );
    await store.waitForSync();
    final balances = await WalletRepository(store).watchWalletBalances().first;
    expect(balances.first.balance, 70000);
    expect(balances.last.balance, 30000);
    final second = CloudFinanceStore(firestore, auth.currentUser!.uid);
    await second.initialize();
    expect(await second.transactionsDao.getAll(), hasLength(2));
    expect(await second.walletsDao.getAll(), hasLength(4));
    await second.close();
  });

  test(
    'offline writes return promptly, appear locally, and sync on reconnect',
    () async {
      await firestore.disableNetwork();
      final now = DateTime.now();
      final id = await store.walletsDao
          .add(
            WalletEntriesCompanion.insert(
              name: 'Offline',
              type: 'cash',
              initialBalance: const Value(12000),
              createdAt: now,
              updatedAt: now,
            ),
          )
          .timeout(const Duration(seconds: 2));
      expect(
        (await store.walletsDao.getAll()).any((row) => row.id == id),
        true,
      );
      expect(store.status.pending, true);
      await firestore.enableNetwork();
      await store.waitForSync();
      final remote = await firestore
          .doc(
            'users/${store.uid}/datasets/${store.status.dataset}/wallets/$id',
          )
          .get(const GetOptions(source: Source.server));
      expect(remote.data()?['initialBalance'], 12000);
    },
  );

  test('another account cannot read or overwrite this account', () async {
    final other = await Firebase.initializeApp(
      name: 'other-${sequence++}',
      options: options,
    );
    final otherAuth = FirebaseAuth.instanceFor(app: other);
    await otherAuth.useAuthEmulator('127.0.0.1', 9099);
    await otherAuth.signInAnonymously();
    final db = FirebaseFirestore.instanceFor(app: other)
      ..useFirestoreEmulator('127.0.0.1', 8080);
    final ref = db.doc('users/${store.uid}/datasets/initial/wallets/1');
    await expectLater(
      ref.get(const GetOptions(source: Source.server)),
      throwsA(
        isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        ),
      ),
    );
    await expectLater(ref.set({'id': 1}), throwsA(isA<FirebaseException>()));
    await db.terminate();
    await otherAuth.signOut();
    await other.delete();
  });

  test(
    'large backup switches generation only after every chunk is stored',
    () async {
      final backup = BackupRepository(store);
      final payload = await backup.exportPayload();
      final walletId = (payload['wallets'] as List).first['id'];
      final categoryId = (payload['categories'] as List).firstWhere(
        (row) => row['type'] == 'expense',
      )['id'];
      payload['transactions'] = [
        for (var i = 0; i < 520; i++)
          {
            'id': 1000 + i,
            'type': 'expense',
            'amount': 1000,
            'wallet_id': walletId,
            'category_id': categoryId,
            'transfer_wallet_id': null,
            'date': DateTime(2026, 11, 7).toIso8601String(),
            'note': null,
          },
      ];
      final previous = store.status.dataset;
      await backup.restoreImport(backup.previewFromJson(jsonEncode(payload)));
      await store.transactionsDao.watchAll().firstWhere(
        (rows) => rows.length == 520,
      );
      expect(store.status.dataset, isNot(previous));
      expect(await store.transactionsDao.getAll(), hasLength(520));
      expect(await store.walletsDao.getAll(), hasLength(4));
    },
  );

  test('failed staging leaves active data intact', () async {
    final previous = store.status.dataset;
    await expectLater(
      store.transaction(() async {
        await store.backupDao.clearUserData();
        final now = DateTime.now();
        await store.walletsDao.add(
          WalletEntriesCompanion.insert(
            name: 'Bad',
            type: 'invalid',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }),
      throwsA(isA<FirebaseException>()),
    );
    expect(store.status.dataset, previous);
    expect(await store.walletsDao.getAll(), hasLength(4));
    final profile = await firestore
        .doc('users/${store.uid}')
        .get(const GetOptions(source: Source.server));
    expect(profile.data()?['activeDataset'], previous);
  });
  test(
    'bills and goals sync offline writes and survive staged restore',
    () async {
      final repo = PlanningRepository(store);
      final wallet = (await store.walletsDao.getAll()).first;
      final category = (await store.categoriesDao.getByType('expense')).first;
      final due = DateTime(2026, 1, 31);
      await firestore.disableNetwork();
      await repo.saveBill(
        title: 'Internet',
        amount: 250000,
        categoryId: category.id,
        walletId: wallet.id,
        nextDueDate: due,
        frequency: 'monthly',
      );
      await repo.saveGoal(
        name: 'Dana darurat',
        targetAmount: 10000000,
        savedAmount: 500000,
        targetDate: DateTime(2027, 12, 31),
      );
      expect(await store.recurringBillsDao.getAll(), hasLength(1));
      expect(await store.savingsGoalsDao.getAll(), hasLength(1));
      expect(await store.transactionsDao.getAll(), isEmpty);
      final bill = (await store.recurringBillsDao.getAll()).single;
      await firestore.enableNetwork();
      await store.waitForSync();
      await repo.payBill(bill, paidAt: DateTime(2026, 1, 30));
      expect((await store.transactionsDao.getAll()).single.amount, 250000);
      await store.recurringBillsDao.watchAll().firstWhere(
        (rows) => rows.single.nextDueDate == DateTime(2026, 2, 28),
      );
      expect(
        (await store.recurringBillsDao.getAll()).single.nextDueDate,
        DateTime(2026, 2, 28),
      );
      await firestore.enableNetwork();
      await store.waitForSync();
      final second = CloudFinanceStore(firestore, auth.currentUser!.uid);
      await second.initialize();
      try {
        expect(
          (await second.savingsGoalsDao.getAll()).single.savedAmount,
          500000,
        );
        expect(
          (await second.recurringBillsDao.getAll()).single.nextDueDate,
          DateTime(2026, 2, 28),
        );
        expect(await second.transactionsDao.getAll(), hasLength(1));
      } finally {
        await second.close();
      }
      final backup = BackupRepository(store);
      final payload = await backup.exportPayload();
      await backup.restoreImport(backup.previewFromJson(jsonEncode(payload)));
      expect(
        (await store.savingsGoalsDao.getAll()).single.name,
        'Dana darurat',
      );
      expect(await store.recurringBillsDao.getAll(), hasLength(1));
      await backup.resetData();
      expect(await store.recurringBillsDao.getAll(), isEmpty);
      expect(await store.savingsGoalsDao.getAll(), isEmpty);
    },
  );

  test(
    'stale cloud confirmation cannot roll back a newer paid schedule',
    () async {
      final repo = PlanningRepository(store);
      final wallet = (await store.walletsDao.getAll()).first;
      final category = (await store.categoriesDao.getByType('expense')).first;
      await repo.saveBill(
        title: 'Internet',
        amount: 250000,
        categoryId: category.id,
        walletId: wallet.id,
        nextDueDate: DateTime(2026, 11, 30),
        frequency: 'monthly',
      );
      await store.waitForSync();
      final stale = (await store.recurringBillsDao.getAll()).single;
      await repo.payBill(stale);
      await repo.payBill((await store.recurringBillsDao.getAll()).single);
      final expected = (await store.recurringBillsDao.getAll()).single;
      final payment = (await store.transactionsDao.getAll()).first;
      final advancedStale = stale.copyWith(
        nextDueDate: DateTime(2026, 12, 30),
        updatedAt: DateTime.now(),
      );
      final atomic = store.recurringBillsDao as AtomicBillPayments;
      await expectLater(
        atomic.payAndAdvance(stale, payment.toCompanion(true), advancedStale),
        throwsStateError,
      );
      await expectLater(
        atomic.advanceBill(stale, advancedStale),
        throwsStateError,
      );
      expect(
        (await store.recurringBillsDao.getAll()).single.nextDueDate,
        expected.nextDueDate,
      );
      expect(expected.nextDueDate, DateTime(2027, 1, 30));
      expect(await store.transactionsDao.getAll(), hasLength(2));
    },
  );
}
