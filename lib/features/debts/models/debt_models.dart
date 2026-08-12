import '../../../core/api/json_reader.dart';

class DebtSummary {
  const DebtSummary(
      {required this.totalPayable,
      required this.overduePayable,
      required this.totalReceivable,
      required this.overdueReceivable,
      required this.activeDebtCount,
      required this.openDocumentCount,
      required this.overdueDocumentCount,
      required this.netProjectedCashFlow});
  final double totalPayable;
  final double overduePayable;
  final double totalReceivable;
  final double overdueReceivable;
  final int activeDebtCount;
  final int openDocumentCount;
  final int overdueDocumentCount;
  final double netProjectedCashFlow;

  factory DebtSummary.fromJson(Map<String, dynamic> json) => DebtSummary(
        totalPayable: JsonReader.decimal(json, 'totalPayable') ?? 0,
        overduePayable: JsonReader.decimal(json, 'totalOverduePayable') ?? 0,
        totalReceivable: JsonReader.decimal(json, 'totalReceivable') ?? 0,
        overdueReceivable:
            JsonReader.decimal(json, 'totalOverdueReceivable') ?? 0,
        activeDebtCount: JsonReader.integer(json, 'activeDebtCount') ?? 0,
        openDocumentCount: JsonReader.integer(json, 'openDocumentCount') ?? 0,
        overdueDocumentCount:
            JsonReader.integer(json, 'overdueDocumentCount') ?? 0,
        netProjectedCashFlow:
            JsonReader.decimal(json, 'netProjectedCashFlow') ?? 0,
      );
}

class DebtDocument {
  const DebtDocument(
      {required this.partyDebtId,
      required this.partyCode,
      required this.partyName,
      required this.direction,
      required this.documentCode,
      required this.totalAmount,
      required this.paidAmount,
      required this.outstandingAmount,
      required this.status,
      required this.daysOverdue,
      this.partyPhone,
      this.transactionDate,
      this.dueDate});
  final int partyDebtId;
  final String partyCode;
  final String partyName;
  final String? partyPhone;
  final String direction;
  final String documentCode;
  final DateTime? transactionDate;
  final DateTime? dueDate;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final String status;
  final int daysOverdue;
  bool get isOverdue => status.toUpperCase() == 'OVERDUE' || daysOverdue > 0;

  factory DebtDocument.fromJson(Map<String, dynamic> json) => DebtDocument(
        partyDebtId: JsonReader.integer(json, 'partyDebtId') ?? 0,
        partyCode: JsonReader.string(json, 'partyCode') ?? '',
        partyName: JsonReader.string(json, 'partyName') ?? 'Chưa xác định',
        partyPhone: JsonReader.string(json, 'partyPhone'),
        direction: JsonReader.string(json, 'direction') ?? '',
        documentCode:
            JsonReader.string(json, 'documentCode') ?? 'Chưa có chứng từ',
        transactionDate: _date(json, 'transactionDate'),
        dueDate: _date(json, 'dueDate'),
        totalAmount: JsonReader.decimal(json, 'totalAmount') ?? 0,
        paidAmount: JsonReader.decimal(json, 'paidAmount') ?? 0,
        outstandingAmount: JsonReader.decimal(json, 'outstandingAmount') ?? 0,
        status: JsonReader.string(json, 'status') ?? 'UNKNOWN',
        daysOverdue: JsonReader.integer(json, 'daysOverdue') ?? 0,
      );
}

class DebtTransaction {
  const DebtTransaction(
      {required this.id,
      required this.partyName,
      required this.transactionType,
      required this.amount,
      required this.balanceAfter,
      required this.documentCode,
      this.transactionDate,
      this.createdByName});
  final int id;
  final String partyName;
  final String transactionType;
  final double amount;
  final double balanceAfter;
  final String documentCode;
  final DateTime? transactionDate;
  final String? createdByName;

  factory DebtTransaction.fromJson(Map<String, dynamic> json) =>
      DebtTransaction(
        id: JsonReader.integer(json, 'id') ?? 0,
        partyName: JsonReader.string(json, 'partyName') ?? 'Chưa xác định',
        transactionType: JsonReader.string(json, 'transactionType') ?? '',
        amount: JsonReader.decimal(json, 'amount') ?? 0,
        balanceAfter: JsonReader.decimal(json, 'balanceAfter') ?? 0,
        documentCode:
            JsonReader.string(json, 'documentCode') ?? 'Chưa có chứng từ',
        transactionDate: _date(json, 'transactionDate'),
        createdByName: JsonReader.string(json, 'createdByName'),
      );
}

class DebtDashboard {
  const DebtDashboard(
      {required this.summary,
      required this.payables,
      required this.receivables,
      required this.transactions,
      required this.overdue,
      this.payablesTotal = 0,
      this.payablesFiltered = 0,
      this.receivablesTotal = 0,
      this.receivablesFiltered = 0,
      this.transactionsTotal = 0,
      this.transactionsFiltered = 0,
      this.overdueTotal = 0,
      this.overdueFiltered = 0});
  final DebtSummary summary;
  final List<DebtDocument> payables;
  final List<DebtDocument> receivables;
  final List<DebtTransaction> transactions;
  final List<DebtDocument> overdue;
  final int payablesTotal;
  final int payablesFiltered;
  final int receivablesTotal;
  final int receivablesFiltered;
  final int transactionsTotal;
  final int transactionsFiltered;
  final int overdueTotal;
  final int overdueFiltered;
}

DateTime? _date(Map<String, dynamic> json, String key) {
  final value = JsonReader.string(json, key);
  return value == null ? null : DateTime.tryParse(value)?.toLocal();
}
