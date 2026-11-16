import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/auth_providers.dart';
import '../../../app/providers/bill_reminder_providers.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/notifications/bill_notification_client.dart';

Future<void> showBillNotificationRecommendation(
  BuildContext context,
  WidgetRef ref,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Text('Aktifkan pengingat?'),
    content: const Text(
      'Disarankan agar tagihan tidak terlewat. Pengingat H-1 dan hari H hanya '
      'berjalan saat DompetKu dibuka. Opsional, bisa diubah di Pengaturan.',
    ),
    actionsPadding: const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      0,
      AppSpacing.xl,
      AppSpacing.xl,
    ),
    actionsOverflowButtonSpacing: AppSpacing.sm,
    actions: [
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.iconTile),
        ),
        onPressed: () => Navigator.pop(dialogContext),
        child: const Text('Nanti saja'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.iconTile),
        ),
        onPressed: () {
          // Enter the browser permission request directly from this tap.
          unawaited(setBillNotificationsEnabled(context, ref, true));
          Navigator.pop(dialogContext);
        },
        child: Text(
          ref.read(billReminderProvider).permission ==
                  BillNotificationPermission.install
              ? 'Cara aktifkan'
              : 'Aktifkan',
        ),
      ),
    ],
  ),
);

Future<void> setBillNotificationsEnabled(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  final account = ref.read(currentAccountProvider)?.uid;
  await ref.read(billReminderProvider.notifier).setEnabled(enabled);
  if (!context.mounted ||
      ref.read(currentAccountProvider)?.uid != account ||
      ref.read(sessionClosingProvider)) {
    return;
  }
  final state = ref.read(billReminderProvider);
  if (!enabled) return;
  final message =
      state.error ??
      switch (state.permission) {
        BillNotificationPermission.denied =>
          'Izinkan notifikasi DompetKu di pengaturan browser atau perangkat, lalu periksa kembali.',
        BillNotificationPermission.install =>
          'Tambahkan DompetKu ke Layar Utama, lalu buka dari ikon aplikasi untuk mengaktifkan notifikasi.',
        BillNotificationPermission.insecure =>
          'Buka DompetKu melalui HTTPS untuk mengaktifkan notifikasi.',
        BillNotificationPermission.unavailable =>
          'Browser ini belum mendukung notifikasi web.',
        _ => null,
      };
  if (message == null) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Notifikasi tagihan'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Tutup'),
        ),
        if (state.permission == BillNotificationPermission.denied ||
            state.error != null)
          TextButton(
            onPressed: () {
              unawaited(ref.read(billReminderProvider.notifier).refresh());
              Navigator.pop(dialogContext);
            },
            child: const Text('Periksa izin'),
          ),
      ],
    ),
  );
}
