import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/browser_session.dart';
import '../../data/notifications/bill_notification_client.dart';
import '../../data/notifications/bill_reminder_batch.dart';
import '../../data/notifications/browser_bill_notifications.dart';
import '../../data/notifications/native_bill_schedule.dart';
import 'auth_providers.dart';
import 'planning_providers.dart';

final billNotificationClientProvider = Provider<BillNotificationClient>((ref) {
  final client = createBillNotificationClient();
  ref.onDispose(client.dispose);
  return client;
});
final billReminderClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

class BillReminderState {
  const BillReminderState({
    this.permission = BillNotificationPermission.unavailable,
    this.enabled = false,
    this.busy = false,
    this.error,
    this.openRequest = 0,
  });

  final BillNotificationPermission permission;
  final bool enabled;
  final bool busy;
  final String? error;
  final int openRequest;

  BillReminderState copyWith({
    BillNotificationPermission? permission,
    bool? enabled,
    bool? busy,
    String? error,
    int? openRequest,
  }) => BillReminderState(
    permission: permission ?? this.permission,
    enabled: enabled ?? this.enabled,
    busy: busy ?? this.busy,
    error: error,
    openRequest: openRequest ?? this.openRequest,
  );
}

final billReminderProvider =
    NotifierProvider.autoDispose<BillReminderController, BillReminderState>(
      BillReminderController.new,
      dependencies: [
        currentAccountProvider,
        webPlatformProvider,
        billNotificationClientProvider,
        billReminderClockProvider,
        recurringBillsProvider,
        cloudStatusProvider,
        sessionClosingProvider,
      ],
    );

class BillReminderController extends Notifier<BillReminderState> {
  late BillNotificationClient _client;
  String? _accountKey;
  Timer? _timer;
  int _revision = 0;
  int _generation = 0;
  bool _checking = false;
  bool _checkAgain = false;

  @override
  BillReminderState build() {
    final generation = ++_generation;
    _accountKey = null;
    _checking = false;
    _checkAgain = false;
    final account = ref.watch(currentAccountProvider);
    final isWeb = ref.watch(webPlatformProvider);
    if (account == null) return const BillReminderState();
    _client = ref.watch(billNotificationClientProvider);
    if (!isWeb && _client is! ScheduledBillNotificationClient) {
      return const BillReminderState();
    }
    final permission = _client.permission;
    if (permission == BillNotificationPermission.unavailable) {
      return const BillReminderState();
    }
    final key = _accountKey = billReminderAccountKey(account.uid);
    final enabled = _client.activate(key, persistent: trustedDevice);
    _invalidate();
    final client = _client;
    final opens = client.openRequests.listen((key) {
      if (_current(generation)) _openBills(key);
    });
    ref.listen(recurringBillsProvider, (_, _) => _changed());
    ref.listen(cloudStatusProvider, (_, _) => _changed());
    ref.listen(sessionClosingProvider, (_, closing) {
      if (closing) {
        _invalidate();
        _client.deactivate(key);
      }
    });
    ref.onDispose(() {
      _timer?.cancel();
      if (_generation == generation) _generation++;
      unawaited(opens.cancel());
      client.deactivate(key);
    });
    scheduleMicrotask(() {
      if (!_current(generation)) return;
      if (!isWeb && client is ScheduledBillNotificationClient) {
        unawaited(
          _prepareNative(generation, client as ScheduledBillNotificationClient),
        );
        return;
      }
      final pending = _client.takePendingOpen();
      if (pending != null) _openBills(pending);
      if (enabled) {
        _startTimer();
        unawaited(check());
      }
    });
    return BillReminderState(
      permission: permission,
      enabled: enabled,
      busy: !isWeb,
    );
  }

  bool _current(int generation) => ref.mounted && _generation == generation;

  Future<void> _prepareNative(
    int generation,
    ScheduledBillNotificationClient scheduler,
  ) async {
    try {
      await _client.prepare();
      if (!_current(generation) || ref.read(sessionClosingProvider)) return;
      state = state.copyWith(
        permission: _client.permission,
        enabled: scheduler.enabled,
        busy: false,
      );
      final pending = _client.takePendingOpen();
      if (pending != null) _openBills(pending);
      if (state.enabled) {
        _startTimer();
        await check();
      }
    } catch (_) {
      if (_current(generation)) {
        state = state.copyWith(
          error: 'Pengingat perangkat belum siap. Coba lagi.',
          busy: false,
        );
      }
    }
  }

  bool takeRecommendation() {
    if (_accountKey == null ||
        state.enabled ||
        state.busy ||
        state.openRequest != 0 ||
        ref.read(sessionClosingProvider)) {
      return false;
    }
    return switch (state.permission) {
      BillNotificationPermission.prompt ||
      BillNotificationPermission.granted ||
      BillNotificationPermission.install => _client.takeRecommendation(),
      _ => false,
    };
  }

  void _openBills(String key) {
    if (ref.mounted &&
        key == _accountKey &&
        !ref.read(sessionClosingProvider)) {
      state = state.copyWith(openRequest: state.openRequest + 1);
    }
  }

  void _invalidate() => _client.revise(++_revision);

  void _changed() {
    final generation = _generation;
    _invalidate();
    scheduleMicrotask(() {
      if (_current(generation)) unawaited(check());
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _invalidate();
      unawaited(check());
    });
  }

  Future<void> setEnabled(bool enabled) async {
    if (_accountKey == null || state.busy) return;
    final generation = _generation;
    // A manual choice also dismisses any future startup recommendation.
    _client.takeRecommendation();
    _invalidate();
    if (!enabled) {
      _timer?.cancel();
      try {
        _client.setEnabled(false);
        if (_client is ScheduledBillNotificationClient) await _client.prepare();
        if (_current(generation)) state = state.copyWith(enabled: false);
      } catch (_) {
        if (_current(generation)) {
          state = state.copyWith(
            error: 'Pengingat belum berhasil dinonaktifkan. Coba lagi.',
          );
        }
      }
      return;
    }
    state = state.copyWith(busy: true);
    try {
      // This call must reach requestPermission synchronously from the tap.
      final permission = await _client.requestPermission();
      if (!_current(generation)) return;
      if (permission != BillNotificationPermission.granted) {
        state = state.copyWith(permission: permission, busy: false);
        return;
      }
      await _client.prepare();
      if (!_current(generation) || ref.read(sessionClosingProvider)) return;
      _client.setEnabled(true);
      if (_client is ScheduledBillNotificationClient) await _client.prepare();
      if (!_current(generation) || ref.read(sessionClosingProvider)) return;
      state = state.copyWith(
        permission: permission,
        enabled: true,
        busy: false,
      );
      _startTimer();
      await check();
    } catch (_) {
      if (!_current(generation)) return;
      state = state.copyWith(
        busy: false,
        permission: _client.permission,
        error:
            'Notifikasi belum bisa diaktifkan. Muat ulang halaman lalu coba lagi.',
      );
    }
  }

  Future<void> check() async {
    if (_accountKey == null ||
        !ref.mounted ||
        !state.enabled ||
        ref.read(sessionClosingProvider)) {
      return;
    }
    final generation = _generation;
    if (_checking) {
      _checkAgain = true;
      return;
    }
    _checking = true;
    try {
      do {
        _checkAgain = false;
        final permission = _client.permission;
        if (state.permission != permission) {
          state = state.copyWith(permission: permission);
        }
        if (permission != BillNotificationPermission.granted) return;
        final cloud = ref.read(cloudStatusProvider).asData?.value;
        final bills = ref.read(recurringBillsProvider);
        // Wait for an authoritative account snapshot, including after payment,
        // dataset replacement, online startup or a pending cloud write.
        if (cloud == null ||
            cloud.loading ||
            cloud.fromCache ||
            cloud.pending ||
            cloud.error != null ||
            bills.isLoading ||
            bills.hasError ||
            !bills.hasValue) {
          if (_client is ScheduledBillNotificationClient &&
              (cloud?.pending == true ||
                  cloud?.loading == true ||
                  bills.hasError)) {
            await (_client as ScheduledBillNotificationClient).replaceSchedule(
              const [],
              accountKey: _accountKey!,
              revision: _revision,
            );
          }
          return;
        }
        final revision = _revision;
        if (_client is ScheduledBillNotificationClient) {
          await (_client as ScheduledBillNotificationClient).replaceSchedule(
            NativeBillReminder.plan(
              bills: bills.requireValue,
              now: ref.read(billReminderClockProvider)(),
              dataset: cloud.dataset,
            ),
            accountKey: _accountKey!,
            revision: revision,
          );
          if (_current(generation) && state.error != null) {
            state = state.copyWith();
          }
          continue;
        }
        final batches = BillReminderBatch.forDay(
          bills: bills.requireValue,
          now: ref.read(billReminderClockProvider)(),
          dataset: cloud.dataset,
        );
        for (final batch in batches) {
          if (!_current(generation) ||
              !state.enabled ||
              revision != _revision) {
            break;
          }
          await _client.showReminder(
            batch,
            accountKey: _accountKey!,
            revision: revision,
          );
        }
        if (_current(generation) && state.error != null) {
          state = state.copyWith();
        }
      } while (_checkAgain &&
          _current(generation) &&
          state.enabled &&
          !ref.read(sessionClosingProvider));
    } catch (_) {
      if (_current(generation)) {
        state = state.copyWith(
          error:
              'Pengingat belum bisa diperbarui. Periksa izin notifikasi lalu coba lagi.',
        );
      }
    } finally {
      if (_current(generation)) _checking = false;
    }
  }

  Future<void> refresh() async {
    if (_accountKey == null) return;
    _invalidate();
    if (_client is ScheduledBillNotificationClient) await _client.prepare();
    state = state.copyWith(permission: _client.permission);
    await check();
  }

  Future<void> testNotification() async {
    if (_accountKey == null || state.busy || !state.enabled) return;
    final generation = _generation;
    state = state.copyWith(busy: true);
    try {
      await _client.showTest();
      if (_current(generation)) {
        state = state.copyWith(busy: false, permission: _client.permission);
      }
    } catch (_) {
      if (_current(generation)) {
        state = state.copyWith(
          busy: false,
          permission: _client.permission,
          error:
              'Notifikasi uji belum bisa ditampilkan. Periksa izin browser dan pengaturan notifikasi perangkat.',
        );
      }
    }
  }
}
