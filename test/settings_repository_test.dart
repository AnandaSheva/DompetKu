import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/settings_repository.dart';

void main() {
  late AppDatabase database;
  late SettingsRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = SettingsRepository(database);
    final now = DateTime(2026, 11, 2);
    await database
        .into(database.appSettingEntries)
        .insert(
          AppSettingEntriesCompanion.insert(createdAt: now, updatedAt: now),
        );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'monthly reset day defaults to the first day and persists changes',
    () async {
      expect((await repository.getSettings())?.monthlyResetDay, 1);

      await repository.setMonthlyResetDay(10);

      expect((await repository.getSettings())?.monthlyResetDay, 10);
    },
  );

  test('rejects invalid monthly reset days', () async {
    await expectLater(repository.setMonthlyResetDay(32), throwsArgumentError);
    expect((await repository.getSettings())?.monthlyResetDay, 1);
  });
}
