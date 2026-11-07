import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/app_providers.dart';
import '../../app/providers/auth_providers.dart';
import '../../app/theme/app_spacing.dart';
import '../../data/local/database/app_database.dart';
import '../../data/auth/browser_session.dart';
import '../../data/repositories/backup_repository.dart';
import '../../shared/widgets/loading_state.dart';
import 'cloud_account_panel.dart';

class LegacyMigrationGate extends ConsumerStatefulWidget {
  const LegacyMigrationGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<LegacyMigrationGate> createState() =>
      _LegacyMigrationGateState();
}

class _LegacyMigrationGateState extends ConsumerState<LegacyMigrationGate> {
  AppDatabase? _legacy;
  BackupImportPreview? _preview;
  bool _checked = false;
  bool _skipped = false;
  bool _busy = false;
  bool _exported = false;
  bool _confirmedBackup = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _inspect();
  }

  Future<void> _inspect() async {
    if (ref.read(cloudStoreProvider) == null) {
      if (mounted) setState(() => _checked = true);
      return;
    }
    try {
      final account = ref.read(currentAccountProvider)!;
      if (ref.read(cloudStoreProvider)!.legacyMigrated) return;
      if (legacyOwner != null && legacyOwner != account.uid) return;
      final settings = await ref.read(settingsRepositoryProvider).getSettings();
      if (settings?.onboardingCompleted == true) return;
      final legacy = _legacy = AppDatabase.defaults();
      final wallets = await legacy.walletsDao.getAll();
      final categories = await legacy.categoriesDao.getAll();
      if (wallets.isEmpty || categories.isEmpty) return;
      final payload = await BackupRepository(legacy).exportPayload();
      if (mounted) {
        setState(
          () => _preview = BackupRepository(
            legacy,
          ).previewFromJson(jsonEncode(payload)),
        );
      }
    } catch (_) {
      // Never upload or delete an unreadable legacy database automatically.
      if (mounted) {
        setState(
          () => _message =
              'Data browser lama belum bisa dibaca. '
              'Data tersebut tetap disimpan dan belum dipindahkan.',
        );
      }
    } finally {
      if (mounted) setState(() => _checked = true);
    }
  }

  @override
  void dispose() {
    _legacy?.close();
    super.dispose();
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await BackupRepository(_legacy!).exportJson();
      if (mounted) setState(() => _exported = true);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Cadangan belum bisa diunduh. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _migrate() async {
    final store = ref.read(cloudStoreProvider)!;
    final repository = ref.read(backupRepositoryProvider);
    final payload = Map<String, dynamic>.from(_preview!.payload)
      ..remove('exported_at');
    final key = sha256.convert(utf8.encode(jsonEncode(payload))).toString();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      rememberLegacyOwner(ref.read(currentAccountProvider)!.uid);
      await store.migrate(key, () => repository.restoreImport(_preview!));
      if (mounted) setState(() => _skipped = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Data belum dipindahkan. Periksa koneksi dan coba lagi. '
              'Jika akun sudah berisi data, gunakan impor cadangan di Pengaturan. Data lokal tetap utuh.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const LoadingState(message: 'Memeriksa data browser lama');
    }
    if (_skipped || (_preview == null && _message == null)) return widget.child;
    final theme = Theme.of(context);
    final account = ref.watch(currentAccountProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.webMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Pindahkan data browser?',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Data lokal lama dapat dipindahkan ke ${account?.email ?? 'akun Google ini'}. '
                    'Simpan cadangan sebelum melanjutkan. Data lokal lama tetap dipertahankan.',
                  ),
                  if (_preview != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '${_preview!.transactions} transaksi · ${_preview!.wallets} dompet · ${_preview!.budgets} anggaran',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    OutlinedButton(
                      onPressed: _busy ? null : _export,
                      child: const Text('Unduh cadangan JSON'),
                    ),
                    if (_exported)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Saya sudah menyimpan file cadangan'),
                        value: _confirmedBackup,
                        onChanged: _busy
                            ? null
                            : (value) => setState(
                                () => _confirmedBackup = value ?? false,
                              ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: _busy || !_confirmedBackup ? null : _migrate,
                      child: Text(
                        _busy ? 'Memproses...' : 'Pindahkan ke akun ini',
                      ),
                    ),
                  ],
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      child: Text(
                        _message!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _skipped = true),
                    child: const Text('Lanjutkan tanpa memindahkan'),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const CloudAccountPanel(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
