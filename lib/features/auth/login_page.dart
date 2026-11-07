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
  bool _preparing = true;
  bool _sessionReady = false;
  bool _trusted = trustedDevice;
  String? _message = takeSessionNotice();

  @override
  void initState() {
    super.initState();
    _prepareSignIn(clearMessage: false);
  }

  Future<void> _prepareSignIn({bool clearMessage = true}) async {
    setState(() {
      _preparing = true;
      _sessionReady = false;
      if (clearMessage) _message = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .prepareGoogleSignIn(trusted: _trusted);
      if (mounted) setState(() => _sessionReady = true);
    } catch (error) {
      if (mounted) setState(() => _message = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _signIn() async {
    if (_busy || !_sessionReady) return;
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
                    onPressed: _busy || !_sessionReady ? null : _signIn,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_busy || _preparing)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(Icons.login_rounded, size: 22),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          _preparing
                              ? 'Menyiapkan login...'
                              : _busy
                              ? 'Menghubungkan...'
                              : 'Masuk dengan Google',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _trusted,
                    onChanged: _busy || _preparing
                        ? null
                        : (value) {
                            setState(() => _trusted = value ?? false);
                            _prepareSignIn();
                          },
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
                  if (!_preparing && !_sessionReady)
                    TextButton(
                      onPressed: _prepareSignIn,
                      child: const Text('Coba lagi'),
                    ),
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
