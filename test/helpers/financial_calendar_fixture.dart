import 'package:dompet_sheva/data/local/database/app_database.dart';
import 'package:dompet_sheva/data/repositories/app_models.dart';

final calendarNow = DateTime(2026, 11, 16, 12);
final calendarWallet = WalletEntry(
  id: 1,
  name: 'Tunai',
  type: 'cash',
  initialBalance: 0,
  reservedBalance: 0,
  isArchived: false,
  createdAt: calendarNow,
  updatedAt: calendarNow,
);

TransactionDetail calendarTransaction({
  int id = 1,
  required String type,
  required int amount,
  required DateTime date,
  String? note,
}) => TransactionDetail(
  transaction: TransactionEntry(
    id: id,
    type: type,
    amount: amount,
    categoryId: null,
    walletId: calendarWallet.id,
    transferWalletId: null,
    date: date,
    note: note,
    createdAt: calendarNow,
    updatedAt: calendarNow,
  ),
  wallet: calendarWallet,
);

RecurringBillEntry calendarBill({
  int id = 1,
  String title = 'Internet rumah',
  int amount = 250000,
  DateTime? due,
  String frequency = 'monthly',
  int? anchorDay,
  bool active = true,
}) {
  final date = due ?? DateTime(2026, 11, 16);
  return RecurringBillEntry(
    id: id,
    title: title,
    amount: amount,
    categoryId: 1,
    walletId: calendarWallet.id,
    nextDueDate: date,
    frequency: frequency,
    anchorDay: anchorDay ?? date.day,
    isActive: active,
    createdAt: calendarNow,
    updatedAt: calendarNow,
  );
}
