import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/auth_providers.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../data/auth/auth_repository.dart';
import '../../data/auth/browser_session.dart';
import '../../shared/widgets/app_brand_mark.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _busy = false;
  bool _trusted = trustedDevice;
  String? _message = takeSessionNotice();

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithGoogle(trusted: _trusted);
    } catch (error) {
      if (mounted) setState(() => _message = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AppBrandMark(size: 80),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  Text(
                    'Keuanganmu,\nselalu terhubung.',
                    style: theme.textTheme.displayMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Masuk ke DompetKu untuk menyimpan catatan keuangan dan membukanya di perangkat lain.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  OutlinedButton(
                    onPressed: _busy ? null : _signIn,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_busy)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(Icons.login_rounded, size: 22),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          _busy ? 'Menghubungkan...' : 'Masuk dengan Google',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _trusted,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _trusted = value ?? false),
                    title: const Text('Ini perangkat pribadi saya'),
                    subtitle: const Text(
                      'Ingat sesi dan simpan cache offline di browser ini.',
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _message!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Data versi web disimpan di Google Firebase sesuai akunmu. Tanpa iklan dan tanpa analytics. '
                    'Pada perangkat bersama, cache hanya tersedia selama tab terbuka. '
                    'Login pertama membutuhkan internet.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
