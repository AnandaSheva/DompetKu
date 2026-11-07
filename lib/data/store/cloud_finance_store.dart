import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Insertable;

import '../local/database/app_database.dart';
import '../auth/browser_session.dart';
import '../local/seed/default_seed_data.dart';
import 'cloud_codec.dart';
import 'finance_store.dart';

class CloudStatus {
  const CloudStatus({
    this.loading = true,
    this.pending = false,
    this.fromCache = false,
    this.error,
    this.dataset = '',
  });

  final bool loading;
  final bool pending;
  final bool fromCache;
  final String? error;
  final String dataset;

  String get label =>
      error ??
      (loading
          ? 'Memuat data akun'
          : pending
          ? 'Menunggu sinkronisasi'
          : fromCache
          ? 'Data offline dari perangkat ini'
          : 'Tersimpan di cloud');
}

String cloudErrorMessage(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => 'Akses data ditolak. Periksa aturan Firestore.',
      'resource-exhausted' =>
        'Kuota Firebase habis. Coba lagi setelah kuota pulih.',
      'unavailable' || 'deadline-exceeded' =>
        'Koneksi terputus. Perubahan menunggu sinkronisasi.',
      'failed-precondition' =>
        'Penyimpanan belum siap. Tutup tab DompetKu lainnya lalu coba lagi.',
      _ => 'Data cloud belum bisa disimpan. Coba lagi atau unduh cadangan.',
    };
  }
  if (error is TimeoutException) {
    return 'Koneksi belum tersedia. Coba lagi saat terhubung ke internet.';
  }
  return 'Data akun belum bisa dimuat. Coba lagi.';
}

/// One shared subscription per collection, scoped to a Firebase UID.
/// Imports/reset are staged in a fresh dataset. Only a successful atomic
/// pointer switch makes the replacement visible on any device.
class CloudFinanceStore implements FinanceStore {
  CloudFinanceStore(this.firestore, this.uid) {
    _transactions = _CloudTable(
      this,
      'transactions',
      TransactionEntry.fromJson,
      defaults: {'categoryId': null, 'transferWalletId': null, 'note': null},
      compare: (a, b) => b.date.compareTo(a.date),
    );
    _wallets = _CloudTable(
      this,
      'wallets',
      WalletEntry.fromJson,
      defaults: {'initialBalance': 0, 'isArchived': false},
      compare: (a, b) => a.id.compareTo(b.id),
    );
    _categories = _CloudTable(
      this,
      'categories',
      CategoryEntry.fromJson,
      defaults: {'isDefault': false, 'isArchived': false},
      compare: (a, b) {
        final group = a.groupName.compareTo(b.groupName);
        return group == 0 ? a.name.compareTo(b.name) : group;
      },
    );
    _budgets = _CloudTable(
      this,
      'budgets',
      BudgetEntry.fromJson,
      defaults: {'categoryId': null},
      compare: (a, b) => b.month.compareTo(a.month),
    );
    _settings = _CloudTable(
      this,
      'settings',
      AppSettingEntry.fromJson,
      defaults: {
        'userName': null,
        'currency': 'IDR',
        'themeMode': 'system',
        'hideBalance': false,
        'onboardingCompleted': false,
        'monthlyResetDay': 1,
      },
    );
    _templates = _CloudTable(
      this,
      'quick_templates',
      QuickTemplateEntry.fromJson,
      defaults: {'defaultAmount': null, 'categoryId': null, 'walletId': null},
    );
    transactionsDao = _CloudTransactions(this);
    walletsDao = _CloudWallets(this);
    categoriesDao = _CloudCategories(this);
    budgetsDao = _CloudBudgets(this);
    appSettingsDao = _CloudSettings(this);
    seedDao = _CloudSeed(this);
    backupDao = _CloudBackup(this);
  }

  final FirebaseFirestore firestore;
  final String uid;
  late final _CloudTable<TransactionEntry> _transactions;
  late final _CloudTable<WalletEntry> _wallets;
  late final _CloudTable<CategoryEntry> _categories;
  late final _CloudTable<BudgetEntry> _budgets;
  late final _CloudTable<AppSettingEntry> _settings;
  late final _CloudTable<QuickTemplateEntry> _templates;
  @override
  late final TransactionsStore transactionsDao;
  @override
  late final WalletsStore walletsDao;
  @override
  late final CategoriesStore categoriesDao;
  @override
  late final BudgetsStore budgetsDao;
  @override
  late final SettingsStore appSettingsDao;
  @override
  late final SeedStore seedDao;
  @override
  late final BackupStore backupDao;

  final _statuses = StreamController<CloudStatus>.broadcast(sync: true);
  CloudStatus status = const CloudStatus();
  Stream<CloudStatus> get statuses => Stream<CloudStatus>.multi((sink) {
    final subscription = _statuses.stream.listen(
      sink.add,
      onError: sink.addError,
    );
    sink.add(status);
    sink.onCancel = subscription.cancel;
  });
  DocumentReference<Map<String, dynamic>> get _profile =>
      firestore.collection('users').doc(uid);
  List<_CloudTable<dynamic>> get _tables => [
    _wallets,
    _categories,
    _transactions,
    _budgets,
    _settings,
    _templates,
  ];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  String _dataset = '';
  String? _lastError;
  int _pending = 0;
  bool _closed = false;
  bool _loading = true;
  bool _allowCache = false;
  Future<void> _binding = Future.value();
  final Object _transactionZone = Object();
  final Object _replacementZone = Object();
  bool _replacing = false;
  String? _migrationKey;
  bool legacyMigrated = false;
  final _writes = <_QueuedWrite>[];

  CollectionReference<Map<String, dynamic>> collection(
    String name, {
    String? dataset,
  }) =>
      _profile.collection('datasets').doc(dataset ?? _dataset).collection(name);

  Future<void> initialize() async {
    DocumentSnapshot<Map<String, dynamic>> profile;
    try {
      profile = await _profile
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 12));
    } catch (error) {
      if (error is FirebaseException &&
          error.code != 'unavailable' &&
          error.code != 'deadline-exceeded') {
        rethrow;
      }
      profile = await _profile.get(const GetOptions(source: Source.cache));
      if (!profile.exists) rethrow;
      _allowCache = true;
    }
    if (!profile.exists) {
      await firestore.runTransaction((transaction) async {
        final latest = await transaction.get(_profile);
        if (latest.exists) return;
        final now = DateTime.now();
        var id = 0;
        for (final row in DefaultSeedData.wallets(now)) {
          final data = companionToCloud(
            row,
            defaults: _wallets.defaults,
            id: ++id,
          );
          transaction.set(
            collection('wallets', dataset: 'initial').doc('$id'),
            data,
          );
        }
        id = 0;
        for (final row in DefaultSeedData.categories(now)) {
          final data = companionToCloud(
            row,
            defaults: _categories.defaults,
            id: ++id,
          );
          transaction.set(
            collection('categories', dataset: 'initial').doc('$id'),
            data,
          );
        }
        transaction.set(
          collection('settings', dataset: 'initial').doc('1'),
          companionToCloud(
            DefaultSeedData.settings(now),
            defaults: _settings.defaults,
            id: 1,
          ),
        );
        transaction.set(_profile, {
          'schemaVersion': 1,
          'activeDataset': 'initial',
          'createdAt': now.millisecondsSinceEpoch,
          'legacyMigration': null,
          'retiredDatasets': <String>[],
        });
      }, timeout: const Duration(seconds: 15));
      profile = await _profile.get(const GetOptions(source: Source.server));
    }
    legacyMigrated = profile.data()?['legacyMigration'] != null;
    _loadPending();
    await _bind(profile.data()!['activeDataset'] as String);
    for (final write in List.of(_writes)) {
      _send(write);
    }
    if (!_allowCache) {
      unawaited(
        _cleanRetiredDatasets().catchError((Object error) {
          _lastError =
              'Data lama belum selesai dibersihkan. Coba sinkronkan lagi.';
          _emit();
        }),
      );
    }
    _profileSub = _profile.snapshots().listen(
      (snapshot) {
        legacyMigrated = snapshot.data()?['legacyMigration'] != null;
        final dataset = snapshot.data()?['activeDataset'] as String?;
        if (dataset != null && dataset != _dataset) {
          _binding = _binding.then((_) => _bind(dataset)).catchError((
            Object error,
          ) {
            _lastError = cloudErrorMessage(error);
            _emit();
          });
        }
      },
      onError: (Object error) {
        _lastError = cloudErrorMessage(error);
        _emit();
      },
    );
  }

  Future<void> _bind(String dataset) async {
    if (_closed || dataset == _dataset) return;
    _dataset = dataset;
    _loading = true;
    _emit();
    await Future.wait(
      _tables.map((table) => table.bind(allowCache: _allowCache)),
    );
    if (_closed) return;
    _loading = false;
    _emit();
  }

  void _emit() {
    if (_closed) return;
    status = CloudStatus(
      loading: _loading,
      dataset: _dataset,
      pending:
          _pending > 0 ||
          _writes.isNotEmpty ||
          _tables.any((table) => table.pending),
      fromCache: _tables.any((table) => table.fromCache),
      error: _lastError,
    );
    _statuses.add(status);
  }

  /// Returns once accepted into the SDK's local write queue. Server failures
  /// stay visible in CloudStatus; they are never presented as a cloud success.
  void _submit(List<_Mutation> rows) {
    if (_closed) throw StateError('Sesi telah berakhir.');
    // A later edit supersedes the same document in an earlier rejected write.
    // Otherwise retrying an older failure could overwrite the user's new edit.
    final keys = {for (final row in rows) '${row.name}/${row.id}'};
    for (final earlier in _writes.where((write) => write.dataset == _dataset)) {
      earlier.rows.removeWhere((row) => keys.contains('${row.name}/${row.id}'));
    }
    _writes.removeWhere((write) => write.rows.isEmpty);
    final write = _QueuedWrite(_dataset, rows);
    _writes.add(write);
    _persistPending();
    for (final table in _tables) {
      table.refresh();
    }
    _send(write);
  }

  void _send(_QueuedWrite write) {
    if (_closed || write.sending) return;
    write.sending = true;
    final batch = firestore.batch();
    for (final row in write.rows) {
      row.apply(
        batch,
        collection(row.name, dataset: write.dataset).doc('${row.id}'),
      );
    }
    _emit();
    write.completion = batch
        .commit()
        .then(
          (_) {
            _writes.remove(write);
            if (_writes.isEmpty) _lastError = null;
            _persistPending();
          },
          onError: (Object error) {
            write.sending = false;
            if (_writes.contains(write)) _lastError = cloudErrorMessage(error);
          },
        )
        .whenComplete(() {
          for (final table in _tables) {
            table.refresh();
          }
          _emit();
        });
  }

  void _persistPending() {
    try {
      savePendingWrites(
        uid,
        _writes.isEmpty
            ? null
            : jsonEncode(
                _writes
                    .map(
                      (write) => {
                        'dataset': write.dataset,
                        'rows': write.rows
                            .map(
                              (row) => {
                                'name': row.name,
                                'id': row.id,
                                'data': row.data,
                              },
                            )
                            .toList(),
                      },
                    )
                    .toList(),
              ),
      );
    } catch (_) {
      _lastError =
          'Cache browser penuh. Biarkan tab terbuka dan unduh cadangan.';
    }
  }

  void _loadPending() {
    final raw = readPendingWrites(uid);
    if (raw == null) return;
    try {
      for (final item in jsonDecode(raw) as List) {
        final rows = [
          for (final row in item['rows'] as List)
            _Mutation(
              row['name'] as String,
              row['id'] as int,
              row['data'] == null
                  ? null
                  : Map<String, dynamic>.from(row['data'] as Map),
            ),
        ];
        if (rows.length > 450 ||
            rows.any(
              (row) => !_tables.any((table) => table.name == row.name),
            )) {
          throw const FormatException();
        }
        _writes.add(_QueuedWrite(item['dataset'] as String, rows));
      }
    } catch (_) {
      _lastError =
          'Antrean lokal belum bisa dibaca. Simpan cadangan sebelum menghapus data browser.';
    }
  }

  Map<int, Map<String, dynamic>> overlay(
    String name,
    Map<int, Map<String, dynamic>> source,
  ) {
    final result = Map<int, Map<String, dynamic>>.from(source);
    for (final write in _writes.where((write) => write.dataset == _dataset)) {
      for (final row in write.rows.where((row) => row.name == name)) {
        if (row.data == null) {
          result.remove(row.id);
        } else {
          result[row.id] = row.data!;
        }
      }
    }
    return result;
  }

  void write(String name, int id, Map<String, dynamic>? data) {
    if (_closed) throw StateError('Sesi telah berakhir.');
    final mutation = _Mutation(name, id, data);
    final buffered = Zone.current[_transactionZone] as List<_Mutation>?;
    if (buffered != null) {
      buffered.add(mutation);
      return;
    }
    _submit([mutation]);
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    if (Zone.current[_transactionZone] != null) return action();
    if (_replacing) throw StateError('Pemulihan data masih berlangsung.');
    final buffer = <_Mutation>[];
    final replacing = <bool>[false];
    final result = await runZoned(
      action,
      zoneValues: {_transactionZone: buffer, _replacementZone: replacing},
    );
    if (replacing.first) {
      await _replaceDataset(buffer);
    } else if (buffer.isNotEmpty) {
      if (buffer.length > 450) {
        throw StateError('Terlalu banyak perubahan sekaligus.');
      }
      _submit(buffer);
    }
    return result;
  }

  Future<void> _replaceDataset(List<_Mutation> rows) async {
    _replacing = true;
    _pending++;
    _emit();
    final oldDataset = _dataset;
    final nextDataset = _migrationKey == null
        ? _profile.collection('datasets').doc().id
        : 'legacy_$_migrationKey';
    try {
      await waitForSync();
      final profile = await _profile.get(
        const GetOptions(source: Source.server),
      );
      if (_migrationKey != null && profile.data()?['legacyMigration'] != null) {
        throw StateError('Data lokal sudah pernah dipindahkan ke akun ini.');
      }
      for (var start = 0; start < rows.length; start += 400) {
        final batch = firestore.batch();
        for (final row in rows.skip(start).take(400)) {
          row.apply(
            batch,
            collection(row.name, dataset: nextDataset).doc('${row.id}'),
          );
        }
        await batch.commit().timeout(const Duration(seconds: 20));
      }
      await firestore.runTransaction((transaction) async {
        final current = await transaction.get(_profile);
        if (current.data()?['activeDataset'] != oldDataset ||
            (_migrationKey != null &&
                current.data()?['legacyMigration'] != null)) {
          throw StateError(
            'Data berubah di perangkat lain. Muat ulang sebelum melanjutkan.',
          );
        }
        transaction.update(_profile, {
          'activeDataset': nextDataset,
          'retiredDatasets': FieldValue.arrayUnion([oldDataset]),
          if (_migrationKey != null) 'legacyMigration': _migrationKey,
        });
      }, timeout: const Duration(seconds: 15));
      // Delete the previous generation only after a verified pointer switch.
      await _bind(nextDataset);
      _lastError = null;
      try {
        await _cleanRetiredDatasets();
      } catch (_) {
        _lastError =
            'Data aktif sudah diganti. Pembersihan data lama belum selesai; coba sinkronkan lagi.';
      }
    } catch (error) {
      _lastError = cloudErrorMessage(error);
      rethrow;
    } finally {
      _pending--;
      _replacing = false;
      _emit();
    }
  }

  Future<void> migrate(String key, Future<void> Function() restore) async {
    if (_migrationKey != null) throw StateError('Migrasi masih berlangsung.');
    _migrationKey = key;
    try {
      // A legacy import is only offered before the account has been used.
      if ((await appSettingsDao.getSettings())?.onboardingCompleted == true ||
          (await transactionsDao.getAll()).isNotEmpty) {
        throw StateError(
          'Akun sudah memiliki data. Gunakan impor cadangan dengan konfirmasi penggantian.',
        );
      }
      await restore();
    } finally {
      _migrationKey = null;
    }
  }

  Future<void> waitForSync() async {
    await Future.wait([
      for (final write in List.of(_writes))
        if (write.completion != null) write.completion!,
    ]).timeout(const Duration(seconds: 15));
    await firestore.waitForPendingWrites().timeout(const Duration(seconds: 15));
    if (_writes.isNotEmpty) {
      throw StateError(_lastError ?? 'Perubahan belum tersimpan di cloud.');
    }
  }

  Future<void> retry() async {
    await firestore.enableNetwork();
    _lastError = null;
    for (final write in List.of(_writes)) {
      _send(write);
    }
    try {
      await _cleanRetiredDatasets();
    } catch (_) {
      _lastError =
          'Pembersihan data lama belum selesai. Periksa koneksi dan kuota.';
    }
    _emit();
  }

  Future<void> _cleanRetiredDatasets() async {
    final profile = await _profile.get(const GetOptions(source: Source.server));
    final retired = profile.data()?['retiredDatasets'] as List? ?? [];
    for (final dataset in retired.whereType<String>()) {
      if (_closed ||
          dataset == profile.data()?['activeDataset'] ||
          !RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(dataset)) {
        continue;
      }
      for (final table in _tables) {
        while (!_closed) {
          final documents = await collection(
            table.name,
            dataset: dataset,
          ).limit(400).get(const GetOptions(source: Source.server));
          if (documents.docs.isEmpty) break;
          final batch = firestore.batch();
          for (final doc in documents.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit().timeout(const Duration(seconds: 20));
        }
      }
      if (!_closed) {
        await _profile.update({
          'retiredDatasets': FieldValue.arrayRemove([dataset]),
        });
      }
    }
  }

  @override
  Future<List<QuickTemplateEntry>> getQuickTemplates() => _templates.getAll();

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _profileSub?.cancel();
    await Future.wait(_tables.map((table) => table.close()));
    await _statuses.close();
  }
}

class _QueuedWrite {
  _QueuedWrite(this.dataset, this.rows);
  final String dataset;
  final List<_Mutation> rows;
  bool sending = false;
  Future<void>? completion;
}

class _Mutation {
  const _Mutation(this.name, this.id, this.data);
  final String name;
  final int id;
  final Map<String, dynamic>? data;
  void apply(
    WriteBatch batch,
    DocumentReference<Map<String, dynamic>> reference,
  ) {
    if (data == null) {
      batch.delete(reference);
    } else {
      batch.set(reference, data!);
    }
  }
}

class _CloudTable<T> {
  _CloudTable(
    this.store,
    this.name,
    this.decode, {
    this.defaults = const {},
    this.compare,
  });
  final CloudFinanceStore store;
  final String name;
  final T Function(Map<String, dynamic>) decode;
  final Map<String, dynamic> defaults;
  final int Function(T, T)? compare;
  final _events = StreamController<List<T>>.broadcast(sync: true);
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  Completer<void> _ready = Completer<void>();
  List<T> _rows = [];
  Map<int, Map<String, dynamic>> _source = {};
  bool pending = false;
  bool fromCache = true;
  bool _closed = false;

  Future<void> bind({required bool allowCache}) async {
    await _subscription?.cancel();
    if (_closed) return;
    _ready = Completer<void>();
    _rows = [];
    _source = {};
    _subscription = store
        .collection(name)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
          try {
            _source = {
              for (final doc in snapshot.docs)
                doc.data()['id'] as int: doc.data(),
            };
            refresh();
            pending = snapshot.metadata.hasPendingWrites;
            fromCache = snapshot.metadata.isFromCache;
            if (!_ready.isCompleted && (allowCache || !fromCache)) {
              _ready.complete();
            }
            store._emit();
          } catch (error, stack) {
            _fail(error, stack);
          }
        }, onError: (Object error, StackTrace stack) => _fail(error, stack));
    await _ready.future.timeout(const Duration(seconds: 20));
  }

  void refresh() {
    if (_closed) return;
    _rows = store.overlay(name, _source).values.map(decode).toList();
    if (compare != null) _rows.sort(compare);
    _events.add(_rows);
  }

  void _fail(Object error, StackTrace stack) {
    if (!_ready.isCompleted) _ready.completeError(error, stack);
    if (!_closed) _events.addError(error, stack);
    store._lastError = cloudErrorMessage(error);
    store._emit();
  }

  Stream<List<T>> watch() => Stream<List<T>>.multi((sink) {
    if (_ready.isCompleted) sink.add(List.of(_rows));
    final sub = _events.stream.listen(sink.add, onError: sink.addError);
    sink.onCancel = sub.cancel;
  });

  Future<List<T>> getAll() async {
    await _ready.future;
    return List.of(_rows);
  }

  Future<int> add(Insertable<dynamic> companion, {int? fixedId}) async {
    final data = companionToCloud(companion, defaults: defaults);
    final id = fixedId ?? data['id'] as int? ?? newCloudId();
    data['id'] = id;
    store.write(name, id, data);
    return id;
  }

  Future<void> update(Insertable<dynamic> companion) async {
    final data = companionToCloud(companion, defaults: defaults);
    store.write(name, data['id'] as int, data);
  }

  Future<int> delete(int id) async {
    store.write(name, id, null);
    return 1;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    await _events.close();
  }
}

class _CloudTransactions implements TransactionsStore {
  _CloudTransactions(this.store);
  final CloudFinanceStore store;
  _CloudTable<TransactionEntry> get table => store._transactions;
  @override
  Stream<List<TransactionEntry>> watchAll() => table.watch();
  @override
  Future<List<TransactionEntry>> getAll() => table.getAll();
  @override
  Future<TransactionEntry?> getById(int id) async =>
      (await getAll()).where((row) => row.id == id).firstOrNull;
  @override
  Future<int> add(TransactionEntriesCompanion entry) => table.add(entry);
  @override
  Future<void> updateEntry(TransactionEntriesCompanion entry) =>
      table.update(entry);
  @override
  Future<int> deleteById(int id) => table.delete(id);
  @override
  Future<int> countByWallet(int id) async => (await getAll())
      .where((row) => row.walletId == id || row.transferWalletId == id)
      .length;
  @override
  Future<int> countByCategory(int id) async =>
      (await getAll()).where((row) => row.categoryId == id).length;
}

class _CloudWallets implements WalletsStore {
  _CloudWallets(this.store);
  final CloudFinanceStore store;
  _CloudTable<WalletEntry> get table => store._wallets;
  @override
  Stream<List<WalletEntry>> watchAll() => table.watch();
  @override
  Future<List<WalletEntry>> getAll() => table.getAll();
  @override
  Future<int> add(WalletEntriesCompanion entry) => table.add(entry);
  @override
  Future<void> updateEntry(WalletEntriesCompanion entry) => table.update(entry);
  @override
  Future<int> deleteById(int id) => table.delete(id);
  @override
  Future<int> countDuplicate({required String name, int? exceptId}) async =>
      (await getAll())
          .where(
            (row) =>
                row.id != exceptId &&
                row.name.toLowerCase() == name.toLowerCase(),
          )
          .length;
}

class _CloudCategories implements CategoriesStore {
  _CloudCategories(this.store);
  final CloudFinanceStore store;
  _CloudTable<CategoryEntry> get table => store._categories;
  @override
  Stream<List<CategoryEntry>> watchAll() => table.watch();
  @override
  Future<List<CategoryEntry>> getAll() => table.getAll();
  @override
  Future<List<CategoryEntry>> getByType(String type) async => (await getAll())
      .where(
        (row) => !row.isArchived && (row.type == type || row.type == 'both'),
      )
      .toList();
  @override
  Future<int> add(CategoryEntriesCompanion entry) => table.add(entry);
  @override
  Future<void> updateEntry(CategoryEntriesCompanion entry) =>
      table.update(entry);
  @override
  Future<int> deleteById(int id) => table.delete(id);
  @override
  Future<int> countDuplicate({
    required String name,
    required String type,
    required String groupName,
    int? exceptId,
  }) async => (await getAll())
      .where(
        (row) =>
            row.id != exceptId &&
            row.type == type &&
            row.groupName.toLowerCase() == groupName.toLowerCase() &&
            row.name.toLowerCase() == name.toLowerCase(),
      )
      .length;
}

class _CloudBudgets implements BudgetsStore {
  _CloudBudgets(this.store);
  final CloudFinanceStore store;
  _CloudTable<BudgetEntry> get table => store._budgets;
  @override
  Stream<List<BudgetEntry>> watchAll() => table.watch();
  @override
  Future<List<BudgetEntry>> getAll() => table.getAll();
  @override
  Future<BudgetEntry?> getById(int id) async =>
      (await getAll()).where((row) => row.id == id).firstOrNull;
  @override
  Future<int> add(BudgetEntriesCompanion entry) => table.add(entry);
  @override
  Future<void> updateEntry(BudgetEntriesCompanion entry) => table.update(entry);
  @override
  Future<int> deleteById(int id) => table.delete(id);
  @override
  Future<int> deleteByMonth(String month) async {
    final rows = (await getAll()).where((row) => row.month == month).toList();
    await store.transaction(() async {
      for (final row in rows) {
        await table.delete(row.id);
      }
    });
    return rows.length;
  }

  @override
  Future<int> countDuplicate({
    required String month,
    required int? categoryId,
    int? exceptId,
  }) async => (await getAll())
      .where(
        (row) =>
            row.id != exceptId &&
            row.month == month &&
            row.categoryId == categoryId,
      )
      .length;
}

class _CloudSettings implements SettingsStore {
  _CloudSettings(this.store);
  final CloudFinanceStore store;
  @override
  Stream<AppSettingEntry?> watchSettings() =>
      store._settings.watch().map((rows) => rows.firstOrNull);
  @override
  Future<AppSettingEntry?> getSettings() async =>
      (await store._settings.getAll()).firstOrNull;
  @override
  Future<void> updateSettings(AppSettingEntriesCompanion entry) =>
      store._settings.update(entry);
}

class _CloudSeed implements SeedStore {
  _CloudSeed(this.store);
  final CloudFinanceStore store;
  @override
  Future<int> walletCount() async => (await store._wallets.getAll()).length;
  @override
  Future<int> categoryCount() async =>
      (await store._categories.getAll()).length;
  @override
  Future<int> settingsCount() async => (await store._settings.getAll()).length;
  @override
  Future<void> insertWallets(List<WalletEntriesCompanion> values) async {
    for (final row in values) {
      await store._wallets.add(row);
    }
  }

  @override
  Future<void> insertCategories(List<CategoryEntriesCompanion> values) async {
    for (final row in values) {
      await store._categories.add(row);
    }
  }

  @override
  Future<void> insertQuickTemplates(
    List<QuickTemplateEntriesCompanion> values,
  ) async {
    for (final row in values) {
      await store._templates.add(row);
    }
  }

  @override
  Future<void> insertSettings(AppSettingEntriesCompanion value) async {
    await store._settings.add(value, fixedId: 1);
  }
}

class _CloudBackup implements BackupStore {
  _CloudBackup(this.store);
  final CloudFinanceStore store;
  @override
  Future<void> clearUserData() async {
    final replacing = Zone.current[store._replacementZone] as List<bool>?;
    if (replacing == null) {
      throw StateError('Penggantian data harus menggunakan transaksi.');
    }
    replacing[0] = true;
  }
}
