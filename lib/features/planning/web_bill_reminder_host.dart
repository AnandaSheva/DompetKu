import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/auth_providers.dart';
import '../../app/providers/bill_reminder_providers.dart';
import 'planning_page.dart';
import 'widgets/bill_notification_dialogs.dart';

/// Starts only inside the initialized, authenticated account's app tree.
class WebBillReminderHost extends ConsumerStatefulWidget {
  const WebBillReminderHost({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<WebBillReminderHost> createState() =>
      _WebBillReminderHostState();
}

class _WebBillReminderHostState extends ConsumerState<WebBillReminderHost>
    with WidgetsBindingObserver {
  bool _openingBills = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          ref.read(currentAccountProvider) == null ||
          _openingBills) {
        return;
      }
      if (ref.read(billReminderProvider.notifier).takeRecommendation()) {
        unawaited(showBillNotificationRecommendation(context, ref));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(currentAccountProvider) != null) {
      unawaited(ref.read(billReminderProvider.notifier).refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(currentAccountProvider) != null) {
      ref.watch(billReminderProvider);
      ref.listen(billReminderProvider, (_, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              !_openingBills &&
              ref.read(billReminderProvider.notifier).takeRecommendation()) {
            unawaited(showBillNotificationRecommendation(context, ref));
          }
        });
      });
      ref.listen(billReminderProvider.select((value) => value.openRequest), (
        _,
        request,
      ) {
        if (request == 0 || _openingBills) return;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted || _openingBills || ref.read(sessionClosingProvider)) {
            return;
          }
          _openingBills = true;
          await Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const PlanningPage()));
          _openingBills = false;
        });
      });
    }
    return widget.child;
  }
}
