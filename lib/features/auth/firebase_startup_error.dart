import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_theme.dart';
import '../../data/auth/browser_session.dart';

class FirebaseStartupError extends StatelessWidget {
  const FirebaseStartupError({super.key});
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
                const Text(
                  'Periksa koneksi internet lalu muat ulang halaman. Catatan yang sudah tersimpan tetap berada di akunmu.',
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: reloadBrowser,
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
