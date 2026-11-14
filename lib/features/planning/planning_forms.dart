import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/app_providers.dart';
import '../../app/providers/planning_providers.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../core/formatters/date_formatter.dart';
import '../../core/formatters/rupiah_input_formatter.dart';
import '../../data/local/database/app_database.dart';
import '../../shared/widgets/app_form_actions.dart';
import '../../shared/widgets/top_toast.dart';

const billFrequencyLabels = {
  'weekly': 'Setiap minggu',
  'monthly': 'Setiap bulan',
  'yearly': 'Setiap tahun',
};

DateTime _nextSourceDueDate(DateTime sourceDate) {
  final today = DateFormatter.startOfDay(DateTime.now());
  var month = sourceDate.month + 1;
  var due = DateTime(
    sourceDate.year,
    month,
    sourceDate.day.clamp(1, DateTime(sourceDate.year, month + 1, 0).day),
  );
  while (due.isBefore(today)) {
    month++;
    due = DateTime(
      sourceDate.year,
      month,
      sourceDate.day.clamp(1, DateTime(sourceDate.year, month + 1, 0).day),
    );
  }
  return due;
}

Future<void> showRecurringBillForm(
  BuildContext context, {
  RecurringBillEntry? bill,
  TransactionEntry? sourceTransaction,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _BillForm(bill: bill, source: sourceTransaction),
  );
  if (saved == true && context.mounted) {
    TopToast.show(
      context,
      'Jadwal tagihan disimpan.',
      type: TopToastType.success,
    );
  }
}

Future<void> showSavingsGoalForm(
  BuildContext context, {
  SavingsGoalEntry? goal,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _GoalForm(goal: goal),
  );
  if (saved == true && context.mounted) {
    TopToast.show(
      context,
      'Target tabungan disimpan.',
      type: TopToastType.success,
    );
  }
}

String planningError(Object error) => switch (error) {
  ArgumentError() => error.message.toString(),
  StateError() => error.message,
  _ => 'Perubahan belum bisa disimpan. Silakan coba lagi.',
};

class _BillForm extends ConsumerStatefulWidget {
  const _BillForm({this.bill, this.source});
  final RecurringBillEntry? bill;
  final TransactionEntry? source;

  @override
  ConsumerState<_BillForm> createState() => _BillFormState();
}

class _BillFormState extends ConsumerState<_BillForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late DateTime _date;
  late String _frequency;
  int? _walletId;
  int? _categoryId;
  bool _saving = false;
  bool _titleEdited = false;
  bool _dateEdited = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final bill = widget.bill;
    final source = widget.source;
    final sourceCategory = ref
        .read(categoriesProvider)
        .asData
        ?.value
        .where((category) => category.id == source?.categoryId)
        .firstOrNull;
    final sourceNote = source?.note?.trim();
    _title = TextEditingController(
      text:
          bill?.title ??
          (source == null
              ? ''
              : sourceNote?.isNotEmpty == true
              ? sourceNote!
              : sourceCategory?.name ?? 'Tagihan rutin'),
    );
    final amount = bill?.amount ?? source?.amount;
    _amount = TextEditingController(
      text: amount == null ? '' : CurrencyFormatter.rupiah(amount),
    );
    _date =
        bill?.nextDueDate ??
        (source == null
            ? DateFormatter.startOfDay(DateTime.now())
            : _nextSourceDueDate(source.date));
    _frequency = bill?.frequency ?? 'monthly';
    _walletId = bill?.walletId ?? source?.walletId;
    _categoryId = bill?.categoryId ?? source?.categoryId;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(categoriesProvider, (_, next) {
      final source = widget.source;
      if (source == null ||
          widget.bill != null ||
          _titleEdited ||
          source.note?.trim().isNotEmpty == true) {
        return;
      }
      final category = next.asData?.value
          .where((item) => item.id == source.categoryId)
          .firstOrNull;
      if (category != null) _title.text = category.name;
    });
    final wallets = ref.watch(walletBalancesProvider);
    final categories = ref.watch(categoriesProvider);
    return _PlanningFormDialog(
      title: widget.bill == null ? 'Tambah tagihan' : 'Edit tagihan',
      saving: _saving,
      onSave: wallets.hasValue && categories.hasValue ? _save : null,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pengeluaran dicatat saat kamu mengonfirmasi pembayaran.',
            ),
            const SizedBox(height: AppSpacing.xl),
            TextFormField(
              controller: _title,
              onChanged: (_) => _titleEdited = true,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nama tagihan'),
              validator: _requiredName,
            ),
            const SizedBox(height: AppSpacing.lg),
            _MoneyField(controller: _amount, label: 'Nominal tagihan'),
            const SizedBox(height: AppSpacing.lg),
            wallets.when(
              data: (items) {
                final available = items.where(
                  (item) => !item.wallet.isArchived,
                );
                final selectedExists = available.any(
                  (item) => item.wallet.id == _walletId,
                );
                return DropdownButtonFormField<int>(
                  initialValue: selectedExists ? _walletId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Dompet pembayaran',
                  ),
                  hint: const Text('Pilih dompet aktif'),
                  items: [
                    for (final item in available)
                      DropdownMenuItem(
                        value: item.wallet.id,
                        child: Text(
                          item.wallet.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  validator: (value) =>
                      value == null ? 'Pilih dompet aktif.' : null,
                  onChanged: (value) => _walletId = value,
                );
              },
              loading: () => const Text('Memuat dompet…'),
              error: (_, _) =>
                  const Text('Dompet belum bisa dimuat. Tutup lalu coba lagi.'),
            ),
            const SizedBox(height: AppSpacing.lg),
            categories.when(
              data: (items) {
                final available = items.where(
                  (item) =>
                      !item.isArchived &&
                      (item.type == 'expense' || item.type == 'both'),
                );
                final selectedExists = available.any(
                  (item) => item.id == _categoryId,
                );
                return DropdownButtonFormField<int>(
                  initialValue: selectedExists ? _categoryId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kategori pengeluaran',
                  ),
                  hint: const Text('Pilih kategori aktif'),
                  items: [
                    for (final item in available)
                      DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  validator: (value) => value == null
                      ? 'Pilih kategori pengeluaran aktif.'
                      : null,
                  onChanged: (value) => _categoryId = value,
                );
              },
              loading: () => const Text('Memuat kategori…'),
              error: (_, _) => const Text(
                'Kategori belum bisa dimuat. Tutup lalu coba lagi.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Pengulangan'),
              items: [
                for (final entry in billFrequencyLabels.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => _frequency = value!,
            ),
            const SizedBox(height: AppSpacing.md),
            _DateButton(
              label: 'Jatuh tempo berikutnya',
              date: _date,
              onChanged: (value) => setState(() {
                _date = value;
                _dateEdited = true;
              }),
            ),
            if (widget.bill != null) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Jika dompet atau kategori dinonaktifkan, pilih penggantinya sebelum menyimpan.',
              ),
            ],
            if (_error != null) _FormError(_error!),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(planningRepositoryProvider)
          .saveBill(
            id: widget.bill?.id,
            expectedBill: widget.bill,
            title: _title.text,
            amount: CurrencyFormatter.parseRupiah(_amount.text),
            categoryId: _categoryId!,
            walletId: _walletId!,
            nextDueDate: _date,
            frequency: _frequency,
            anchorDay:
                widget.bill == null &&
                    widget.source != null &&
                    !_dateEdited &&
                    _frequency == 'monthly'
                ? widget.source!.date.day
                : null,
            isActive: widget.bill?.isActive ?? true,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = planningError(error);
          _saving = false;
        });
      }
    }
  }
}

class _GoalForm extends ConsumerStatefulWidget {
  const _GoalForm({this.goal});
  final SavingsGoalEntry? goal;
  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _saved;
  DateTime? _date;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _name = TextEditingController(text: goal?.name ?? '');
    _target = TextEditingController(
      text: goal == null ? '' : CurrencyFormatter.rupiah(goal.targetAmount),
    );
    _saved = TextEditingController(
      text: CurrencyFormatter.rupiah(goal?.savedAmount ?? 0),
    );
    _date = goal?.targetDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PlanningFormDialog(
    title: widget.goal == null
        ? 'Tambah target tabungan'
        : 'Perbarui target tabungan',
    saving: _saving,
    onSave: _save,
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Progres dicatat manual dan tidak mengubah saldo dompet.'),
          const SizedBox(height: AppSpacing.xl),
          TextFormField(
            controller: _name,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nama target'),
            validator: _requiredName,
          ),
          const SizedBox(height: AppSpacing.lg),
          _MoneyField(controller: _target, label: 'Nominal target'),
          const SizedBox(height: AppSpacing.lg),
          _MoneyField(
            controller: _saved,
            label: 'Sudah terkumpul',
            allowZero: true,
          ),
          const SizedBox(height: AppSpacing.md),
          _DateButton(
            label: 'Tenggat (opsional)',
            date: _date,
            onChanged: (value) => setState(() => _date = value),
          ),
          if (_date != null)
            TextButton(
              onPressed: () => setState(() => _date = null),
              child: const Text('Hapus tenggat'),
            ),
          if (_error != null) _FormError(_error!),
        ],
      ),
    ),
  );

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(planningRepositoryProvider)
          .saveGoal(
            id: widget.goal?.id,
            name: _name.text,
            targetAmount: CurrencyFormatter.parseRupiah(_target.text),
            savedAmount: CurrencyFormatter.parseRupiah(_saved.text),
            targetDate: _date,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = planningError(error);
          _saving = false;
        });
      }
    }
  }
}

String? _requiredName(String? value) =>
    value == null || value.trim().isEmpty ? 'Nama belum diisi.' : null;

class _MoneyField extends StatelessWidget {
  const _MoneyField({
    required this.controller,
    required this.label,
    this.allowZero = false,
  });
  final TextEditingController controller;
  final String label;
  final bool allowZero;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: const [RupiahInputFormatter()],
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final amount = CurrencyFormatter.parseRupiah(value ?? '');
      if (amount > 9007199254740991) return 'Nominal terlalu besar.';
      if (!allowZero && amount <= 0) return 'Nominal harus lebih dari nol.';
      return null;
    },
  );
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onChanged,
  });
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(
      date == null ? 'Tanpa tenggat' : DateFormatter.shortDateLabel(date!),
    ),
    trailing: const Icon(Icons.calendar_today_rounded, size: 20),
    onTap: () async {
      final selected = await showDatePicker(
        context: context,
        initialDate: date ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100, 12, 31),
      );
      if (selected != null) onChanged(selected);
    },
  );
}

class _PlanningFormDialog extends StatelessWidget {
  const _PlanningFormDialog({
    required this.title,
    required this.child,
    required this.saving,
    required this.onSave,
  });
  final String title;
  final Widget child;
  final bool saving;
  final VoidCallback? onSave;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      title: Text(title),
      content: SizedBox(
        width: AppSpacing.webMaxWidth,
        child: SingleChildScrollView(
          child: AbsorbPointer(absorbing: saving, child: child),
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
          primaryLabel: saving ? 'Menyimpan…' : 'Simpan',
          onPrimaryPressed: saving ? null : onSave,
          secondaryLabel: 'Batal',
          onSecondaryPressed: () {
            if (!saving) Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}

class _FormError extends StatelessWidget {
  const _FormError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}
