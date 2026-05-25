import 'dart:convert';
import 'dart:io';

import '../../../core/config/api_config.dart';
import '../models/auth_session.dart';
import 'auth_service.dart';

class ApiAuthService implements AuthService {
  ApiAuthService({
    HttpClient? httpClient,
    this.baseUrl = ApiConfig.baseUrl,
  }) : _httpClient = httpClient ?? _createHttpClient();

  final HttpClient _httpClient;
  final String baseUrl;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw const AuthException('Vui lòng nhập tài khoản và mật khẩu');
    }

    try {
      final uri = Uri.parse('$baseUrl/api/v1/auth/login');
      final request = await _httpClient.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      request.write(
        jsonEncode({
          'Username': email.trim(),
          'Password': password,
        }),
      );

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);

      if (decoded is! Map<String, dynamic>) {
        throw const AuthException('Phản hồi đăng nhập không hợp lệ');
      }

      final isSucceeded = _readBool(decoded, 'isSucceeded') ?? response.statusCode == 200;
      if (!isSucceeded || response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(
          _readString(decoded, 'message') ?? 'Đăng nhập thất bại',
        );
      }

      final resources = _readMap(decoded, 'resources');
      if (resources == null) {
        throw const AuthException('API đăng nhập không trả về dữ liệu phiên');
      }

      final userInfo = _readMap(resources, 'userInfo');
      if (userInfo == null) {
        throw const AuthException('API đăng nhập không trả về thông tin người dùng');
      }

      return AuthSession(
        accessToken: _readString(resources, 'accessToken') ?? '',
        refreshToken: _readString(resources, 'refreshToken') ?? '',
        user: AuthUser(
          id: _readInt(userInfo, 'id') ?? 0,
          fullName: _readString(userInfo, 'fullName') ?? '',
          email: _readString(userInfo, 'email') ?? email.trim(),
          avatarUrl: _readString(userInfo, 'avatarUrl'),
        ),
      );
    } on AuthException {
      rethrow;
    } on SocketException {
      throw AuthException('Không kết nối được API đăng nhập tại $baseUrl');
    } on HandshakeException {
      throw const AuthException('Chứng chỉ HTTPS local chưa được tin cậy');
    } on FormatException {
      throw const AuthException('API đăng nhập trả về JSON không hợp lệ');
    } on HttpException catch (error) {
      throw AuthException(error.message);
    } catch (error) {
      throw AuthException('Không đăng nhập được: $error');
    }
  }

  static HttpClient _createHttpClient() {
    final client = HttpClient();
    client.badCertificateCallback = (certificate, host, port) {
      return (host == '10.0.2.2' || host == 'localhost' || host == '127.0.0.1') && port == 7260;
    };
    return client;
  }

  static Object? _readValue(Map<String, dynamic> json, String key) {
    for (final entry in json.entries) {
      if (entry.key.toLowerCase() == key.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  static Map<String, dynamic>? _readMap(Map<String, dynamic> json, String key) {
    final value = _readValue(json, key);
    return value is Map<String, dynamic> ? value : null;
  }

  static String? _readString(Map<String, dynamic> json, String key) {
    final value = _readValue(json, key);
    return value is String ? value : null;
  }

  static int? _readInt(Map<String, dynamic> json, String key) {
    final value = _readValue(json, key);
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static bool? _readBool(Map<String, dynamic> json, String key) {
    final value = _readValue(json, key);
    return value is bool ? value : null;
  }
}
