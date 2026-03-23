import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:housepital_patient/services/cache_service.dart';

void main() {
  late CacheService cacheService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cacheService = CacheService.instance;
  });

  group('CacheService', () {
    test('cache() stores data with timestamp', () async {
      SharedPreferences.setMockInitialValues({});
      await cacheService.cache('test_key', {'name': 'test'});

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('housepital_cache_test_key');
      expect(raw, isNotNull);

      final wrapper = jsonDecode(raw!) as Map<String, dynamic>;
      expect(wrapper.containsKey('data'), isTrue);
      expect(wrapper.containsKey('timestamp'), isTrue);
      expect(wrapper['data'], equals({'name': 'test'}));
      expect(wrapper['timestamp'], isA<int>());
    });

    test('get() returns cached data within TTL', () async {
      SharedPreferences.setMockInitialValues({});
      await cacheService.cache('fresh_key', 'hello');

      final result = await cacheService.get<String>('fresh_key');
      expect(result, equals('hello'));
    });

    test('get() returns null for expired data (TTL exceeded)', () async {
      // Manually insert data with a timestamp 31+ minutes ago
      final expiredTimestamp =
          DateTime.now().subtract(const Duration(minutes: 31)).millisecondsSinceEpoch;
      final wrapper = jsonEncode({
        'data': 'old_value',
        'timestamp': expiredTimestamp,
      });
      SharedPreferences.setMockInitialValues({
        'housepital_cache_expired_key': wrapper,
      });

      final result = await cacheService.get<String>('expired_key');
      expect(result, isNull);
    });

    test('get() returns null for non-existent keys', () async {
      SharedPreferences.setMockInitialValues({});
      final result = await cacheService.get<String>('nonexistent');
      expect(result, isNull);
    });

    test('clear() removes all cached data', () async {
      SharedPreferences.setMockInitialValues({});
      await cacheService.cache('key1', 'value1');
      await cacheService.cache('key2', 'value2');

      await cacheService.clear();

      final result1 = await cacheService.get<String>('key1');
      final result2 = await cacheService.get<String>('key2');
      expect(result1, isNull);
      expect(result2, isNull);
    });

    test('remove() removes specific key', () async {
      SharedPreferences.setMockInitialValues({});
      await cacheService.cache('keep_key', 'keep');
      await cacheService.cache('remove_key', 'remove');

      await cacheService.remove('remove_key');

      final kept = await cacheService.get<String>('keep_key');
      final removed = await cacheService.get<String>('remove_key');
      expect(kept, equals('keep'));
      expect(removed, isNull);
    });

    test('getLastUpdatedText() returns "just now" for fresh data', () async {
      SharedPreferences.setMockInitialValues({});
      await cacheService.cache('recent', 'data');

      final text = await cacheService.getLastUpdatedText('recent');
      expect(text, equals('Last updated: just now'));
    });

    test('getLastUpdatedText() returns "X min ago" for data cached minutes ago', () async {
      final fiveMinAgo =
          DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch;
      final wrapper = jsonEncode({
        'data': 'value',
        'timestamp': fiveMinAgo,
      });
      SharedPreferences.setMockInitialValues({
        'housepital_cache_old': wrapper,
      });

      final text = await cacheService.getLastUpdatedText('old');
      expect(text, contains('min ago'));
    });

    test('getLastUpdatedText() returns "X hr ago" for data cached hours ago', () async {
      final twoHoursAgo =
          DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch;
      final wrapper = jsonEncode({
        'data': 'value',
        'timestamp': twoHoursAgo,
      });
      SharedPreferences.setMockInitialValues({
        'housepital_cache_hours': wrapper,
      });

      final text = await cacheService.getLastUpdatedText('hours');
      expect(text, equals('Last updated: 2 hr ago'));
    });

    test('getLastUpdatedText() returns null for non-existent key', () async {
      SharedPreferences.setMockInitialValues({});
      final text = await cacheService.getLastUpdatedText('nope');
      expect(text, isNull);
    });
  });
}
