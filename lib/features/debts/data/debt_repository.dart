import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/debt_models.dart';

abstract class DebtRepository {
  Future<DebtDashboard> loadDashboard();
}

extension DebtRepositoryPaging on DebtRepository {
  Future<DebtDashboard> loadDashboardPage(
          {DebtQuery query = const DebtQuery()}) =>
      loadDashboard();
}

class DebtQuery {
  const DebtQuery(
      {this.start = 0,
      this.length = 20,
      this.search = '',
      this.status,
      this.transactionType});
  final int start;
  final int length;
  final String search;
  final String? status;
  final String? transactionType;
}

class ApiDebtRepository implements DebtRepository {
  ApiDebtRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();
  final ApiClient _api;

  @override
  Future<DebtDashboard> loadDashboard() => loadDashboardPage();

  Future<DebtDashboard> loadDashboardPage(
      {DebtQuery query = const DebtQuery()}) async {
    final token = _token;
    try {
      final values = await Future.wait<dynamic>([
        _summary(token),
        _documents(token, direction: 'PAYABLE', query: query),
        _documents(token, direction: 'RECEIVABLE', query: query),
        _transactions(token, query: query),
        _documents(token, overdueOnly: true, query: query),
      ]);
      return DebtDashboard(
          summary: values[0] as DebtSummary,
          payables: (values[1] as DebtPage<DebtDocument>).items,
          receivables: (values[2] as DebtPage<DebtDocument>).items,
          transactions: (values[3] as DebtPage<DebtTransaction>).items,
          overdue: (values[4] as DebtPage<DebtDocument>).items,
          payablesTotal: (values[1] as DebtPage<DebtDocument>).total,
          payablesFiltered: (values[1] as DebtPage<DebtDocument>).filtered,
          receivablesTotal: (values[2] as DebtPage<DebtDocument>).total,
          receivablesFiltered: (values[2] as DebtPage<DebtDocument>).filtered,
          transactionsTotal: (values[3] as DebtPage<DebtTransaction>).total,
          transactionsFiltered:
              (values[3] as DebtPage<DebtTransaction>).filtered,
          overdueTotal: (values[4] as DebtPage<DebtDocument>).total,
          overdueFiltered: (values[4] as DebtPage<DebtDocument>).filtered);
    } on ApiException catch (error) {
      throw DebtException(error.message,
          statusCode: error.statusCode, isTransient: error.isTransient);
    }
  }

  String get _token {
    final value = AuthSessionStore.current?.accessToken;
    if (value == null || value.isEmpty) {
      throw const DebtException('Bạn cần đăng nhập để xem công nợ.',
          statusCode: 401);
    }
    return value;
  }

  Future<DebtSummary> _summary(String token) async {
    final json = await _api.get('/api/v1/party-debts/summary', token: token);
    return DebtSummary.fromJson(_resources(json));
  }

  Future<DebtPage<DebtDocument>> _documents(String token,
      {String? direction,
      bool overdueOnly = false,
      required DebtQuery query}) async {
    final json = await _api.post('/api/v1/party-debts/documents/paged',
        token: token,
        body: _body(
            direction: direction, overdueOnly: overdueOnly, query: query));
    final page = _page(json);
    return DebtPage<DebtDocument>([
      for (final row in page.rows)
        if (row is Map<String, dynamic>) DebtDocument.fromJson(row)
    ], page.total, page.filtered);
  }

  Future<DebtPage<DebtTransaction>> _transactions(String token,
      {required DebtQuery query}) async {
    final json = await _api.post(
        '/api/v1/party-debts/transactions/paged-advanced',
        token: token,
        body: _body(query: query));
    final page = _page(json);
    return DebtPage<DebtTransaction>([
      for (final row in page.rows)
        if (row is Map<String, dynamic>) DebtTransaction.fromJson(row)
    ], page.total, page.filtered);
  }

  Map<String, dynamic> _resources(Map<String, dynamic> json) {
    if (JsonReader.boolean(json, 'isSucceeded') == false) {
      throw DebtException(
          JsonReader.string(json, 'message') ?? 'Không tải được công nợ.');
    }
    final value = JsonReader.map(json, 'resources');
    if (value == null) {
      throw const DebtException('Backend không trả dữ liệu công nợ.');
    }
    return value;
  }

  _RawPage _page(Map<String, dynamic> json) {
    final value = _resources(json);
    return _RawPage(
      JsonReader.list(value, 'data') ??
          JsonReader.list(value, 'dataSource') ??
          const [],
      JsonReader.integer(value, 'recordsTotal') ?? 0,
      JsonReader.integer(value, 'recordsFiltered') ?? 0,
    );
  }

  Map<String, dynamic> _body(
          {String? direction,
          bool overdueOnly = false,
          DebtQuery query = const DebtQuery()}) =>
      {
        'draw': 1,
        'start': query.start,
        'length': query.length,
        'search': {'value': query.search, 'regex': false},
        'columns': <dynamic>[],
        'order': <dynamic>[],
        if (direction != null) 'direction': direction,
        'overdueOnly': overdueOnly,
        if (query.status != null && direction != null) 'status': query.status,
        if (query.transactionType != null && direction == null)
          'transactionType': query.transactionType,
      };
}

class _RawPage {
  const _RawPage(this.rows, this.total, this.filtered);
  final List<dynamic> rows;
  final int total;
  final int filtered;
}

class DebtPage<T> {
  const DebtPage(this.items, this.total, this.filtered);
  final List<T> items;
  final int total;
  final int filtered;
}

class DebtException implements Exception {
  const DebtException(this.message,
      {this.statusCode, this.isTransient = false});
  final String message;
  final int? statusCode;
  final bool isTransient;
  @override
  String toString() => message;
}
