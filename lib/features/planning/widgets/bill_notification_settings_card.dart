import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/bill_reminder_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import 'bill_notification_dialogs.dart';

class BillNotificationSettingsCard extends ConsumerWidget {
  const BillNotificationSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(billReminderProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Notifikasi tagihan',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            label: 'Notifikasi tagihan',
            child: Switch.adaptive(
              value: state.enabled,
              onChanged: state.busy
                  ? null
                  : (enabled) =>
                        setBillNotificationsEnabled(context, ref, enabled),
            ),
          ),
        ],
      ),
    );
  }
}
