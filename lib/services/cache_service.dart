import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const _prefix = 'housepital_cache_';
  static const _ttlMinutes = 30;

  static CacheService? _instance;
  static CacheService get instance => _instance ??= CacheService._();
  CacheService._();

  Future<void> cache(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    final wrapper = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await prefs.setString('$_prefix$key', jsonEncode(wrapper));
  }

  Future<T?> get<T>(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;

    try {
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      final timestamp = wrapper['timestamp'] as int;
      if (_isExpired(timestamp)) return null;
      return wrapper['data'] as T?;
    } catch (e) {
      debugPrint('CacheService: failed to parse cache for $key: $e');
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }

  bool _isExpired(int cachedTimestamp) {
    final cached = DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
    return DateTime.now().difference(cached).inMinutes > _ttlMinutes;
  }

  /// Returns how many minutes ago the data was cached, or null if not cached.
  Future<int?> getAgeMinutes(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;

    try {
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      final timestamp = wrapper['timestamp'] as int;
      final cached = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateTime.now().difference(cached).inMinutes;
    } catch (e) {
      debugPrint('CacheService: failed to parse cache age for $key: $e');
      return null;
    }
  }

  /// Human-readable last updated text, e.g. "Last updated: 5 min ago"
  Future<String?> getLastUpdatedText(String key) async {
    final minutes = await getAgeMinutes(key);
    if (minutes == null) return null;
    if (minutes < 1) return 'Last updated: just now';
    if (minutes < 60) return 'Last updated: $minutes min ago';
    final hours = minutes ~/ 60;
    return 'Last updated: $hours hr ago';
  }
}
