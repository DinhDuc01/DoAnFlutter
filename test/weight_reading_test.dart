import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stocklite/features/scale/models/weight_reading.dart';

void main() {
  group('WeightReading', () {
    test('parses the ESP32 JSON payload', () {
      final reading = WeightReading.fromBytes(
        utf8.encode('{"w":2.45,"u":"kg","s":true}'),
      );

      expect(reading.weight, 2.45);
      expect(reading.unit, 'kg');
      expect(reading.isStable, isTrue);
    });

    test('defaults to kg when unit is missing', () {
      final reading = WeightReading.fromJsonString('{"w":12,"s":false}');

      expect(reading.weight, 12.0);
      expect(reading.unit, 'kg');
      expect(reading.isStable, isFalse);
    });

    test('rejects a payload without stability state', () {
      expect(
        () => WeightReading.fromJsonString('{"w":2.45,"u":"kg"}'),
        throwsFormatException,
      );
    });

    test('rejects non-JSON data', () {
      expect(
        () => WeightReading.fromJsonString('2.45 kg'),
        throwsFormatException,
      );
    });

    test('rejects an empty BLE payload', () {
      expect(() => WeightReading.fromBytes(const []), throwsFormatException);
    });

    test('rejects JSON that is not an object', () {
      expect(
        () => WeightReading.fromJsonString('[2.45, "kg", true]'),
        throwsFormatException,
      );
    });

    test('rejects weight and stability fields with wrong types', () {
      expect(
        () => WeightReading.fromJsonString('{"w":"2.45","s":true}'),
        throwsFormatException,
      );
      expect(
        () => WeightReading.fromJsonString('{"w":2.45,"s":"true"}'),
        throwsFormatException,
      );
    });

    test('rejects non-positive or non-finite weight', () {
      expect(
        () => WeightReading.fromJsonString('{"w":0,"s":true}'),
        throwsFormatException,
      );
      expect(
        () => WeightReading.fromJsonString('{"w":-1,"s":true}'),
        throwsFormatException,
      );
    });

    test('detects stale readings before capture', () {
      final receivedAt = DateTime(2026, 8, 13, 10);
      final reading = WeightReading(
        weight: 2.45,
        unit: 'kg',
        isStable: true,
        receivedAt: receivedAt,
      );

      expect(
        reading.isFresh(
          now: receivedAt.add(const Duration(seconds: 4)),
        ),
        isTrue,
      );
      expect(
        reading.isFresh(
          now: receivedAt.add(const Duration(seconds: 6)),
        ),
        isFalse,
      );
    });
  });
}
