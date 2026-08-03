/// Cau hinh ket noi API.
class ApiConfig {
  const ApiConfig._();

  /// Co the override khi chay app:
  /// flutter run --dart-define=API_BASE_URL=https://your-api-url
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://backend-do-an-api-new.onrender.com',
  );
}
