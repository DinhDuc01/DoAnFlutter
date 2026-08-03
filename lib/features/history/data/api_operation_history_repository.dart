import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/operation_history.dart';
import 'operation_history_repository.dart';

class ApiOperationHistoryRepository implements OperationHistoryRepository {
  ApiOperationHistoryRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  @override
  Future<List<OperationHistory>> getHistories() async {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const ApiException(
        message: 'Bạn cần đăng nhập để xem lịch sử thao tác.',
      );
    }

    const columnNames = [
      'action',
      'description',
      'ipAddress',
      'userAgent',
      'createdDate',
    ];
    final json = await _apiClient.post(
      '/api/v1/activity-log/me',
      token: token,
      body: {
        'draw': 1,
        'start': 0,
        'length': 50,
        'search': {'value': '', 'regex': false},
        'columns': [
          for (final name in columnNames)
            {
              'data': name,
              'name': name,
              'searchable': true,
              'orderable': true,
              'search': {'value': '', 'regex': false},
            },
        ],
        'order': [
          {'column': 4, 'dir': 1},
        ],
      },
    );
    if (JsonReader.boolean(json, 'isSucceeded') == false) {
      throw ApiException(
        message: JsonReader.string(json, 'message') ??
            'Không thể tải lịch sử thao tác.',
      );
    }

    final resources = JsonReader.map(json, 'resources');
    final rows = resources == null ? null : JsonReader.list(resources, 'data');
    if (rows == null) return const [];

    return rows
        .whereType<Map<String, dynamic>>()
        .map(_fromJson)
        .toList(growable: false);
  }

  OperationHistory _fromJson(Map<String, dynamic> json) {
    final id = JsonReader.integer(json, 'id') ?? 0;
    final action = JsonReader.string(json, 'action')?.trim();
    final description = JsonReader.string(json, 'description')?.trim();
    final createdUser = JsonReader.string(json, 'createdUserName')?.trim();
    final createdDate = JsonReader.string(json, 'createdDate');
    return OperationHistory(
      type: _typeFromAction(action ?? ''),
      productName: description?.isNotEmpty == true
          ? description!
          : (action?.isNotEmpty == true ? action! : 'Thao tác StockLite'),
      sku: createdUser?.isNotEmpty == true ? createdUser! : 'Tài khoản của tôi',
      referenceCode: id > 0 ? '#$id' : 'StockLite',
      quantityChange: 0,
      createdAt: DateTime.tryParse(createdDate ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  OperationHistoryType _typeFromAction(String action) {
    final value = action.toLowerCase();
    if (value.contains('inbound') ||
        value.contains('receipt') ||
        value.contains('thu mua') ||
        value.contains('nhập')) {
      return OperationHistoryType.inbound;
    }
    if (value.contains('outbound') ||
        value.contains('dispatch') ||
        value.contains('giao') ||
        value.contains('xuất')) {
      return OperationHistoryType.outbound;
    }
    if (value.contains('stocktake') ||
        value.contains('inventory') ||
        value.contains('kiểm kê')) {
      return OperationHistoryType.inventory;
    }
    return OperationHistoryType.other;
  }
}
