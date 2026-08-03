import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/api_config.dart';
import 'json_reader.dart';

/// Class quản lý việc gửi nhận request HTTP tới REST API.
class ApiClient {
  ApiClient({
    this.baseUrl =
        ApiConfig.baseUrl, // Sử dụng URL cơ sở mặc định từ cấu hình API
    this.requestTimeout = const Duration(seconds: 30),
  });

  /// URL cơ sở (base URL) của API
  final String baseUrl;
  final Duration requestTimeout;

  /// Thực hiện phương thức GET request.
  /// [path] là đường dẫn API (ví dụ: '/products').
  /// [query] là các tham số dạng query string.
  /// [token] là mã xác thực Bearer token (nếu có).
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    String? token,
    bool retryTransient = true,
  }) {
    return _sendWithRetry(
      'GET',
      path,
      query: query,
      token: token,
      retryTransient: retryTransient,
    );
  }

  /// Thực hiện phương thức POST request.
  /// [path] là đường dẫn API.
  /// [body] là dữ liệu JSON gửi lên body của request.
  /// [token] là mã xác thực Bearer token (nếu có).
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) {
    return _sendWithRetry('POST', path, body: body, token: token);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) {
    return _sendWithRetry('PUT', path, body: body, token: token);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) {
    return _sendWithRetry('PATCH', path, body: body, token: token);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) {
    return _sendWithRetry('DELETE', path, body: body, token: token);
  }

  Future<Map<String, dynamic>> _sendWithRetry(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    String? token,
    bool retryTransient = true,
  }) async {
    final attempts = method == 'GET' && retryTransient ? 2 : 1;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        return await _send(
          method,
          path,
          query: query,
          body: body,
          token: token,
        );
      } on ApiException catch (error) {
        if (!error.isTransient || attempt == attempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
    throw const ApiException(message: 'Khong the gui yeu cau API.');
  }

  /// Phương thức chung nội bộ để xử lý gửi request (cả GET và POST).
  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    String? token,
  }) async {
    // Tạo đối tượng HttpClient hỗ trợ cấu hình tùy chỉnh
    final client = _createHttpClient();

    try {
      // Parse URI kết hợp baseUrl, path và query parameters
      final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
      final request = await client.openUrl(method, uri);

      // Thiết lập header chấp nhận định dạng JSON
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);

      // Nếu có token xác thực, thiết lập Authorization Header dưới dạng Bearer Token
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      // Nếu có body gửi kèm (áp dụng cho POST)
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }

      // Đóng request và chờ phản hồi từ server
      final response = await request.close().timeout(requestTimeout);

      // Đọc toàn bộ body phản hồi từ dạng stream
      final responseBody =
          await response.transform(utf8.decoder).join().timeout(requestTimeout);

      // Giải mã chuỗi phản hồi sang Map JSON
      final json = _decodeJson(responseBody);

      // Nếu mã trạng thái HTTP không nằm trong khoảng thành công (200 - 299)
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          message: JsonReader.string(json, 'message') ??
              'API lỗi ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      return json;
    } on ApiException {
      rethrow;
    } on HttpException {
      throw const ApiException(
        message: 'Kết nối API bị gián đoạn. Vui lòng thử lại.',
        isTransient: true,
      );
    } on TimeoutException {
      throw const ApiException(
        message: 'API phản hồi quá lâu. Vui lòng thử lại.',
        isTransient: true,
      );
    } on SocketException {
      throw ApiException(
        message: 'Không kết nối được API tại $baseUrl',
        isTransient: true,
      );
    } on HandshakeException {
      throw const ApiException(
          message: 'Chứng chỉ HTTPS local chưa được tin cậy');
    } on FormatException {
      throw const ApiException(message: 'API trả về JSON không hợp lệ');
    } finally {
      // Đảm bảo client luôn đóng để giải phóng tài nguyên hệ thống
      client.close(force: true);
    }
  }

  /// Giải mã chuỗi JSON sang đối tượng Map.
  Map<String, dynamic> _decodeJson(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;

    throw const FormatException('Response is not a JSON object');
  }

  /// Khởi tạo và cấu hình HttpClient.
  HttpClient _createHttpClient() {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);

    // Cho phép bỏ qua SSL cert cho môi trường dev local (localhost, emulator)
    // và server production HTTP (15.135.109.251).
    client.badCertificateCallback = (certificate, host, port) {
      final isLocalHost =
          host == '10.0.2.2' || host == 'localhost' || host == '127.0.0.1';
      final isProductionHttp = host == '15.135.109.251';
      return isLocalHost || isProductionHttp;
    };

    return client;
  }
}

/// Lớp ngoại lệ (Exception) tùy chỉnh dành riêng cho các lỗi liên quan đến API.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.isTransient = false,
  });

  /// Thông điệp lỗi
  final String message;

  /// Mã trạng thái HTTP (HTTP status code) tương ứng nếu có
  final int? statusCode;

  final bool isTransient;

  @override
  String toString() => message;
}
