import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme.dart';
import '../../data/auth/browser_session.dart';

class FirebaseStartupError extends StatelessWidget {
  const FirebaseStartupError({super.key, this.onRetry});
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DompetKu',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('DompetKu belum bisa terhubung'),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  kIsWeb
                      ? 'Periksa koneksi internet lalu muat ulang halaman. Catatan yang sudah tersimpan tetap berada di akunmu.'
                      : 'Periksa koneksi dan konfigurasi aplikasi lalu coba lagi. Data perangkat lama tetap disimpan.',
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: kIsWeb ? reloadBrowser : onRetry,
                  child: const Text('Muat ulang'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
