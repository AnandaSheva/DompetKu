import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/app_providers.dart';
import '../../app/providers/planning_providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../core/formatters/date_formatter.dart';
import '../../data/local/database/app_database.dart';
import '../../shared/widgets/app_confirm_dialog.dart';
import '../../shared/widgets/app_form_actions.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/pressable_surface.dart';
import '../../shared/widgets/top_toast.dart';
import 'planning_forms.dart';

class PlanningPage extends ConsumerStatefulWidget {
  const PlanningPage({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  ConsumerState<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends ConsumerState<PlanningPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: widget.initialTab,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Perencanaan'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Tagihan'),
            Tab(text: 'Target tabungan'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.webMaxWidth + 40,
          ),
          child: TabBarView(children: [_bills(), _goals()]),
        ),
      ),
    ),
  );

  Widget _bills() {
    final bills = ref.watch(recurringBillsProvider);
    final wallets = ref.watch(walletBalancesProvider).asData?.value ?? [];
    final categories = ref.watch(categoriesProvider).asData?.value ?? [];
    final hidden =
        ref.watch(appSettingsProvider).asData?.value?.hideBalance ?? false;
    return bills.when(
      data: (items) {
        final sorted = [...items]
          ..sort((a, b) {
            if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
            return a.nextDueDate.compareTo(b.nextDueDate);
          });
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            const Text(
              'Atur tagihan rutin. Konfirmasi setiap pembayaran untuk mencatat pengeluaran dan melanjutkan jadwal.',
            ),
            if (kIsWeb) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Di web, mengedit tagihan, mencatat pembayaran, dan mengubah status jadwal memerlukan internet.',
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _busy ? null : () => showRecurringBillForm(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah tagihan'),
            ),
            const SizedBox(height: AppSpacing.xxl),
            if (sorted.isEmpty)
              const EmptyState(
                icon: Icons.event_repeat_rounded,
                title: 'Belum ada tagihan',
                message:
                    'Mulai dari tagihan kos, internet, atau langganan bulanan.',
                compact: true,
              ),
            for (final bill in sorted) ...[
              _PlanningCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            bill.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        PopupMenuButton<String>(
                          enabled: !_busy,
                          tooltip: 'Kelola tagihan ${bill.title}',
                          onSelected: (action) => _billAction(action, bill),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit jadwal'),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(
                                bill.isActive
                                    ? 'Jeda tagihan'
                                    : 'Aktifkan tagihan',
                              ),
                            ),
                            if (bill.isActive)
                              const PopupMenuItem(
                                value: 'skip',
                                child: Text('Lewati periode ini'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Hapus jadwal'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      CurrencyFormatter.rupiah(bill.amount, hidden: hidden),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${billFrequencyLabels[bill.frequency]} · ${DateFormatter.shortDateLabel(bill.nextDueDate)}',
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${wallets.where((item) => item.wallet.id == bill.walletId).firstOrNull?.wallet.name ?? 'Dompet tidak tersedia'} · ${categories.where((item) => item.id == bill.categoryId).firstOrNull?.name ?? 'Kategori tidak tersedia'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _StatusLabel(
                      label: _billStatus(bill),
                      warning:
                          bill.isActive &&
                          !bill.nextDueDate.isAfter(
                            DateFormatter.startOfDay(DateTime.now()),
                          ),
                    ),
                    if (bill.isActive) ...[
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _busy ? null : () => _payBill(bill),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Catat pembayaran'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _LoadError(
        message: 'Tagihan belum bisa dimuat.',
        onRetry: () => ref.invalidate(recurringBillsProvider),
      ),
    );
  }

  Widget _goals() {
    final goals = ref.watch(savingsGoalsProvider);
    final hidden =
        ref.watch(appSettingsProvider).asData?.value?.hideBalance ?? false;
    return goals.when(
      data: (items) => ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          const Text(
            'Tentukan tujuan dan perbarui jumlah yang sudah kamu sisihkan. Progres dicatat manual dan tidak mengubah saldo dompet.',
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: _busy ? null : () => showSavingsGoalForm(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah target tabungan'),
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (items.isEmpty)
            const EmptyState(
              icon: Icons.savings_outlined,
              title: 'Mulai menabung untuk tujuanmu',
              message:
                  'Buat target dana darurat, liburan, atau kebutuhan lainnya.',
              compact: true,
            ),
          for (final goal in items) ...[
            _PlanningCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          goal.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      PopupMenuButton<String>(
                        enabled: !_busy,
                        tooltip: 'Kelola target ${goal.name}',
                        onSelected: (action) {
                          if (action == 'edit') {
                            showSavingsGoalForm(context, goal: goal);
                          } else {
                            _deleteGoal(goal);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit target'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Hapus target'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    CurrencyFormatter.rupiah(goal.savedAmount, hidden: hidden),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'dari ${CurrencyFormatter.rupiah(goal.targetAmount, hidden: hidden)}',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: LinearProgressIndicator(
                      value: (goal.savedAmount / goal.targetAmount).clamp(0, 1),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    goal.savedAmount >= goal.targetAmount
                        ? 'Target tercapai 🎉'
                        : '${hidden ? '•••' : '${(goal.savedAmount / goal.targetAmount * 100).floor()}%'} terkumpul · Sisa ${CurrencyFormatter.rupiah(goal.targetAmount - goal.savedAmount, hidden: hidden)}',
                  ),
                  if (goal.targetDate != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Tenggat ${DateFormatter.shortDateLabel(goal.targetDate!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (goal.savedAmount < goal.targetAmount &&
                        goal.targetDate!.isBefore(
                          DateFormatter.startOfDay(DateTime.now()),
                        ))
                      const _StatusLabel(
                        label: 'Tenggat terlewati',
                        warning: true,
                      ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => showSavingsGoalForm(context, goal: goal),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Perbarui tabungan'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _LoadError(
        message: 'Target tabungan belum bisa dimuat.',
        onRetry: () => ref.invalidate(savingsGoalsProvider),
      ),
    );
  }

  String _billStatus(RecurringBillEntry bill) {
    if (!bill.isActive) return 'Dijeda';
    final day = DateFormatter.startOfDay(bill.nextDueDate);
    final today = DateFormatter.startOfDay(DateTime.now());
    if (day.isBefore(today)) return 'Lewat jatuh tempo';
    if (day == today) return 'Jatuh tempo hari ini';
    return 'Akan datang';
  }

  Future<void> _mutate(Future<bool> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final changed = await action();
      if (changed && mounted) {
        TopToast.show(context, success, type: TopToastType.success);
      }
    } catch (error) {
      if (mounted) {
        TopToast.show(
          context,
          planningError(error),
          type: TopToastType.warning,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _billAction(String action, RecurringBillEntry bill) {
    if (action == 'edit') {
      showRecurringBillForm(context, bill: bill);
      return;
    }
    _mutate(
      () async {
        final repository = ref.read(planningRepositoryProvider);
        if (action == 'toggle') {
          await repository.setBillActive(bill, !bill.isActive);
          return true;
        }
        final confirmed = await showAppConfirmDialog(
          context: context,
          title: action == 'delete'
              ? 'Hapus jadwal tagihan?'
              : 'Lewati periode ini?',
          message: action == 'delete'
              ? 'Jadwal ${bill.title} akan dihapus. Transaksi pembayaran yang sudah dicatat tetap tersimpan.'
              : 'Jadwal ${bill.title} dilanjutkan satu periode tanpa mencatat pengeluaran.',
          confirmLabel: action == 'delete' ? 'Hapus jadwal' : 'Lewati periode',
          danger: action == 'delete',
        );
        if (!confirmed) return false;
        if (action == 'delete') {
          await repository.deleteBill(bill.id);
        } else {
          await repository.skipBill(bill);
        }
        return true;
      },
      action == 'delete'
          ? 'Jadwal tagihan dihapus.'
          : action == 'toggle'
          ? 'Status tagihan diperbarui.'
          : 'Periode tagihan dilewati.',
    );
  }

  void _payBill(RecurringBillEntry bill) => _mutate(() async {
    final balance = await ref
        .read(walletRepositoryProvider)
        .getWalletBalance(walletId: bill.walletId);
    if (!mounted) return false;
    if (balance == null || balance.wallet.isArchived) {
      throw StateError(
        'Pilih dompet aktif melalui Edit jadwal sebelum membayar.',
      );
    }
    final date = await showDialog<DateTime>(
      context: context,
      builder: (_) => _PaymentDialog(
        bill: bill,
        walletName: balance.wallet.name,
        lowBalance: balance.balance < bill.amount,
      ),
    );
    if (date == null) return false;
    await ref.read(planningRepositoryProvider).payBill(bill, paidAt: date);
    return true;
  }, 'Pembayaran dicatat dan jadwal dilanjutkan.');

  void _deleteGoal(SavingsGoalEntry goal) => _mutate(() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Hapus target tabungan?',
      message:
          'Target ${goal.name} dan progresnya akan dihapus. Saldo dompet tetap sama.',
      confirmLabel: 'Hapus target',
      danger: true,
    );
    if (!confirmed) return false;
    await ref.read(planningRepositoryProvider).deleteGoal(goal.id);
    return true;
  }, 'Target tabungan dihapus.');
}

class PlanningShortcuts extends ConsumerWidget {
  const PlanningShortcuts({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateFormatter.startOfDay(DateTime.now());
    final bills = ref.watch(recurringBillsProvider);
    final goals = ref.watch(savingsGoalsProvider);
    final due =
        bills.asData?.value
            .where((bill) => bill.isActive && !bill.nextDueDate.isAfter(today))
            .length ??
        0;
    return Row(
      children: [
        Expanded(
          child: _Shortcut(
            icon: Icons.event_repeat_rounded,
            title: 'Tagihan',
            subtitle: bills.hasError
                ? 'Buka jadwal'
                : bills.isLoading
                ? 'Memuat…'
                : due > 0
                ? '$due perlu dibayar'
                : 'Atur jadwal rutin',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const PlanningPage()),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _Shortcut(
            icon: Icons.savings_outlined,
            title: 'Target tabungan',
            subtitle: goals.hasError
                ? 'Buka target'
                : goals.isLoading
                ? 'Memuat…'
                : goals.asData?.value.isNotEmpty == true
                ? '${goals.asData!.value.length} tujuan menabung'
                : 'Wujudkan tujuanmu',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const PlanningPage(initialTab: 1),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: PressableSurface(
      onTap: onTap,
      child: _PlanningCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _PlanningCard extends StatelessWidget {
  const _PlanningCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: AppRadius.card,
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: .15),
      ),
    ),
    child: child,
  );
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.label, this.warning = false});
  final String label;
  final bool warning;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: warning
          ? AppColors.readableAccent(
              AppColors.warningOrange,
              Theme.of(context).brightness,
            )
          : Theme.of(context).colorScheme.primary,
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
      ],
    ),
  );
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.bill,
    required this.walletName,
    required this.lowBalance,
  });
  final RecurringBillEntry bill;
  final String walletName;
  final bool lowBalance;
  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  DateTime _date = DateFormatter.startOfDay(DateTime.now());
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Catat pembayaran?'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.bill.title}\n${CurrencyFormatter.rupiah(widget.bill.amount)} dari ${widget.walletName}.',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Untuk jatuh tempo ${DateFormatter.shortDateLabel(widget.bill.nextDueDate)}. Konfirmasi setelah tagihan benar-benar dibayar.',
          ),
          if (widget.lowBalance) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Saldo dompet tidak cukup. Jika dilanjutkan, saldo menjadi negatif.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tanggal pembayaran'),
            subtitle: Text(DateFormatter.shortDateLabel(_date)),
            trailing: const Icon(Icons.calendar_today_rounded, size: 20),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (date != null && mounted) setState(() => _date = date);
            },
          ),
        ],
      ),
    ),
    actionsPadding: const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      0,
      AppSpacing.xl,
      AppSpacing.xl,
    ),
    actions: [
      AppFormActions(
        primaryLabel: 'Catat pembayaran',
        onPrimaryPressed: () => Navigator.pop(context, _date),
        secondaryLabel: 'Batal',
        onSecondaryPressed: () => Navigator.pop(context),
      ),
    ],
  );
}
