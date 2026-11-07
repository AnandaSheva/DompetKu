import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/auth_providers.dart';
import '../../app/providers/app_providers.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../data/auth/browser_session.dart';
import '../../data/auth/web_session_repository.dart';
import '../../data/store/cloud_finance_store.dart';
import '../../shared/widgets/app_confirm_dialog.dart';
import '../../shared/widgets/top_toast.dart';

class CloudAccountPanel extends ConsumerWidget {
  const CloudAccountPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentAccountProvider);
    if (account == null) return const SizedBox.shrink();
    final status =
        ref.watch(cloudStatusProvider).asData?.value ?? const CloudStatus();
    final store = ref.watch(cloudStoreProvider);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      margin: const EdgeInsets.only(bottom: AppSpacing.xxl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            account.name ?? 'Akun Google',
            style: theme.textTheme.titleMedium,
          ),
          if (account.email != null)
            Text(account.email!, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              status.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: status.error == null ? null : theme.colorScheme.error,
              ),
            ),
          ),
          Text(
            trustedDevice
                ? 'Cache offline aktif di perangkat pribadi ini.'
                : 'Cache sementara. Unduh cadangan sebelum menutup tab saat offline.',
            style: theme.textTheme.bodySmall,
          ),
          if (status.error != null)
            TextButton(
              onPressed: store?.retry,
              child: const Text('Coba sinkronkan lagi'),
            ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _signOut(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Keluar akun'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Keluar dari akun?',
      message:
          'Pastikan perubahan sudah tersimpan di cloud. Cache akun di browser ini akan dibersihkan.',
      confirmLabel: 'Keluar akun',
    );
    if (!confirmed || !context.mounted) return;
    final auth = ref.read(authRepositoryProvider);
    final store = ref.read(cloudStoreProvider);
    final controller = ref.read(sessionClosingProvider.notifier);
    // Wait while the account screen stays mounted so the provider is not
    // disposed before its pending writes have reached the server.
    try {
      await store?.waitForSync();
      controller.setClosing(true);
      await endWebSession(auth, store);
    } catch (_) {
      controller.setClosing(false);
      if (!context.mounted) return;
      final backupFirst = await showAppConfirmDialog(
        context: context,
        title: 'Perubahan belum tersinkron',
        message:
            'Tetap di akun ini untuk menunggu sinkronisasi, atau unduh cadangan JSON sebelum keluar.',
        confirmLabel: 'Unduh cadangan',
        cancelLabel: 'Tetap di akun',
      );
      if (!backupFirst || !context.mounted) return;
      try {
        await ref.read(backupRepositoryProvider).exportJson();
        if (!context.mounted) return;
        final saved = await showAppConfirmDialog(
          context: context,
          title: 'Cadangan sudah tersimpan?',
          message:
              'Pastikan file JSON sudah tersimpan. Perubahan yang belum dikirim akan dibersihkan dari browser ini dan dapat dipulihkan melalui impor cadangan.',
          confirmLabel: 'Keluar dan bersihkan',
          danger: true,
        );
        if (!saved || !context.mounted) return;
        controller.setClosing(true);
        await endWebSession(auth, store, discardPending: true);
      } catch (_) {
        controller.setClosing(false);
        if (context.mounted) {
          TopToast.show(
            context,
            'Cadangan atau proses keluar belum berhasil. Data belum dibuang.',
            type: TopToastType.warning,
          );
        }
      }
    }
  }
}

class CloudStartupError extends ConsumerWidget {
  const CloudStartupError({super.key, this.error});
  final Object? error;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.webMaxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Data belum bisa dimuat',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  error is String
                      ? error as String
                      : error == null
                      ? 'Periksa koneksi lalu coba lagi.'
                      : cloudErrorMessage(error!),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () {
                    if (ref.read(cloudStoreProvider) == null) {
                      ref.invalidate(databaseProvider);
                    } else {
                      reloadBrowser();
                    }
                  },
                  child: const Text('Muat ulang'),
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
