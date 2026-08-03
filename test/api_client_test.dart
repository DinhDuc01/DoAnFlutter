import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/api/api_client.dart';

void main() {
  group('ApiClient', () {
    test('GET sends query, accept header and bearer token', () async {
      late Uri receivedUri;
      late String? accept;
      late String? authorization;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        receivedUri = request.uri;
        accept = request.headers.value(HttpHeaders.acceptHeader);
        authorization = request.headers.value(HttpHeaders.authorizationHeader);
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'isSucceeded': true, 'resources': 7}));
        await request.response.close();
      });

      final result = await ApiClient(baseUrl: _baseUrl(server)).get(
        '/api/items',
        query: const {'page': '2', 'search': 'gao'},
        token: 'access-token',
      );

      expect(receivedUri.path, '/api/items');
      expect(receivedUri.queryParameters, {'page': '2', 'search': 'gao'});
      expect(accept, ContentType.json.mimeType);
      expect(authorization, 'Bearer access-token');
      expect(result['resources'], 7);
    });

    test('POST encodes JSON body and content type', () async {
      late String method;
      late String? contentType;
      late Object? receivedBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        method = request.method;
        contentType = request.headers.value(HttpHeaders.contentTypeHeader);
        receivedBody = jsonDecode(await utf8.decoder.bind(request).join());
        request.response
          ..statusCode = HttpStatus.created
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'resources': {'id': 99}
          }));
        await request.response.close();
      });

      final result = await ApiClient(baseUrl: _baseUrl(server)).post(
        '/api/orders',
        body: const {
          'quantity': 12,
          'note': 'test',
        },
      );

      expect(method, 'POST');
      expect(contentType, startsWith(ContentType.json.mimeType));
      expect(receivedBody, {'quantity': 12, 'note': 'test'});
      expect(result['resources'], {'id': 99});
    });

    for (final method in ['PUT', 'PATCH', 'DELETE']) {
      test('$method sends the requested method, JSON body and bearer token',
          () async {
        late String receivedMethod;
        late Object? receivedBody;
        late String? authorization;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          receivedMethod = request.method;
          authorization =
              request.headers.value(HttpHeaders.authorizationHeader);
          receivedBody = jsonDecode(await utf8.decoder.bind(request).join());
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write('{}');
          await request.response.close();
        });

        final client = ApiClient(baseUrl: _baseUrl(server));
        final request = switch (method) {
          'PUT' => client.put,
          'PATCH' => client.patch,
          _ => client.delete,
        };
        await request(
          '/api/resource/9',
          body: const {'enabled': true},
          token: 'access-token',
        );

        expect(receivedMethod, method);
        expect(authorization, 'Bearer access-token');
        expect(receivedBody, {'enabled': true});
      });
    }

    test('does not send authorization header for an empty token', () async {
      String? authorization;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        authorization = request.headers.value(HttpHeaders.authorizationHeader);
        request.response
          ..statusCode = HttpStatus.ok
          ..write('{}');
        await request.response.close();
      });

      await ApiClient(baseUrl: _baseUrl(server)).get('/public', token: '');

      expect(authorization, isNull);
    });

    test('uses backend message and status code for an HTTP error', () async {
      var requestCount = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        requestCount++;
        request.response
          ..statusCode = HttpStatus.unprocessableEntity
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'message': 'Dữ liệu không hợp lệ'}));
        await request.response.close();
      });

      final future = ApiClient(baseUrl: _baseUrl(server)).get('/invalid');

      await expectLater(
        future,
        throwsA(
          isA<ApiException>()
              .having(
                  (error) => error.message, 'message', 'Dữ liệu không hợp lệ')
              .having((error) => error.statusCode, 'statusCode', 422)
              .having((error) => error.isTransient, 'isTransient', isFalse),
        ),
      );
      expect(requestCount, 1);
    });

    test('converts invalid and non-object JSON into ApiException', () async {
      var responseIndex = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.statusCode = HttpStatus.ok;
        request.response.write(responseIndex++ == 0 ? 'not-json' : '[1, 2]');
        await request.response.close();
      });
      final client = ApiClient(baseUrl: _baseUrl(server));

      await expectLater(
        client.get('/invalid-json', retryTransient: false),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'API trả về JSON không hợp lệ',
          ),
        ),
      );
      await expectLater(
        client.get('/json-array', retryTransient: false),
        throwsA(isA<ApiException>()),
      );
    });

    test('returns an empty map for a successful empty response', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
      });

      final result = await ApiClient(baseUrl: _baseUrl(server)).post('/empty');

      expect(result, isEmpty);
    });

    test('retries a transient GET timeout exactly once', () async {
      var requestCount = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        requestCount++;
        // Keep the response open so the client reaches its configured timeout.
      });

      final future = ApiClient(
        baseUrl: _baseUrl(server),
        requestTimeout: const Duration(milliseconds: 20),
      ).get('/slow');

      await expectLater(
        future,
        throwsA(
          isA<ApiException>()
              .having((error) => error.isTransient, 'isTransient', isTrue)
              .having(
                (error) => error.message,
                'message',
                contains('quá lâu'),
              ),
        ),
      );
      expect(requestCount, 2);
    });
  });
}

String _baseUrl(HttpServer server) =>
    'http://${server.address.address}:${server.port}';
