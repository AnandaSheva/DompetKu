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

import '../helpers/legacy_food_fixture.dart';

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

  test(
    'offline wallet deletion syncs logs, pauses bills and survives restore across clients',
    () async {
      final walletRepository = WalletRepository(store);
      final repository = TransactionRepository(store);
      final wallets = await walletRepository.getWallets();
      final source = wallets.first;
      final destination = wallets.last;
      final category = (await store.categoriesDao.getByType('expense')).first;
      await repository.save(
        type: TransactionType.transfer,
        amount: 30000,
        walletId: source.id,
        transferWalletId: destination.id,
        date: DateTime.now(),
      );
      await repository.save(
        type: TransactionType.expense,
        amount: 10000,
        categoryId: category.id,
        walletId: source.id,
        date: DateTime.now(),
      );
      await PlanningRepository(store).saveBill(
        title: 'Internet',
        amount: 10000,
        categoryId: category.id,
        walletId: source.id,
        nextDueDate: DateTime.now(),
        frequency: 'monthly',
      );
      await store.waitForSync();
      final before = await store.transactionsDao.getAll();
      await firestore.disableNetwork();
      await walletRepository.deleteWallet(source.id);
      expect(store.status.pending, true);
      expect((await repository.getDetails()).every((d) => d.isLog), true);
      expect(
        (await walletRepository.getWallets()).any((w) => w.id == source.id),
        false,
      );
      await firestore.enableNetwork();
      await store.waitForSync();
      final second = CloudFinanceStore(firestore, store.uid);
      try {
        await second.initialize();
        final secondWallets = WalletRepository(second);
        expect(
          await secondWallets.getWalletBalance(walletId: source.id),
          isNull,
        );
        expect(
          (await secondWallets.getWalletBalance(
            walletId: destination.id,
          ))!.balance,
          30000,
        );
        expect(await second.transactionsDao.getAll(), before);
        final logs = await TransactionRepository(second).getDetails();
        expect(logs, hasLength(2));
        expect(logs.every((d) => d.isLog), true);
        expect(
          (await second.recurringBillsDao.getAll()).single.isActive,
          false,
        );
        await expectLater(
          TransactionRepository(second).delete(logs.first.transaction.id),
          throwsArgumentError,
        );
        final backup = BackupRepository(second);
        final payload = await backup.exportPayload();
        await backup.restoreImport(backup.previewFromJson(jsonEncode(payload)));
        await second.waitForSync();
        expect(
          (await TransactionRepository(
            second,
          ).getDetails()).every((d) => d.isLog),
          true,
        );
        await secondWallets.addWallet(name: source.name, type: source.type);
        await second.waitForSync();
        expect(
          (await secondWallets.getWallets())
              .singleWhere((w) => w.name == source.name)
              .id,
          isNot(source.id),
        );
        // Reset must still be able to retire and clean up datasets containing logs.
        await backup.resetData();
        expect(await second.transactionsDao.getAll(), isEmpty);
      } finally {
        await second.close();
      }
    },
  );

  test('seeds once and shares existing calculations for transfers', () async {
    final wallets = await store.walletsDao.getAll();
    expect(wallets, hasLength(4));
    final defaults = await store.categoriesDao.getAll();
    expect(
      defaults.singleWhere((row) => row.name == 'Makanan & Minuman').id,
      1,
    );
    expect(
      defaults.where((row) => row.name == 'Makanan' || row.name == 'Minuman'),
      isEmpty,
    );
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
    'existing accounts merge over 450 references into the original Makanan ID on startup',
    () async {
      final legacy = await seedLegacyFoodFixture(store, transactionCount: 502);
      await store.waitForSync();
      final original = await store.transactionsDao.getAll();
      final budgets = await store.budgetsDao.getAll();
      final foodBudget = budgets.singleWhere(
        (row) => row.categoryId == legacy.foodId,
      );
      final template = (await store.getQuickTemplates()).single;
      final bill = (await store.recurringBillsDao.getAll()).single;
      final dataset = store.status.dataset;
      await store.close();
      store = CloudFinanceStore(firestore, auth.currentUser!.uid);

      await store.initialize();
      await store.waitForSync();

      final base = firestore.collection(
        'users/${store.uid}/datasets/$dataset/categories',
      );
      expect(
        (await base
                .doc('${legacy.foodId}')
                .get(const GetOptions(source: Source.server)))
            .data()?['name'],
        'Makanan & Minuman',
      );
      expect(
        (await base
                .doc('${legacy.drinkId}')
                .get(const GetOptions(source: Source.server)))
            .exists,
        false,
      );
      final updated = await firestore
          .collection('users/${store.uid}/datasets/$dataset/transactions')
          .get(const GetOptions(source: Source.server));
      expect(updated.docs, hasLength(502));
      final originalById = {for (final row in original) row.id: row};
      for (final doc in updated.docs) {
        final data = doc.data();
        expect(data['categoryId'], legacy.foodId);
        expect(data['amount'], originalById[data['id']]!.amount);
        expect(data['note'], originalById[data['id']]!.note);
      }
      final merged = await firestore
          .collection('users/${store.uid}/datasets/$dataset/budgets')
          .get(const GetOptions(source: Source.server));
      expect(merged.docs, hasLength(3));
      expect(
        merged.docs
            .singleWhere((doc) => doc.data()['id'] == foodBudget.id)
            .data()['limitAmount'],
        150000,
      );
      for (final (name, id) in [
        ('quick_templates', template.id),
        ('recurring_bills', bill.id),
      ]) {
        final ref = firestore.doc(
          'users/${store.uid}/datasets/$dataset/$name/$id',
        );
        expect(
          (await ref.get(
            const GetOptions(source: Source.server),
          )).data()?['categoryId'],
          legacy.foodId,
        );
      }
      await store.categoriesDao.mergeFoodAndDrink();
      expect(
        (await firestore
                .doc(
                  'users/${store.uid}/datasets/$dataset/budgets/${foodBudget.id}',
                )
                .get(const GetOptions(source: Source.server)))
            .data()?['limitAmount'],
        150000,
      );
    },
  );

  test(
    'online category migration preserves legacy data and pending writes',
    () async {
      final legacy = await seedLegacyFoodFixture(store);
      await store.waitForSync();
      await firestore.disableNetwork();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final now = DateTime.now();
      await store.walletsDao.add(
        WalletEntriesCompanion.insert(
          name: 'Antrean lokal',
          type: 'cash',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await store.categoriesDao.mergeFoodAndDrink().timeout(
        const Duration(seconds: 2),
      );

      expect(
        (await store.categoriesDao.getAll()).any(
          (row) => row.id == legacy.drinkId,
        ),
        true,
      );
      expect(store.status.pending, true);
      await firestore.enableNetwork();
      await store.waitForSync();
      expect(
        (await store.walletsDao.getAll()).any(
          (row) => row.name == 'Antrean lokal',
        ),
        true,
      );
    },
  );

  test(
    'online writes return promptly, appear locally, and sync on reconnect',
    () async {
      await firestore.disableNetwork();
      final now = DateTime.now();
      final id = await store.walletsDao
          .add(
            WalletEntriesCompanion.insert(
              name: 'online',
              type: 'bank',
              initialBalance: const Value(12000),
              reservedBalance: const Value(2000),
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
      expect(remote.data()?['reservedBalance'], 2000);
      expect(
        (await WalletRepository(
          store,
        ).getWalletBalance(walletId: id))!.availableBalance,
        10000,
      );
      final second = CloudFinanceStore(firestore, auth.currentUser!.uid);
      try {
        await second.initialize();
        final wallet = (await second.walletsDao.getAll()).singleWhere(
          (row) => row.id == id,
        );
        expect(wallet.reservedBalance, 2000);
        await WalletRepository(second).updateWallet(
          wallet: wallet,
          name: wallet.name,
          type: wallet.type,
          initialBalance: wallet.initialBalance,
          reservedBalance: 4000,
        );
        await second.waitForSync();
        final synced = await store.walletsDao
            .watchAll()
            .firstWhere(
              (rows) => rows.any(
                (row) => row.id == id && row.reservedBalance == 4000,
              ),
            )
            .timeout(const Duration(seconds: 10));
        expect(synced.singleWhere((row) => row.id == id).initialBalance, 12000);
      } finally {
        await second.close();
      }
    },
  );

  test('legacy bank documents without reserves still load with zero', () async {
    final bank = (await store.walletsDao.getAll()).singleWhere(
      (row) => row.type == 'bank',
    );
    await store.collection('wallets').doc('${bank.id}').update({
      'reservedBalance': FieldValue.delete(),
    });
    final second = CloudFinanceStore(firestore, auth.currentUser!.uid);
    try {
      await second.initialize();
      final restored = (await second.walletsDao.getAll()).singleWhere(
        (row) => row.id == bank.id,
      );
      expect(restored.reservedBalance, 0);
    } finally {
      await second.close();
    }
  });

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
    'bills and goals sync online writes and survive staged restore',
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
