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

  /// Hook làm mới token khi API trả về 401.
  ///
  /// Nhận access token đã hết hạn (token vừa dùng cho request bị 401) và trả về
  /// access token mới nếu làm mới thành công, hoặc null nếu không thể (khi đó
  /// request sẽ giữ nguyên lỗi 401). Được gắn 1 lần trong `main()` để tránh
  /// phụ thuộc vòng giữa ApiClient và tầng auth.
  static Future<String?> Function(String? expiredToken)? onUnauthorized;

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
    // Chỉ GET được retry tự động vì có tính idempotent. Mutation POST/PUT/
    // PATCH/DELETE không retry để tránh tạo hoặc cập nhật nghiệp vụ hai lần.
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
  ///
  /// [allowRefresh] cho phép tự làm mới token khi gặp 401 (chỉ thử 1 lần để
  /// tránh lặp vô hạn).
  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    String? token,
    bool allowRefresh = true,
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

      // Access token hết hạn → thử làm mới token rồi gửi lại đúng 1 lần.
      if (response.statusCode == 401 &&
          allowRefresh &&
          token != null &&
          token.isNotEmpty &&
          onUnauthorized != null) {
        final newToken = await onUnauthorized!(token);
        if (newToken != null && newToken.isNotEmpty && newToken != token) {
          return _send(
            method,
            path,
            query: query,
            body: body,
            token: newToken,
            allowRefresh: false,
          );
        }
      }

      // HTTP 4xx/5xx luôn thành exception; tầng repository/UI không được coi
      // response có body JSON nhưng status lỗi là một mutation thành công.
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

  /// Gửi request multipart/form-data (dùng để upload ảnh lên server → Cloudinary).
  ///
  /// [fields] là các trường text kèm theo; [fileBytes]/[fileName] là tệp cần
  /// tải lên dưới field tên [fileField]. Trả về JSON đã giải mã.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required List<int> fileBytes,
    required String fileName,
    String fileField = 'Files',
    Map<String, String> fields = const {},
    String? token,
  }) async {
    final client = _createHttpClient();
    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = await client.postUrl(uri);
      final boundary =
          '----flutterBoundary${DateTime.now().microsecondsSinceEpoch}';

      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      request.headers.contentType = ContentType(
        'multipart',
        'form-data',
        parameters: {'boundary': boundary},
      );

      final body = <int>[];
      void writeLine(String line) => body.addAll(utf8.encode('$line\r\n'));

      fields.forEach((key, value) {
        writeLine('--$boundary');
        writeLine('Content-Disposition: form-data; name="$key"');
        writeLine('');
        writeLine(value);
      });

      writeLine('--$boundary');
      writeLine(
        'Content-Disposition: form-data; name="$fileField"; filename="$fileName"',
      );
      writeLine('Content-Type: ${_mimeFromFileName(fileName)}');
      writeLine('');
      body.addAll(fileBytes);
      body.addAll(utf8.encode('\r\n'));
      writeLine('--$boundary--');

      request.contentLength = body.length;
      request.add(body);

      final response = await request.close().timeout(requestTimeout);
      final responseBody =
          await response.transform(utf8.decoder).join().timeout(requestTimeout);
      final json = _decodeJson(responseBody);

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
    } finally {
      client.close(force: true);
    }
  }

  String _mimeFromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
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
