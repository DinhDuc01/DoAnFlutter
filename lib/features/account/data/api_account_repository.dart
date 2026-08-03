import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../../core/theme/theme_controller.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/account_profile.dart';
import 'account_repository.dart';

class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  String get _accessToken {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const ApiException(
        message: 'Bạn cần đăng nhập để thực hiện thao tác này.',
      );
    }
    return token;
  }

  @override
  Future<AccountProfile> getProfile() async {
    final token = _accessToken;

    final results = await Future.wait([
      _apiClient.get('/api/v1/auth/me', token: token),
      _apiClient.get('/api/v1/warehouse', token: token),
    ]);
    final profile = JsonReader.map(results[0], 'resources') ?? const {};
    final warehouses = JsonReader.list(results[1], 'resources') ?? const [];
    final name = '${JsonReader.string(profile, 'firstName') ?? ''} '
            '${JsonReader.string(profile, 'lastName') ?? ''}'
        .trim();
    final roles = JsonReader.list(profile, 'userRoles') ?? const [];
    final firstRole = roles.isNotEmpty && roles.first is Map<String, dynamic>
        ? JsonReader.string(roles.first as Map<String, dynamic>, 'name')
        : null;
    final warehouse =
        warehouses.isNotEmpty && warehouses.first is Map<String, dynamic>
            ? warehouses.first as Map<String, dynamic>
            : null;
    final warehouseName = warehouse == null
        ? 'Chưa phân công kho'
        : JsonReader.string(warehouse, 'name') ?? 'Kho';
    final address =
        warehouse == null ? '' : JsonReader.string(warehouse, 'address') ?? '';
    final displayName = name.isEmpty ? 'Người dùng' : name;

    return AccountProfile(
      name: displayName,
      email: JsonReader.string(profile, 'email') ?? 'Không có email',
      role: firstRole ?? 'Người dùng',
      avatarInitial: displayName.substring(0, 1).toUpperCase(),
      inboundCount: 0,
      outboundCount: 0,
      inventoryCount: 0,
      assignedWarehouse:
          address.isEmpty ? warehouseName : '$warehouseName — $address',
      notificationsEnabled: true,
      darkModeEnabled: ThemeController.isDarkMode,
      language: 'Tiếng Việt',
    );
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    final json = await _apiClient.put(
      '/api/v1/user/me/change-password',
      token: _accessToken,
      body: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
        'confirmNewPassword': confirmNewPassword,
      },
    );
    if (JsonReader.boolean(json, 'isSucceeded') == false) {
      throw ApiException(
        message:
            JsonReader.string(json, 'message') ?? 'Không thể đổi mật khẩu.',
      );
    }
  }
}
