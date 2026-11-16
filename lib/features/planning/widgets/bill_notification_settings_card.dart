import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/bill_reminder_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/notifications/bill_notification_client.dart';

class BillNotificationSettingsCard extends ConsumerWidget {
  const BillNotificationSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(billReminderProvider);
    final controller = ref.read(billReminderProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canRequest =
        state.permission == BillNotificationPermission.prompt ||
        state.permission == BillNotificationPermission.granted;
    final active =
        state.enabled && state.permission == BillNotificationPermission.granted;
    final status = switch (state.permission) {
      BillNotificationPermission.unavailable =>
        'Browser ini belum mendukung notifikasi web.',
      BillNotificationPermission.insecure =>
        'Buka DompetKu melalui HTTPS agar izin notifikasi tersedia.',
      BillNotificationPermission.install =>
        'Di iPhone/iPad, tambahkan DompetKu ke Layar Utama lalu buka dari ikon aplikasi untuk mengizinkan notifikasi.',
      BillNotificationPermission.denied =>
        'Izin diblokir. Izinkan notifikasi DompetKu di pengaturan browser/perangkat, lalu tekan Periksa izin.',
      BillNotificationPermission.prompt =>
        'Tekan Aktifkan notifikasi, lalu pilih Izinkan pada permintaan browser.',
      BillNotificationPermission.granted =>
        active
            ? 'Aktif untuk akun ini di browser ini.'
            : 'Izin browser tersedia. Aktifkan pengingat untuk akun ini.',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                active
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Notifikasi tagihan',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (state.enabled)
                Semantics(
                  label: 'Pengingat tagihan H-1 dan hari H',
                  child: Switch.adaptive(
                    value: state.enabled,
                    onChanged: state.busy ? null : controller.setEnabled,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Pengingat H-1 dan hari H saat DompetKu dibuka atau aktif. Tidak berjalan saat aplikasi ditutup.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(status, style: theme.textTheme.bodySmall),
          if (state.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              state.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.readableAccent(
                  AppColors.dangerRed,
                  theme.brightness,
                ),
              ),
            ),
          ],
          if (!state.enabled && canRequest) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: state.busy ? null : () => controller.setEnabled(true),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.iconTileSmall),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
              ),
              child: Text(
                state.busy ? 'Mengaktifkan...' : 'Aktifkan notifikasi',
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (state.permission == BillNotificationPermission.denied ||
              state.error != null) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              onPressed: state.busy ? null : controller.refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Periksa izin'),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Isi notifikasi tidak menampilkan nama tagihan atau nominal. Pengingat menunggu data akun selesai tersinkron.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
