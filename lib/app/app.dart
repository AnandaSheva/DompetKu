import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/auth/web_auth_gate.dart';
import '../features/auth/cloud_account_panel.dart';
import '../features/auth/cloud_sync_banner.dart';
import '../features/auth/legacy_migration_gate.dart';
import '../data/auth/browser_session.dart';
import 'providers/auth_providers.dart';
import '../features/security/app_lock_gate.dart';
import '../shared/layouts/main_shell.dart';
import '../shared/widgets/loading_state.dart';
import 'providers/app_providers.dart';
import 'theme/app_theme.dart';

class DompetShevaApp extends ConsumerWidget {
  const DompetShevaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(webPlatformProvider)
        ? const WebAuthGate()
        : const FinanceApp();
  }
}

class FinanceApp extends ConsumerWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref
        .watch(appSettingsProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);

    final cloud = ref.watch(cloudStoreProvider);
    final status = cloud == null
        ? null
        : ref.watch(cloudStatusProvider).asData?.value;
    if (status != null) {
      warnBeforeLeaving(status.pending || status.error != null);
    }

    return MaterialApp(
      key: ValueKey(status?.dataset ?? 'local'),
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode(settings?.themeMode),
      builder: (context, child) {
        final brightness = Theme.of(context).colorScheme.brightness;
        final isDark = brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: status == null
              ? child ?? const SizedBox.shrink()
              : Column(
                  children: [
                    CloudSyncBanner(status: status),
                    Expanded(child: child ?? const SizedBox.shrink()),
                  ],
                ),
        );
      },
      home: const AppLockGate(child: _AppGate()),
    );
  }

  ThemeMode _themeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

class _AppGate extends ConsumerWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(appBootstrapProvider);

    final cloud = ref.watch(cloudStoreProvider);
    final cloudStatus = cloud == null
        ? null
        : ref.watch(cloudStatusProvider).asData?.value;
    if (bootstrap.hasValue && cloudStatus?.loading == true) {
      if (cloudStatus?.error != null) {
        return CloudStartupError(error: cloudStatus!.error);
      }
      return const LoadingState(message: 'Menyiapkan data akun');
    }
    return bootstrap.when(
      data: (_) {
        final settings = ref.watch(appSettingsProvider);
        return settings.when(
          data: (value) {
            if (value?.onboardingCompleted ?? false) {
              return const LegacyMigrationGate(child: MainShell());
            }
            return const LegacyMigrationGate(child: OnboardingPage());
          },
          loading: () => const LoadingState(message: 'Menyiapkan data lokal'),
          error: (_, _) => const CloudStartupError(),
        );
      },
      loading: () =>
          const LoadingState(message: 'Menyiapkan ${AppConstants.appName}'),
      error: (error, _) => CloudStartupError(error: error),
    );
  }
}
