import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/widgets/state_widgets.dart';
import 'package:stocklite/features/auth/data/auth_session_store.dart';
import 'package:stocklite/features/auth/models/auth_session.dart';
import 'package:stocklite/features/debts/data/debt_repository.dart';
import 'package:stocklite/features/debts/models/debt_models.dart';
import 'package:stocklite/features/debts/presentation/screens/debt_screen.dart';

import 'support/fake_api_client.dart';

void main() {
  setUp(() => AuthSessionStore.current = const AuthSession(
        accessToken: 'debt-token',
        refreshToken: 'refresh-token',
        user: AuthUser(id: 1, fullName: 'Tester', email: 't@example.com'),
      ));
  tearDown(() => AuthSessionStore.current = null);

  test('parses summary, document, transaction and nullable fields', () {
    final summary = DebtSummary.fromJson({
      'totalPayable': 120000,
      'totalOverduePayable': 20000,
      'totalReceivable': 90000,
      'openDocumentCount': 4,
    });
    final document = DebtDocument.fromJson({
      'partyDebtId': 3,
      'partyName': 'Nông dân A',
      'direction': 'PAYABLE',
      'documentCode': 'PPR-001',
      'totalAmount': 120000,
      'paidAmount': 20000,
      'outstandingAmount': 100000,
      'status': 'OVERDUE',
      'daysOverdue': 5,
    });
    final transaction = DebtTransaction.fromJson({
      'id': 7,
      'partyName': 'Khách hàng B',
      'transactionType': 'PAYMENT',
      'amount': 10000,
      'balanceAfter': 80000,
      'documentCode': 'SO-001',
    });

    expect(summary.totalPayable, 120000);
    expect(summary.overdueReceivable, 0);
    expect(document.partyPhone, isNull);
    expect(document.isOverdue, isTrue);
    expect(transaction.createdByName, isNull);
  });

  test('repository uses verified endpoints, bodies and bearer token', () async {
    final client = FakeApiClient(
      onGet: (_, __, ___) async =>
          {'isSucceeded': true, 'resources': _summaryJson()},
      onPost: (path, body, token) async => {
        'isSucceeded': true,
        'resources': {
          'data': path.contains('transactions')
              ? [_transactionJson()]
              : [_documentJson(direction: body?['direction'] as String?)],
          'recordsTotal': 1,
          'recordsFiltered': 1,
        },
      },
    );

    final result = await ApiDebtRepository(apiClient: client).loadDashboard();

    expect(client.calls, hasLength(5));
    expect(client.calls.every((call) => call.token == 'debt-token'), isTrue);
    expect(client.calls.first.path, '/api/v1/party-debts/summary');
    expect(client.calls.where((call) => call.path.endsWith('documents/paged')),
        hasLength(3));
    expect(result.payables, hasLength(1));
    expect(result.transactions.single.documentCode, 'SO-001');
  });

  test('repository sends paging, search, status and parses paging metadata',
      () async {
    final client = FakeApiClient(
      onGet: (_, __, ___) async =>
          {'isSucceeded': true, 'resources': _summaryJson()},
      onPost: (path, body, token) async => {
        'isSucceeded': true,
        'resources': {
          'data': path.contains('transactions')
              ? [_transactionJson()]
              : [_documentJson(direction: body?['direction'] as String?)],
          'recordsTotal': 41,
          'recordsFiltered': 7,
        },
      },
    );
    final result = await ApiDebtRepository(apiClient: client).loadDashboardPage(
      query: const DebtQuery(
          start: 20, length: 20, search: 'PPR-001', status: 'PAID'),
    );
    final calls = client.calls.where(
        (call) => call.path.contains('party-debts/') && call.body != null);
    expect(calls, hasLength(4));
    for (final call in calls) {
      expect(call.body?['start'], 20);
      expect(call.body?['length'], 20);
      expect((call.body?['search'] as Map)['value'], 'PPR-001');
    }
    final documentCalls = calls
        .where((c) =>
            c.path.endsWith('documents/paged') && c.body?['direction'] != null)
        .toList();
    expect(documentCalls, hasLength(2));
    for (final call in documentCalls) {
      expect(call.body?['status'], 'PAID');
    }
    expect(result.payablesTotal, 41);
    expect(result.payablesFiltered, 7);
  });

  test(
      'overdue request keeps overdueOnly true and refresh query starts at zero',
      () async {
    final client = FakeApiClient(
      onGet: (_, __, ___) async =>
          {'isSucceeded': true, 'resources': _summaryJson()},
      onPost: (path, body, token) async => {
        'isSucceeded': true,
        'resources': {'data': [], 'recordsTotal': 0, 'recordsFiltered': 0}
      },
    );
    await ApiDebtRepository(apiClient: client)
        .loadDashboardPage(query: const DebtQuery(start: 0));
    final overdue =
        client.calls.where((c) => c.path.endsWith('documents/paged')).last;
    expect(overdue.body?['overdueOnly'], isTrue);
    expect(overdue.body?['start'], 0);
  });

  test('repository maps missing session to unauthorized', () async {
    AuthSessionStore.current = null;
    await expectLater(
      ApiDebtRepository(apiClient: FakeApiClient()).loadDashboard(),
      throwsA(isA<DebtException>().having((e) => e.statusCode, 'status', 401)),
    );
  });

  testWidgets('screen shows loading then empty states and switches tabs',
      (tester) async {
    final completer = Completer<DebtDashboard>();
    await tester.pumpWidget(MaterialApp(
        home: DebtScreen(repository: _Repo(() => completer.future))));
    expect(find.byType(ListSkeleton), findsOneWidget);

    completer.complete(_dashboard(empty: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('debt_payable')));
    await tester.pumpAndSettle();
    expect(find.text('Không có khoản phải trả'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('debt_transactions')));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có giao dịch'), findsOneWidget);
  });

  testWidgets('error has retry and refresh calls repository again',
      (tester) async {
    var calls = 0;
    final repository = _Repo(() async {
      calls++;
      if (calls == 1) throw const DebtException('Forbidden', statusCode: 403);
      return _dashboard();
    });
    await tester
        .pumpWidget(MaterialApp(home: DebtScreen(repository: repository)));
    await tester.pumpAndSettle();
    expect(find.byType(HErrorState), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Công nợ'), findsOneWidget);
    expect(calls, 2);

    await tester.tap(find.byKey(const ValueKey('debt_refresh')));
    await tester.pumpAndSettle();
    expect(calls, 3);
  });
}

Map<String, dynamic> _summaryJson() => {
      'totalPayable': 120000,
      'totalOverduePayable': 20000,
      'totalReceivable': 90000,
      'totalOverdueReceivable': 10000,
      'activeDebtCount': 2,
      'openDocumentCount': 2,
      'overdueDocumentCount': 1,
      'netProjectedCashFlow': -30000,
    };

Map<String, dynamic> _documentJson({String? direction}) => {
      'partyDebtId': 1,
      'partyCode': 'P-001',
      'partyName': 'Đối tác A',
      'partyPhone': '0900000000',
      'direction': direction ?? 'PAYABLE',
      'documentCode': direction == 'RECEIVABLE' ? 'SO-001' : 'PPR-001',
      'transactionDate': '2026-08-12T08:00:00',
      'dueDate': '2026-08-20T00:00:00',
      'totalAmount': 120000,
      'paidAmount': 20000,
      'outstandingAmount': 100000,
      'status': 'PARTIALLY_PAID',
      'daysOverdue': 0,
    };

Map<String, dynamic> _transactionJson() => {
      'id': 9,
      'partyName': 'Khách hàng B',
      'transactionType': 'PAYMENT',
      'amount': 10000,
      'balanceAfter': 80000,
      'documentCode': 'SO-001',
      'transactionDate': '2026-08-12T09:00:00',
      'createdByName': 'Admin',
    };

DebtDashboard _dashboard({bool empty = false}) => DebtDashboard(
      summary: DebtSummary.fromJson(_summaryJson()),
      payables: empty
          ? []
          : [DebtDocument.fromJson(_documentJson(direction: 'PAYABLE'))],
      receivables: empty
          ? []
          : [DebtDocument.fromJson(_documentJson(direction: 'RECEIVABLE'))],
      transactions: empty ? [] : [DebtTransaction.fromJson(_transactionJson())],
      overdue: const [],
    );

class _Repo implements DebtRepository {
  _Repo(this.loader);
  final Future<DebtDashboard> Function() loader;
  @override
  Future<DebtDashboard> loadDashboard() => loader();
}
