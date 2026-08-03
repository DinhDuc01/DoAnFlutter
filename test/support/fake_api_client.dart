import 'package:stocklite/core/api/api_client.dart';

typedef GetHandler = Future<Map<String, dynamic>> Function(
  String path,
  Map<String, String>? query,
  String? token,
);

typedef PostHandler = Future<Map<String, dynamic>> Function(
  String path,
  Map<String, dynamic>? body,
  String? token,
);

class ApiCall {
  const ApiCall({
    required this.method,
    required this.path,
    this.query,
    this.body,
    this.token,
  });

  final String method;
  final String path;
  final Map<String, String>? query;
  final Map<String, dynamic>? body;
  final String? token;
}

class FakeApiClient extends ApiClient {
  FakeApiClient({
    this.onGet,
    this.onPost,
    this.onPut,
    this.onPatch,
    this.onDelete,
  }) : super(baseUrl: 'https://fake.api');

  final GetHandler? onGet;
  final PostHandler? onPost;
  final PostHandler? onPut;
  final PostHandler? onPatch;
  final PostHandler? onDelete;
  final List<ApiCall> calls = [];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    String? token,
    bool retryTransient = true,
  }) async {
    calls.add(
      ApiCall(
        method: 'GET',
        path: path,
        query: query,
        token: token,
      ),
    );
    final handler = onGet;
    if (handler == null) return <String, dynamic>{};
    return handler(path, query, token);
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    calls.add(
      ApiCall(
        method: 'POST',
        path: path,
        body: body,
        token: token,
      ),
    );
    final handler = onPost;
    if (handler == null) return <String, dynamic>{};
    return handler(path, body, token);
  }

  @override
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) =>
      _write('PUT', path, body, token, onPut);

  @override
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) =>
      _write('PATCH', path, body, token, onPatch);

  @override
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) =>
      _write('DELETE', path, body, token, onDelete);

  Future<Map<String, dynamic>> _write(
    String method,
    String path,
    Map<String, dynamic>? body,
    String? token,
    PostHandler? handler,
  ) async {
    calls.add(ApiCall(method: method, path: path, body: body, token: token));
    if (handler == null) return <String, dynamic>{};
    return handler(path, body, token);
  }
}
