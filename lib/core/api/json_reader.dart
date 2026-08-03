/// Lớp tiện ích (utility helper) giúp đọc dữ liệu từ Map JSON một cách an toàn.
/// Nó hỗ trợ so khớp key không phân biệt chữ hoa/thường (case-insensitive) và tự động ép/chuyển kiểu dữ liệu.
class JsonReader {
  const JsonReader._(); // Hạn chế khởi tạo đối tượng trực tiếp từ bên ngoài

  /// Lấy giá trị bất kỳ từ [json] dựa theo [key] (không phân biệt chữ hoa/thường).
  static Object? value(Map<String, dynamic> json, String key) {
    for (final entry in json.entries) {
      if (entry.key.toLowerCase() == key.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  /// Đọc một đối tượng Map (JSON Object) từ [json] theo [key].
  static Map<String, dynamic>? map(Map<String, dynamic> json, String key) {
    final data = value(json, key);
    return data is Map<String, dynamic> ? data : null;
  }

  /// Đọc một danh sách (JSON Array) từ [json] theo [key].
  static List<dynamic>? list(Map<String, dynamic> json, String key) {
    final data = value(json, key);
    return data is List<dynamic> ? data : null;
  }

  /// Đọc một chuỗi ký tự (String) từ [json] theo [key].
  static String? string(Map<String, dynamic> json, String key) {
    final data = value(json, key);
    return data is String ? data : null;
  }

  /// Đọc số nguyên (int) từ [json] theo [key], tự động chuyển đổi từ số thực hoặc chuỗi nếu có thể.
  static int? integer(Map<String, dynamic> json, String key) {
    final data = value(json, key);
    if (data is int) return data;
    if (data is num) return data.toInt();
    if (data is String) return int.tryParse(data);
    return null;
  }

  /// Đọc số thực (double) từ [json] theo [key], tự động chuyển đổi từ số nguyên hoặc chuỗi nếu có thể.
  static double? decimal(Map<String, dynamic> json, String key) {
    final data = value(json, key);
    if (data is double) return data;
    if (data is num) return data.toDouble();
    if (data is String) return double.tryParse(data);
    return null;
  }

  /// Đọc giá trị Boolean (bool - true/false) từ [json] theo [key].
  static bool? boolean(Map<String, dynamic> json, String key) {
    final data = value(json, key);
    return data is bool ? data : null;
  }
}
