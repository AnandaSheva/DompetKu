import 'package:flutter_test/flutter_test.dart';
import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/store/cloud_codec.dart';

void main() {
  test('cloud mapping preserves integer Rupiah, defaults, nulls and dates', () {
    final now = DateTime(2026, 11, 7);
    final map = companionToCloud(
      WalletEntriesCompanion.insert(
        name: 'Tunai',
        type: 'cash',
        createdAt: now,
        updatedAt: now,
      ),
      id: 42,
      defaults: {'initialBalance': 0, 'isArchived': false},
    );
    final row = WalletEntry.fromJson(map);
    expect(row.id, 42);
    expect(row.initialBalance, 0);
    expect(row.isArchived, false);
    expect(row.createdAt, now);
    expect(map['initialBalance'], isA<int>());
    final transfer = companionToCloud(
      TransactionEntriesCompanion.insert(
        type: 'transfer',
        amount: 5000,
        walletId: 1,
        date: now,
        createdAt: now,
        updatedAt: now,
      ),
      id: 12,
      defaults: {'categoryId': null, 'transferWalletId': 2, 'note': null},
    );
    expect(TransactionEntry.fromJson(transfer).transferWalletId, 2);
    expect(transfer['categoryId'], isNull);
  });

  test('cross-device IDs are positive unique JavaScript-safe integers', () {
    final ids = {for (var i = 0; i < 10000; i++) newCloudId()};
    expect(ids.length, 10000);
    expect(ids.every((id) => id > 0 && id <= 9007199254740991), true);
  });
}
