import 'dart:async';

/// Simple in-memory cache for game sessions
class CacheManager<T> {
  final Map<String, CacheEntry<T>> _cache = {};
  final Duration _defaultTtl;

  CacheManager({Duration? defaultTtl}) 
    : _defaultTtl = defaultTtl ?? const Duration(minutes: 5);

  /// Get cached value if it exists and is not expired
  T? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    
    return entry.value;
  }

  /// Cache a value with optional TTL
  void put(String key, T value, {Duration? ttl}) {
    _cache[key] = CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl ?? _defaultTtl),
    );
  }

  /// Remove a cached value
  void remove(String key) {
    _cache.remove(key);
  }

  /// Clear all cached values
  void clear() {
    _cache.clear();
  }

  /// Get cache statistics
  CacheStats get stats {
    int expired = 0;
    int valid = 0;
    
    for (final entry in _cache.values) {
      if (entry.isExpired) {
        expired++;
      } else {
        valid++;
      }
    }
    
    return CacheStats(
      totalEntries: _cache.length,
      validEntries: valid,
      expiredEntries: expired,
    );
  }

  /// Clean up expired entries
  void cleanup() {
    final expiredKeys = _cache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();
    
    for (final key in expiredKeys) {
      _cache.remove(key);
    }
  }
}

class CacheEntry<T> {
  final T value;
  final DateTime expiresAt;

  CacheEntry({
    required this.value,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class CacheStats {
  final int totalEntries;
  final int validEntries;
  final int expiredEntries;

  CacheStats({
    required this.totalEntries,
    required this.validEntries,
    required this.expiredEntries,
  });

  @override
  String toString() {
    return 'CacheStats(total: $totalEntries, valid: $validEntries, expired: $expiredEntries)';
  }
}