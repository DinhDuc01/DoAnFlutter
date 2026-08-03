import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/core/api/json_reader.dart';

void main() {
  group('JsonReader', () {
    test('reads keys without case sensitivity', () {
      final json = <String, dynamic>{
        'AccessToken': 'token-123',
        'ISsucceeded': true,
      };

      expect(JsonReader.string(json, 'accessToken'), 'token-123');
      expect(JsonReader.boolean(json, 'isSucceeded'), isTrue);
    });

    test('converts integer values from num and string', () {
      final json = <String, dynamic>{
        'fromInt': 12,
        'fromDouble': 12.9,
        'fromString': '42',
        'invalid': '4.2',
      };

      expect(JsonReader.integer(json, 'fromInt'), 12);
      expect(JsonReader.integer(json, 'fromDouble'), 12);
      expect(JsonReader.integer(json, 'fromString'), 42);
      expect(JsonReader.integer(json, 'invalid'), isNull);
    });

    test('converts decimal values from num and string', () {
      final json = <String, dynamic>{
        'fromInt': 10,
        'fromDouble': 2.75,
        'fromString': '15.25',
        'invalid': 'fifteen',
      };

      expect(JsonReader.decimal(json, 'fromInt'), 10.0);
      expect(JsonReader.decimal(json, 'fromDouble'), 2.75);
      expect(JsonReader.decimal(json, 'fromString'), 15.25);
      expect(JsonReader.decimal(json, 'invalid'), isNull);
    });

    test('only returns maps and lists with the expected type', () {
      final json = <String, dynamic>{
        'resources': <String, dynamic>{'id': 1},
        'items': <dynamic>[1, 2],
        'wrongMap': 'not-a-map',
        'wrongList': <String, dynamic>{},
      };

      expect(JsonReader.map(json, 'resources'), {'id': 1});
      expect(JsonReader.list(json, 'items'), [1, 2]);
      expect(JsonReader.map(json, 'wrongMap'), isNull);
      expect(JsonReader.list(json, 'wrongList'), isNull);
      expect(JsonReader.value(json, 'missing'), isNull);
    });
  });
}
