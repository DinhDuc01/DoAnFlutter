import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../models/auth_session.dart';
import 'auth_service.dart';

/// Lớp hiện thực (Implementation) của [AuthService] sử dụng REST API thực tế để đăng nhập.
class ApiAuthService implements AuthService {
  ApiAuthService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<void> logout(AuthSession session) async {
    final json = await _apiClient.post(
      '/api/v1/auth/logout',
      token: session.accessToken,
      body: {'refreshToken': session.refreshToken},
    );
    if (JsonReader.boolean(json, 'isSucceeded') == false) {
      throw AuthException(
        JsonReader.string(json, 'message') ?? 'Đăng xuất thất bại',
      );
    }
  }

  @override
  Future<AuthSession> refresh(AuthSession session) async {
    if (session.refreshToken.isEmpty) {
      throw const AuthException('Phiên đăng nhập đã hết hạn');
    }

    try {
      // Backend nhận accessToken (cũ) + refreshToken, trả về cặp token mới.
      final json = await _apiClient.post(
        '/api/v1/auth/refresh-token',
        body: {
          'accessToken': session.accessToken,
          'refreshToken': session.refreshToken,
        },
      );

      final isSucceeded = JsonReader.boolean(json, 'isSucceeded') ?? false;
      if (!isSucceeded) {
        throw AuthException(
          JsonReader.string(json, 'message') ?? 'Làm mới phiên thất bại',
        );
      }

      final resources = JsonReader.map(json, 'resources');
      if (resources == null) {
        throw const AuthException('API làm mới token không trả dữ liệu');
      }

      final accessToken = JsonReader.string(resources, 'accessToken') ?? '';
      final refreshToken = JsonReader.string(resources, 'refreshToken') ?? '';
      if (accessToken.isEmpty) {
        throw const AuthException('API làm mới token không hợp lệ');
      }

      return session.copyWith(
        accessToken: accessToken,
        // Giữ refresh token cũ nếu backend không cấp lại token mới.
        refreshToken: refreshToken.isEmpty ? session.refreshToken : refreshToken,
      );
    } on AuthException {
      rethrow;
    } on ApiException catch (error) {
      throw AuthException(error.message);
    } catch (error) {
      throw AuthException('Không làm mới được phiên: $error');
    }
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    // Kiểm tra dữ liệu đầu vào cơ bản
    if (email.trim().isEmpty || password.isEmpty) {
      throw const AuthException('Vui lòng nhập tài khoản và mật khẩu');
    }

    try {
      // Backend nhận username/password và trả accessToken + userInfo.
      final json = await _apiClient.post(
        '/api/v1/auth/login', // Điểm cuối (endpoint) API đăng nhập
        body: {
          'username': email.trim(),
          'password': password,
        },
      );

      // Đọc cờ trạng thái từ JSON phản hồi
      final isSucceeded = JsonReader.boolean(json, 'isSucceeded') ?? false;
      if (!isSucceeded) {
        throw AuthException(
          JsonReader.string(json, 'message') ?? 'Đăng nhập thất bại',
        );
      }

      // Đọc thông tin tài nguyên (resources) trả về
      final resources = JsonReader.map(json, 'resources');
      if (resources == null) {
        throw const AuthException('API đăng nhập không trả dữ liệu phiên');
      }

      // Đọc thông tin chi tiết người dùng (userInfo)
      final userInfo = JsonReader.map(resources, 'userInfo');
      if (userInfo == null) {
        throw const AuthException(
            'API đăng nhập không trả thông tin người dùng');
      }

      final accessToken = JsonReader.string(resources, 'accessToken');
      final refreshToken = JsonReader.string(resources, 'refreshToken');
      if (accessToken == null || accessToken.isEmpty ||
          refreshToken == null || refreshToken.isEmpty) {
        throw const AuthException(
          'API đăng nhập không trả đủ thông tin token phiên',
        );
      }

      // Khởi tạo và trả về đối tượng AuthSession từ dữ liệu API đã parse thành công
      return AuthSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: AuthUser(
          id: JsonReader.integer(userInfo, 'id') ?? 0,
          fullName: JsonReader.string(userInfo, 'fullName') ?? '',
          email: JsonReader.string(userInfo, 'email') ?? email.trim(),
          avatarUrl: JsonReader.string(userInfo, 'avatarUrl'),
        ),
      );
    } on AuthException {
      rethrow;
    } on ApiException catch (error) {
      // Chuyển tiếp lỗi phát sinh từ API client sang ngoại lệ AuthException
      throw AuthException(error.message);
    } catch (error) {
      // Xử lý các lỗi hệ thống không xác định khác
      throw AuthException('Không đăng nhập được: $error');
    }
  }
}
