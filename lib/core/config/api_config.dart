class ApiConfig {
  const ApiConfig._();

  // Android emulator maps host machine localhost to 10.0.2.2.
  // For a physical phone, override this with your machine LAN IP.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://10.0.2.2:7260',
  );
}
