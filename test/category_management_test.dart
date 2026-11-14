import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:dompet_sheva/app/providers/app_providers.dart';
import 'package:dompet_sheva/app/theme/app_theme.dart';
import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/category_repository.dart';
import 'package:dompet_sheva/data/repositories/security_repository.dart';
import 'package:dompet_sheva/data/store/finance_store.dart';
import 'package:dompet_sheva/features/settings/settings_page.dart';
import 'package:dompet_sheva/shared/widgets/top_toast.dart';

void main() {
  tearDown(TopToast.dismiss);

  testWidgets(
    'deletes a custom category and shows success after confirmation',
    (tester) async {
      final repository = _CategoryRepository();
      addTearDown(repository.close);
      await _openDeleteConfirmation(tester, repository);

      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      expect(repository.deleteRequests, 1);
      expect(repository.categories, isEmpty);
      expect(find.text('Kategori berhasil dihapus.'), findsOneWidget);
      expect(find.text('Kategori Uji'), findsNothing);
      TopToast.dismiss();
    },
  );

  testWidgets('shows why a category cannot be deleted and keeps it', (
    tester,
  ) async {
    const message = 'Kategori bawaan tidak bisa dihapus. Gunakan Nonaktifkan.';
    final repository = _CategoryRepository(blockedMessage: message);
    addTearDown(repository.close);
    await _openDeleteConfirmation(tester, repository);

    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(repository.categories, hasLength(1));
    expect(find.text(message), findsOneWidget);
    expect(find.text('Kategori Uji'), findsOneWidget);
    TopToast.dismiss();
  });

  testWidgets('canceling confirmation does not delete the category', (
    tester,
  ) async {
    final repository = _CategoryRepository();
    addTearDown(repository.close);
    await _openDeleteConfirmation(tester, repository);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(repository.deleteRequests, 0);
    expect(repository.categories, hasLength(1));
    expect(find.text('Kategori Uji'), findsOneWidget);
  });

  testWidgets('shows a storage failure without losing the category', (
    tester,
  ) async {
    final repository = _CategoryRepository(failDeletion: true);
    addTearDown(repository.close);
    await _openDeleteConfirmation(tester, repository);

    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repository.categories, hasLength(1));
    expect(
      find.text('Kategori belum bisa dihapus. Coba lagi.'),
      findsOneWidget,
    );
    TopToast.dismiss();
  });
}

Future<void> _openDeleteConfirmation(
  WidgetTester tester,
  _CategoryRepository repository,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(repository),
        appSettingsProvider.overrideWith((ref) => Stream.value(null)),
        securitySettingsProvider.overrideWith(
          (ref) async => const SecuritySettings(
            pinEnabled: false,
            biometricEnabled: false,
            autoLockMinutes: 1,
            pinLength: 6,
          ),
        ),
        packageInfoProvider.overrideWith(
          (ref) async => PackageInfo(
            appName: 'DompetKu',
            packageName: 'dompet_sheva',
            version: '1.0.0',
            buildNumber: '1',
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: SettingsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Kategori'), 250);
  await tester.tap(find.text('Kategori'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Kategori Uji'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Hapus'));
  await tester.pumpAndSettle();
  expect(find.text('Hapus kategori?'), findsOneWidget);
}

class _CategoryRepository extends CategoryRepository {
  _CategoryRepository({this.blockedMessage, this.failDeletion = false})
    : super(_UnusedStore());

  final String? blockedMessage;
  final bool failDeletion;
  final _changes = StreamController<List<CategoryEntry>>.broadcast();
  final categories = [
    CategoryEntry(
      id: 1,
      name: 'Kategori Uji',
      type: 'expense',
      groupName: 'Pengujian',
      iconKey: 'category',
      colorValue: 0xff2563eb,
      isDefault: false,
      isArchived: false,
      createdAt: DateTime(2026, 11, 14),
      updatedAt: DateTime(2026, 11, 14),
    ),
  ];
  var deleteRequests = 0;

  @override
  Stream<List<CategoryEntry>> watchAll() async* {
    yield List.of(categories);
    yield* _changes.stream;
  }

  @override
  Future<String?> deleteCategory(CategoryEntry category) async {
    deleteRequests++;
    if (failDeletion) throw StateError('Storage unavailable');
    if (blockedMessage != null) return blockedMessage;
    categories.removeWhere((row) => row.id == category.id);
    _changes.add(List.of(categories));
    return null;
  }

  Future<void> close() => _changes.close();
}

class _UnusedStore implements FinanceStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected storage access: ${invocation.memberName}',
  );
}
