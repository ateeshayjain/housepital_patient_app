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

    // --- Additional tests for persistence, isolation, and prefix clearing ---

    test('cache survives simulated app restart (pre-seeded SharedPreferences)', () async {
      // Simulate data persisted from a previous session by pre-seeding
      final freshTimestamp = DateTime.now().millisecondsSinceEpoch;
      final wrapper = jsonEncode({
        'data': 'persisted_value',
        'timestamp': freshTimestamp,
      });
      SharedPreferences.setMockInitialValues({
        'housepital_cache_restart_key': wrapper,
      });

      // A new get call should find the pre-seeded data
      final result = await cacheService.get<String>('restart_key');
      expect(result, equals('persisted_value'));
    });

    test('multiple cache keys do not interfere with each other', () async {
      SharedPreferences.setMockInitialValues({});
      await cacheService.cache('alpha', 'value_alpha');
      await cacheService.cache('beta', 'value_beta');
      await cacheService.cache('gamma', 42);

      final alpha = await cacheService.get<String>('alpha');
      final beta = await cacheService.get<String>('beta');
      final gamma = await cacheService.get<int>('gamma');

      expect(alpha, equals('value_alpha'));
      expect(beta, equals('value_beta'));
      expect(gamma, equals(42));

      // Removing one key does not affect others
      await cacheService.remove('beta');
      expect(await cacheService.get<String>('alpha'), equals('value_alpha'));
      expect(await cacheService.get<String>('beta'), isNull);
      expect(await cacheService.get<int>('gamma'), equals(42));
    });

    test('clear() removes all keys with housepital_cache_ prefix', () async {
      // Pre-seed with both cache keys and a non-cache key
      final ts = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'housepital_cache_a': jsonEncode({'data': 1, 'timestamp': ts}),
        'housepital_cache_b': jsonEncode({'data': 2, 'timestamp': ts}),
        'housepital_cache_c': jsonEncode({'data': 3, 'timestamp': ts}),
        'other_app_key': 'should_survive',
      });

      await cacheService.clear();

      final prefs = await SharedPreferences.getInstance();
      // All cache keys should be gone
      expect(prefs.getString('housepital_cache_a'), isNull);
      expect(prefs.getString('housepital_cache_b'), isNull);
      expect(prefs.getString('housepital_cache_c'), isNull);
      // Non-prefixed key should survive
      expect(prefs.getString('other_app_key'), equals('should_survive'));
    });

    test('cache overwrites existing key with new value', () async {
      SharedPreferences.setMockInitialValues({});
      await cacheService.cache('overwrite_key', 'original');
      await cacheService.cache('overwrite_key', 'updated');

      final result = await cacheService.get<String>('overwrite_key');
      expect(result, equals('updated'));
    });
  });
}
