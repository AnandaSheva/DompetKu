import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../data/store/cloud_finance_store.dart';

class CloudSyncBanner extends StatelessWidget {
  const CloudSyncBanner({super.key, required this.status});
  final CloudStatus status;
  @override
  Widget build(BuildContext context) {
    if (status.loading ||
        (!status.pending && !status.fromCache && status.error == null)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                status.error == null
                    ? Icons.cloud_sync_outlined
                    : Icons.cloud_off_outlined,
                size: 20,
                color: status.error == null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(status.label, style: theme.textTheme.bodySmall),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
